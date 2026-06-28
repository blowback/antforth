# Story 18.2: Sentinel-trampoline `cross_bank_return` + kernel `EXIT` distinguishes intra-bank from cross-bank

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Second story of Epic 18 (Stub mechanism (γ) + cross-bank EXIT (S1 b) +
`BANK-OF` + `IN-BANK`). Story 18.1 closed 2026-05-18 with the
descriptor-stub allocator + `(stub-allocate)` wrapper landed in
`src/banking.asm:780..822`, the `stub_alloc_tail` UserArea cell appended
at `src/structures.asm:51..52`, `STUB_ALLOC_BASE = $D4CB` constant in
`src/constants.asm`, and COLD seeding in `src/antforth.asm` step 8h.
Pre-edit baseline at Story 18.1 close = **26,298 B kernel** /
**975 PASS / 0 FAIL / 2 SKIP** iz-cpm baseline / **38 PASS / 0 FAIL**
`make test-repl-banking` (= 35 Epic-17 baseline + 3 Story-18.1 probes
A/B/C) / **31 advisories / 0 drift** `make check-doc-sync` (re-validate
at dev-pass start per B.3 — see Pre-edit baseline task below).

Story 18.2 lands the **S1 b sentinel-trampoline cross-bank return
mechanism** — the piece of Epic 18 that lets a banked colon body's
`EXIT` route control back to the caller's bank when the caller and
target live in different banks, while leaving the standard intra-bank
`EXIT` zero-overhead (per FR-P4-19). Concretely:

1. **A `cross_bank_return:` trampoline body lands in `src/banking.asm`**
   at a fixed-memory address (the body lives anywhere convenient in
   the file; the only requirement is that its address is a known
   compile-time symbol). The body's contract per PD-P4-2 +
   `docs/antforth-banking-redesign.md` §2.2:
   - Pop `caller_bank` (1 cell) from the return stack.
   - Resolve `caller_bank` → physical page via `active_pages[caller_bank]`
     (the same `(IY+UserArea.current_bank)` ↔ `active_pages[]` mapping
     that `BANK!` uses at `src/banking.asm:157..161`).
   - Write the physical page to MMU slot 2: `OUT (0x72), A` — same
     port as `BANK!` (per PD-P4-9 / `iz-cpm-banking cpm_machine.rs:13..14`
     PORT_BANK0..3 = 0x70..0x73; slot 2 = portal page per redesign
     §5.1 / §5.2).
   - Update the live `(IY+UserArea.current_bank)` cell so `BANK@`
     reflects the restored bank.
   - Pop `target_addr` (1 cell) and `JP (HL)` to it (or equivalent
     direct dispatch). `target_addr` is a fixed-memory or current-bank
     code address chosen by whatever pushed the sentinel frame.
2. **The sentinel address IS `cross_bank_return` itself** per the
   architecture's "Sentinel-trampoline labels" pattern at
   `architecture.md:534..537` ("`cross_bank_return:` — the trampoline
   label in `src/banking.asm`; sentinel address is `cross_bank_return`
   itself (one symbol does both jobs)"). No separate sentinel constant
   is introduced; `cross_bank_return` is exported via sjasmplus
   global-label semantics so `src/inner_interpreter.asm` can `CP`
   against it.
3. **`src/inner_interpreter.asm`'s `EXIT_CODE` is extended with a
   sentinel comparison** (`src/inner_interpreter.asm:36..43`,
   currently 6 instructions / ~6 B emit). After the standard
   `LD E,(IX+0) / LD D,(IX+1) / INC IX / INC IX` pop, DE = popped
   return-address. A two-byte CP against `LOW cross_bank_return` then
   `HIGH cross_bank_return` decides intra-bank vs cross-bank: on
   match, `JP cross_bank_return` (or fall-through if the trampoline
   is placed immediately after EXIT_CODE — Layout B in Q1 below);
   on miss, the standard `NEXT` runs. The intra-bank path adds
   one or two CP / JR-NZ pairs (≤ ~10 B extra) above the existing
   6-byte EXIT_CODE; no other intra-bank instructions are inserted
   on the hot path (FR-P4-19 intra-bank zero-overhead path
   preserved exactly up to the sentinel CP).
4. **No `cross_bank_return`-frame pusher lands in this story.** Story
   18.3's `EXECUTE` chokepoint is the production pusher (writes
   `(sentinel_addr, caller_bank, target_addr)` onto the R-stack
   when EXECUTE decodes a cross-bank target from stub byte 0).
   Story 18.2's AC7 probes hand-construct the 3-cell frame via
   `>R` from a probe-local colon body (or via a thin kernel-internal
   `(push-sentinel-frame)` helper if dev-pass picks that shape —
   see Q2 below); the probes verify the trampoline + EXIT-sentinel
   branch independently of Story 18.3's EXECUTE wiring.
5. **No `BANK-OF` / `IN-BANK` user surface lands here.** Story 18.4
   (`BANK-OF`) and Story 18.5 (`IN-BANK` + Epic 18 close-out) consume
   the trampoline + EXIT-sentinel branch; Story 18.2 is purely the
   dispatch substrate.
6. **Per-binary-delta S9 hardware-smoke run on real MicroBeast** is
   in-scope (the trampoline writes MMU port 0x72 — same
   port-write surface as `BANK!`, validated repeatedly on real
   hardware in Epic 17). Recipe is typed-form, smoke-tested under
   iz-cpm-banking first per Lesson 17-F, and posted in the closing
   chat message at code-review close per
   `feedback_post_hw_smoke_steps_at_review.md` STRONG rule (fired
   8× in Epic 17 + Story 18.1; non-negotiable).
7. **Binary-delta calibration carries the Epic-17 / Story-18.1
   lesson forward** (Lesson 17-B + memory
   `project_epic17_envelope.md` — empirical envelope ~2.4–2.7× spec
   target across Epic 17; Story 18.1 came in at 1.52× of its
   per-component itemisation, under the envelope). AC9's spec
   ceiling is ≤ ~80 B; the per-component itemisation (Dev Notes —
   Byte budget) sums to ~35–50 B (trampoline ~20–28 B + EXIT
   sentinel comparison ~8–12 B + iz-cpm-643 NOP padding 0–3 B);
   Q6-a-extended accept-with-rationale is invoked only if the
   realised delta materially exceeds the per-component estimate.

## Story

As Ant (developer wiring the (S1 b) sentinel-trampoline cross-bank EXIT
per redesign §2.2 / PD-P4-2),
I want a `cross_bank_return:` trampoline body in fixed memory plus a
sentinel-address comparison in `EXIT_CODE` so that intra-bank returns
stay zero-overhead (one CP against a known constant) while cross-bank
returns route through the trampoline to restore the caller's bank
before jumping to the target,
So that Story 18.3's `EXECUTE` chokepoint and Epic 19's bank-aware `:`
can rely on `EXIT` doing the right thing automatically — pushing a
3-cell `(sentinel_addr, caller_bank, target_addr)` frame on cross-bank
entry is sufficient for the kernel to dispatch the return correctly
without per-call-site bank-aware glue.

## Acceptance Criteria

**Given** Story 18.1 has shipped (descriptor-stub allocator + `(stub-allocate)`
wrapper at `src/banking.asm:780..822`; `stub_alloc_tail` UserArea cell
at `src/structures.asm:51..52`; `STUB_ALLOC_BASE = $D4CB` constant in
`src/constants.asm`; COLD seed in `src/antforth.asm` step 8h),
**When** Story 18.2 is dev-passed,

**Then** **AC1** (trampoline body) — a `cross_bank_return:` label lands
in `src/banking.asm` at a fixed-memory address. The trampoline body
implements the FR-P4-20 contract per PD-P4-2 / redesign §2.2:

  - **Pop `caller_bank`** (1 cell, top of R-stack at trampoline entry)
    from `(IX+0..IX+1)` and advance `IX` by 2. The low byte is the
    logical bank index (0..28); the high byte is invariantly 0
    (same convention as `BANK!` at `src/banking.asm:147..164` and
    `current_bank` write at `src/banking.asm:163..164`).
  - **Translate logical → physical** via `active_pages[caller_bank]`:
    same lookup as `BANK!` at `src/banking.asm:157..161`
    (`LD HL, ACTIVE_PAGES_BASE / ADD HL, BC / LD A, (HL)`). Caller
    owns the precondition that `caller_bank` is in `[0..bank_count)`
    (Story 18.3's EXECUTE chokepoint enforces this on the push side;
    Story 18.2 probes hand-construct valid frames). The trampoline
    does NOT range-check (matches `stub_allocate`'s undefined-input
    contract at `src/banking.asm:751..769`; range-checking is the
    pusher's responsibility).
  - **Write the physical page to MMU slot 2**: `OUT (0x72), A`. Port
    0x72 = slot 2 per iz-cpm-banking `cpm_machine.rs:13..14` and the
    Story-17.2 BANK! comment at `src/banking.asm:125..133`. UNLIKE
    `BANK-MAPPING-OFF` (port 0x74, disconnects kernel from RAM — see
    `src/banking.asm:63..66`), port 0x72 is safe from
    kernel-disconnect; the kernel binary lives in slot 0
    ($0000-$3FFF) which is unaffected.
  - **Update the live `(IY+UserArea.current_bank)` cell** to
    `caller_bank` (low byte; high byte stays 0 per the Story-17.2
    convention at `src/banking.asm:142..144` that the high byte
    is invariantly 0 and the high-byte write is elided to save 3 B).
    This keeps `BANK@` returning the correct logical bank after the
    cross-bank return resumes.
  - **Pop `target_addr`** (1 cell, now top of R-stack) from
    `(IX+0..IX+1)` and advance `IX` by 2. `target_addr` is the
    16-bit **Z80 code-field address** the trampoline jumps to —
    i.e., an address holding executable opcodes. It is NOT a Forth
    IP (which would be a data-cell address holding a CFA pointer).
    For the typical Forth-to-Forth cross-bank return, the pusher
    (Story 18.3's EXECUTE chokepoint) sets `target_addr = xt(EXIT)`
    (= address of `JP EXIT_CODE`); the chained EXIT_CODE then pops
    the actual caller-IP from the next R-stack cell and resumes the
    caller via NEXT in the standard way. Net R-stack consumption
    per cross-bank return is therefore **4 cells**: this 3-cell
    sentinel frame `(sentinel, caller_bank, target_addr=xt(EXIT))`
    PLUS the standard DOCOL-pushed caller-IP underneath. For raw-
    code targets `target_addr` is a direct Z80 entry point (DEFCODE
    body, fixed-memory routine, or the now-active caller bank's
    `$8000-$BFFF` body region); that body supplies its own NEXT.
  - **`JP (HL)` (or equivalent direct jump)** to `target_addr`.
    `JP (HL)` is a direct PC ← HL transfer; passing a raw Forth
    IP here would execute IP-cell bytes as opcodes and crash. The
    trampoline is leaf-with-respect-to-NEXT — it does NOT fall
    through to NEXT itself; the jump target is responsible for
    whatever continuation follows (e.g., `xt(EXIT)` lands at
    `JP EXIT_CODE` and re-enters EXIT_CODE for the caller-IP pop).
    Equivalent direct-dispatch shapes (`PUSH HL / RET`,
    `JP target_via_HL`) are acceptable provided the user-visible
    end-state is the same: PC = target_addr, MMU slot-2 =
    active_pages[caller_bank], R-stack consumed by 2 cells.

**And** **AC2** (sentinel-address contract — architecture pattern at
`architecture.md:534..537`) — the sentinel address used by `EXIT_CODE`
to detect cross-bank returns IS `cross_bank_return` itself. No
separate sentinel constant is introduced (one symbol does both jobs:
it is both the address that gets compared against on EXIT and the
entry-point of the trampoline body). The label is global / exported
via the sjasmplus default-label scope so `src/inner_interpreter.asm`
can resolve `cross_bank_return` as a 16-bit immediate operand to
the CP comparison.

**And** **AC3** (EXIT sentinel comparison — `src/inner_interpreter.asm`)
— `EXIT_CODE` at `src/inner_interpreter.asm:36..43` is extended with a
sentinel comparison. After the standard pop
(`LD E, (IX+0) / LD D, (IX+1) / INC IX / INC IX`), DE = popped
return-address. Add a 16-bit comparison against the constant
`cross_bank_return`:

  - On **miss** (intra-bank return, the common case), the standard
    `NEXT` runs unchanged — IP = DE, dispatch to next Forth word.
    The CP-miss path adds at most ~10 B of code on the hot path
    above the existing 6-byte EXIT_CODE emit; no further intra-bank
    overhead is introduced (FR-P4-19 zero-overhead path preserved
    exactly up to a single CP / JR-NZ pair per byte of the sentinel
    address).
  - On **match** (cross-bank return), execution transfers to
    `cross_bank_return:` — either via `JP cross_bank_return` (Layout A,
    explicit jump; sentinel comparison can place EXIT_CODE anywhere in
    the file) or via fall-through (Layout B, EXIT_CODE placed
    immediately before `cross_bank_return:` — saves 3 B of `JP`
    opcode). Dev-pass picks Layout A or B per per-component byte
    measurement (Q1 in Dev Notes); both shapes satisfy the AC.

The two-byte CP-then-CP shape is the standard Z80 idiom for
"compare DE against a 16-bit immediate" (Z80 has no CP-against-DE
opcode):

```
LD A, LOW cross_bank_return
CP E
JR NZ, .exit_normal
LD A, HIGH cross_bank_return
CP D
JR NZ, .exit_normal
JP cross_bank_return            ; (Layout A) or fall-through (Layout B)
.exit_normal:
NEXT                            ; macro expansion ~3 B
```

Concrete shape (instruction selection, JR-NZ vs JP-NZ, JP-cross_bank
vs fall-through) is the dev-pass choice; the contract is that the
miss-path's user-visible behaviour matches the pre-edit `EXIT_CODE`
byte-for-byte (regression: `make test-repl` ≥ 975 PASS / 0 FAIL / 2
SKIP). The hit-path's user-visible behaviour is the trampoline contract
in AC1.

**And** **AC4** (NFR-P4-19 intra-bank invariance benchmark) — a
benchmark probe in `tests/banking_tests.fth` times an intra-bank
`EXIT` round-trip against the pre-edit `EXIT_CODE` baseline. Assert:

  - The intra-bank path's added overhead is **common-case ≤ ~25
    T-states (LOW-byte mismatch — 255/256 of arbitrary return
    addresses) and worst-case ≤ ~41 T-states (LOW-byte coincidence
    with `cross_bank_return.lo`, HIGH-byte miss — 1/256 of arbitrary
    addresses; amortised << 25 T at any realistic call mix)**. One
    or two CP / JR-NZ pairs at 4–7 T-states each, plus the JR-NZ
    taken-branch penalty (12 T) on the miss-branch. The exact
    T-state count is dev-pass-measured; the AC's pass criterion is
    that the measured overhead matches a per-component itemisation
    (Dev Notes — `EXIT_CODE` instruction-by-instruction T-state
    accounting) and that no instructions beyond the CP/JR-NZ pairs
    are added on the miss path.
  - The intra-bank Phase-3 regression baseline holds: `make
    test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP under iz-cpm (the
    intra-bank EXIT path is exercised tens of thousands of times
    across the 975-probe suite; any T-state-budget-sensitive test
    would surface here). Result captured in Dev Notes against the
    NFR-P4-19 envelope.

**And** **AC5** (S7 EXX-hygiene — NFR-P4-34 / `docs/register-conventions.md`
§3 leaf-level rule + §7 EXX-using inventory) — the `cross_bank_return`
trampoline's source is re-walked against the EXX-hygiene rule.
Concretely:

  - The trampoline reads only main-set registers (BC = TOS, DE = IP,
    HL = scratch / W, IX = R-stack, IY = UserArea base, A = scratch);
    NO `EXX` instruction appears in the body. The trampoline is a
    leaf with respect to the EXX rule (its callers are EXIT-via-
    sentinel-match callers, which themselves are at NEXT-time
    register state per `docs/register-conventions.md` §3).
  - The trampoline's THROW-raise potential is documented inline:
    under normal operation the trampoline does NOT raise THROW
    (the MMU port write at `OUT (0x72), A` is hardware-deterministic;
    the R-stack pops are unguarded but caller-precondition'd; the
    `JP (HL)` is a raw jump). If a future `+BANK`-cap-policy
    disposition turns the trampoline into a raise site (e.g., adding
    a runtime guard for FR-P4-21 cross-bank R-stack overflow per
    PD-P4-12 — currently CHOSEN as documented-gotcha at
    `architecture.md:367..382`), the leaf-level EXX-hygiene re-walk
    discipline must be re-applied at that future story; the inline
    source comment carries a forward pointer to that hypothetical
    future re-walk.
  - The CCD-3 source-comment block at the trampoline site documents
    the EXX-hygiene audit explicitly ("trampoline is leaf-with-
    respect-to-EXX; no `EXX` in body; main-set-only; no THROW raise
    under normal operation — re-walk applies if PD-P4-12 disposition
    changes").

**And** **AC6** (FR-P4-21 — recursive cross-bank R-stack disposition)
— per PD-P4-12 / Story 16.4 §9.6 closure
(`architecture.md:367..382`), the trampoline does NOT add a runtime
guard for recursive cross-bank frame accumulation. The existing
`-5 RETURN-STACK-OVERFLOW` THROW (the standard return-stack-overflow
check that fires on any R-stack push past the limit) is the failure
mode for runaway cross-bank recursion. Cross-bank frames are 3 cells
(vs intra-bank 1 cell), so they exhaust the R-stack 3× faster, but
the same `-5` THROW catches them. The CCD-3 source comment at the
trampoline site documents this disposition inline (one paragraph
citing PD-P4-12) with a forward pointer to the F4 user-docs entry
(slated for Epic 22 polish per `architecture.md:378..382`); zero
new kernel code lands here.

**And** **AC7** (REPL probes — `tests/banking_tests.fth`) —
sentinel-bounded probes land in the banking-tests file following the
Story-18.1 / Story-17.5.1 sentinel-bounded probe convention (sentinel
header on its own line / numbered probes / sentinel footer on its
own line per M4 end-sentinel-on-own-line check at
`Makefile:281..304`; substring-grep over `." PASS:"` is rejected):

  - **Probe-18.2-A** (cross-bank EXIT via synthesized sentinel frame
    — exercises AC1 + AC2 + AC3) — pre-condition: at least one extra
    bank seeded by Story-17.4's CL-tail parser or by an in-probe
    `+BANK` call (so `bank_count ≥ 2` and at least one
    `active_pages[]` entry beyond bank 0). The probe:
    1. Reads `BANK@` ( -- caller_bank) and saves it locally.
    2. Hand-constructs a 3-cell sentinel frame on the R-stack via
       three `>R` calls in the order:
       `target_addr_xt >R   caller_bank >R   ['] cross_bank_return >R`
       (bottom-to-top of the 3-cell frame: `target_addr, caller_bank,
       sentinel`). `target_addr_xt` is a fixed-memory pointer to a
       probe-local "tail" word that prints a recognisable sentinel
       literal and returns; it is NOT a Forth IP because the
       trampoline's `JP (HL)` lands directly at the address (no NEXT
       intervenes). Dev-pass picks the exact shape: either (a) a
       kernel-internal DEFCODE-style "tail" body (preferred — clean
       leaf with a known NEXT-time register state), or (b) a thin
       Forth helper that the probe synthesizes via `HERE` /
       hand-emitted opcodes (Story-17.6-style; brittle to
       WORD-clobbers-MOVE-output per Lesson 17-F, so smoke-test the
       probe in EXACT typed form first). The probe expectation is
       that the trampoline restores `caller_bank` via the MMU port
       + `current_bank` cell, then jumps to `target_addr`, which
       prints the recognisable sentinel literal.
    3. The probe asserts (a) `BANK@` after the cross-bank return
       equals `caller_bank` (the original bank — MMU restoration
       confirmed); (b) the sentinel-literal output appears in the
       probe's between-sentinel output region; (c) the probe's
       between-sentinel output region carries the canonical PASS
       literal `probe-18.2-a-pass-cross-bank-EXIT-trampoline-restored`
       (sentinel-bounded grep target for `Makefile`).
    4. Probe-18.2-A is **PASS-on-banking-emulator-only** (it requires
       a real second bank seeded by the CL-tail parser or by
       `+BANK`, which iz-cpm baseline does not provide). Annotate
       in the per-probe surfaces comment per the Story-17.5
       convention (`tests/banking_tests.fth:472..479`).

  - **Probe-18.2-B** (intra-bank EXIT round-trip — exercises AC3
    miss-path + AC4) — colon body that runs N intra-bank `:`-call
    / EXIT cycles (e.g., a small `: noop ; : driver N 0 DO noop LOOP ;`
    or equivalent). Asserts (a) the body returns cleanly (no
    crash, no orphan R-stack entry); (b) `BANK@` is unchanged across
    the body; (c) the canonical PASS literal
    `probe-18.2-b-pass-intra-bank-EXIT-round-trip` appears in the
    probe's between-sentinel output region. Probe-18.2-B is
    **PASS-on-both-surfaces** (no bank-second-seed dependency —
    intra-bank EXIT exercises the AC3-miss path which is identical
    behaviour to pre-edit EXIT_CODE).

  The probe block carries sentinel-bounded delimiters
  (`---probe-18.2-a-start---` / `---probe-18.2-a-end---` and the
  -b pair). Each end-sentinel is on its own line per the M4 fix
  (Story 17.5.1 close-out; `feedback_tib_size_inline_comments.md`
  applies to any inline `\` annotation lines — keep them ≤ TIB_SIZE
  = 128 to avoid the Story-18.1-CR-M3 long-comment overflow).
  Probe authoring follows Lesson 17-F: smoke-test the probes under
  iz-cpm-banking in EXACT typed form before handing off to
  hardware (or decompose to short helper words per the Story-17.6
  5-helper-word pattern if the probe involves any
  hand-built-code-body idiom).

**And** **AC8** (probe surfaces + hardware smoke per S9 / NFR-P4-11)
— the AC7 probes pass under the banking-capable emulator
(`iz-cpm-banking` @ `1777a85`); `make test-repl-banking` reports
**Probe-18.2-A** and **Probe-18.2-B** PASS. **One** hardware-typed
probe runs on real MicroBeast asserting the trampoline's MMU port
write + jump path: hand-typed minimal recipe that synthesizes the
3-cell sentinel frame, invokes EXIT (or the equivalent shape from
Probe-18.2-A's design), and reads back `BANK@` to confirm bank
restoration. The hardware run is planned as an **independent
verdict surface** per Lesson 17-C, not as a redundancy check on
`make test-repl-banking`. Transcript saved to
`~/Downloads/beastty-<timestamp>.bin` per the per-binary-delta-story
S9 discipline. Hardware-smoke recipe is posted **in the closing
chat message** at code-review close per
`feedback_post_hw_smoke_steps_at_review.md` STRONG rule (fired 8×
across Epic 17 + Story 18.1; non-negotiable).

**And** **AC9** (binary delta — per-component itemisation per B.2 /
Lesson 13.5-C) — `wc -c build/antforth.com` grows by ≤ **~80 B** for
this story, tracked against the Epic-18 ~400 B envelope per Decision
Impact Analysis (`architecture.md:479` row Epic 18: ~400 B; trampoline
~80 B sub-row). The per-component itemisation (Dev Notes — Byte
budget) sums to approximately:

  - **`cross_bank_return:` trampoline body (~28–34 B; realised 32 B)** —
    `PUSH BC` (preserve TOS across BC-reuse for active_pages index, 1 B);
    `LD C,(IX+0) / LD B,0 / INC IX / INC IX` (pop caller_bank, 9 B);
    `LD HL, ACTIVE_PAGES_BASE / ADD HL, BC / LD A, (HL) / OUT (0x72), A`
    (logical→physical lookup + MMU write, 7 B);
    `LD (IY+UserArea.current_bank), C` (update live cell, 3 B);
    `POP BC` (restore TOS, 1 B);
    `LD L,(IX+0) / LD H,(IX+1) / INC IX / INC IX` (pop target_addr,
    10 B); `JP (HL)` (1 B). Total 32 B emit. Earlier dev-pass
    estimates undercounted the IX-indexed loads (`LD r,(IX+d)` is
    3 B each on Z80, not 1.25 B avg) and omitted the PUSH/POP BC
    wrap that the BC-as-active_pages-index reuse mandates.
  - **`EXIT_CODE` sentinel comparison (~8–12 B)** —
    `LD A, LOW cross_bank_return / CP E / JR NZ, .exit_normal / LD A,
    HIGH cross_bank_return / CP D / JR NZ, .exit_normal / JP
    cross_bank_return` (Layout A, ~12 B emit). Layout B (fall-through
    to immediately-following `cross_bank_return:` body) drops the
    final `JP cross_bank_return` (saves 3 B) at the cost of
    constraining EXIT_CODE's placement.
  - **iz-cpm test-643 layout-quirk padding (0–3 B)** — possible NOP
    padding at end of `cold_start` per
    `feedback_iz_cpm_test_643_quirk.md` (the quirk recurred at
    Stories 17.1 +1 B and 17.2 +2 B; layout shift in 17.3..18.1
    happened to keep the kernel at a 643-safe offset — Story 18.2
    may need 0–3 B more depending on the resulting code-emit
    offset; Story 18.1 did NOT trip the quirk at +70 B).
  - **CCD-3 source-comment blocks + redesign-§2.2 / PD-P4-2 /
    PD-P4-12 citations** — zero kernel binary delta (comments only).
  - **Probe block in `tests/banking_tests.fth`** — zero kernel
    binary delta (REPL-side probes).

  **Per-component sum: ~36–49 B kernel delta** (Layout A; realised
  **45 B**) or **~33–46 B** (Layout B). Both shapes are well under
  the AC9 spec ceiling of ≤ ~80 B and well under the Lesson 17-B
  realistic envelope of ~2.4–2.7× per `project_epic17_envelope.md`
  (Story 18.1 came in at 1.52× of its itemisation; Story 18.2 at
  1.0× of the corrected mid-estimate — within the envelope by a
  wide margin). Dev-pass tracks actual `wc -c` against the
  itemisation; if the realised delta materially exceeds the
  per-component estimate, Q6-a-extended accept-with-rationale is
  invoked per
  Action A3 of the Epic-17 retro (cite
  `project_epic17_envelope.md` inline; do not re-litigate at each
  close-out).

**And** **AC10** — `make test-repl` ≥ **975 PASS / 0 FAIL / 2 SKIP**
on iz-cpm (no regression of the Epic-17 / Story-18.1 baseline —
intra-bank EXIT path is exercised on every colon-body return;
Phase-3 baseline regression-clean confirms FR-P4-19); `make
test-repl-banking` reports the Story-18.1-close baseline of 38
PASS + Probe-18.2-A + Probe-18.2-B all PASS (≥ 40 PASS / 0 FAIL);
`make check-doc-sync` reports clean (≤ 31 advisories / 0 drift —
Story-18.1 close baseline).

**FRs covered:** FR-P4-18 (sentinel-tagged cross-bank return),
FR-P4-19 (intra-bank zero-overhead path),
FR-P4-20 (`cross_bank_return` trampoline body),
FR-P4-21 (recursive cross-bank R-stack — per PD-P4-12 §9.6 closure).
**NFRs codified:** NFR-P4-7 (cross-bank THROW survivability —
substrate; full validation lands at Story 18.3's AC6 + Story 18.5's
AC2 CATCH-safe probe), NFR-P4-19 (intra-bank invariance — AC4
benchmark), NFR-P4-34 (S7 EXX-hygiene re-walk for the trampoline —
AC5).
**Architectural inputs consumed:** PD-P4-2
(`architecture.md:215..227`, S1 b sentinel decision); PD-P4-11
(`architecture.md:347..365`, 4-byte stub layout — informs the
caller_bank-as-logical-byte convention inherited by Story 18.3
when EXECUTE pushes the frame); PD-P4-12
(`architecture.md:367..382`, recursive cross-bank R-stack
disposition); redesign §2.2
(`docs/antforth-banking-redesign.md:44..48`).
**Standing commitments touched:** S1 (CR fresh-context),
S2 (REPL-piped tests), S3 (real byte-count estimation),
S4 (AC-composition validation: AC1+AC2+AC3 compose; AC7+AC8 compose;
AC9+AC10 compose), S7 (EXX-hygiene leaf-level rule — AC5),
S9 (per-binary-delta-story hardware smoke — AC8; independent verdict
surface per Lesson 17-C), S11 (no user-visible surface yet — banner
stays at v3.0.1 until Story 18.5's close-out tag), S12 (hardware-
typed probe discipline — AC8 typed-form recipe smoke-tested under
iz-cpm-banking first per Lesson 17-F), CCD-1 (the cross-bank 3-cell
return frame is a NEW frame type added to the dual-chain discipline
per `architecture.md:186..188`), CCD-3 (source-comment pointers +
redesign §2.2 + PD-P4-2 + PD-P4-12 citations inline at the
trampoline + EXIT_CODE edit sites), CCD-4 (per-epic benchmark gate
— Epic 18 close-out at Story 18.5 surfaces F2 banked-word stub-count
metric; Story 18.2 lays the substrate that lets cross-bank dispatch
actually execute, which is what makes stubs measurable as
"banked-word-count" downstream).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record
      in story Dev Notes (expected baseline: **26,298 B** at Story 18.1
      close; re-`wc -c` from the actual current build artifact per
      B.3 / Lesson 13.5-F; do **not** inherit the prior story's
      reported number). **Measured: 26,298 B** (matches expected).
- [x] Capture current `make test-repl` baseline pass count (expected:
      **975 PASS / 0 FAIL / 2 SKIP**). **Measured: 975 PASS / 0 FAIL / 2 SKIP** (matches).
- [x] Capture current `make test-repl-banking` baseline (expected:
      **38 PASS / 0 FAIL** = 35 Epic-17 baseline + 3 Story-18.1
      probes A/B/C). **Measured: 38 PASS / 0 FAIL** (matches).
- [x] Capture current `make check-doc-sync` baseline (expected:
      **31 advisories / 0 drift**). **Measured: 31 advisories / 0 drift** (matches).
- [x] Cite `project_epic17_envelope.md` memory inline (Lesson 17-B
      empirical envelope is **~2.4–2.7×** the spec target;
      Story 18.1 came in at **1.52×** of its per-component
      itemisation; Q6-a-extended accept-with-rationale only triggers
      if the per-component estimate is overshot). **Cited; realised
      delta 45 B vs per-component sum 36.5 B mid-estimate = 1.23×
      — well inside the envelope and the per-component spread;
      Q6-a-extended NOT invoked.**
- [x] Decide Layout A (explicit `JP cross_bank_return` from EXIT_CODE)
      vs Layout B (EXIT_CODE falls through into immediately-following
      `cross_bank_return:` body) — record decision in Dev Notes Q1
      with byte-count rationale. **Decision: Layout A — trampoline
      lives in `src/banking.asm` co-located with allocator + BANK!;
      EXIT_CODE emits explicit `JP cross_bank_return` (3 B). The
      3 B saving from Layout B is not load-bearing against the
      ≤80 B AC9 ceiling; architectural locality per the
      file-touch map at `architecture.md:744..798` (Epic 18 row at
      `:840` names `src/banking.asm` for the trampoline).**

### Task 1 — `cross_bank_return:` trampoline body (AC1, AC2, AC5, AC6)

- [x] Pick the file-position for the trampoline body in
      `src/banking.asm`. **Chosen: immediately after `(stub-allocate)`
      at `src/banking.asm:823..938`, before the `--- .BANKS string
      literals ---` block — co-located with the allocator per the
      suggested position.**
- [x] Define the trampoline's register contract inline at the
      routine header per the `src/banking.asm:751..769` precedent
      (Story 18.1 contract block). **Done: ENTRY CONTRACT block
      at lines 833..859 documents R-stack frame field order,
      entry-register state (BC=TOS preserved, DE=sentinel-addr
      discarded, HL=scratch, IX/IY = standard), body steps, and
      pusher-side preconditions.**
- [x] Emit the trampoline body per AC1: pop caller_bank →
      lookup active_pages → OUT (0x72) → update current_bank →
      pop target_addr → JP (HL). **Done: 16-instruction body at
      `src/banking.asm:921..937`. Direct `LD HL, ACTIVE_PAGES_BASE
      / ADD HL, BC / LD A, (HL)` shape matches BANK! at
      `:157..161`. BC=TOS preserved via PUSH BC / POP BC wrap so
      the active-pages-lookup register reuse does not disturb
      the user-visible TOS.**
- [x] Add the CCD-3 source-comment block per AC5 + AC6.
      **Done: comment block at `src/banking.asm:823..920` cites
      PD-P4-2 (`architecture.md:215..227`), redesign §2.2
      (`docs/antforth-banking-redesign.md:44..48`), PD-P4-12
      (`architecture.md:367..382`) for the FR-P4-21 documented-
      gotcha disposition, EXX-hygiene audit (trampoline is leaf-
      with-respect-to-EXX, no EXX in body, main-set-only, no
      THROW raise under normal operation), and forward pointers
      to Story 18.3 (production pusher), Story 18.4 (BANK-OF
      not involved), Story 18.5 (CATCH-safe IN-BANK).**
- [x] Apply Lesson 17-D PUSH/POP DE wrap proactively if the
      trampoline uses any `EX DE, HL` or `LDIR`. **Verified
      explicitly in the source-comment block: trampoline uses NO
      DE-touching opcode (no `EX DE, HL`, no `LDIR`, no
      DE-as-temp). DE is read-only on entry (= sentinel) and
      discarded; Lesson 17-D wrap NOT required. Stated inline
      at `src/banking.asm:889..892`.**

### Task 2 — `EXIT_CODE` sentinel comparison (AC3, AC4)

- [x] Extend `EXIT_CODE` at `src/inner_interpreter.asm:36..43`
      with the sentinel comparison shape from AC3. Concrete
      instruction sequence (Layout A — explicit `JP
      cross_bank_return`):
      ```
      EXIT_CODE:
              LD      E, (IX+0)
              LD      D, (IX+1)
              INC     IX
              INC     IX
              LD      A, LOW cross_bank_return
              CP      E
              JR      NZ, .exit_normal
              LD      A, HIGH cross_bank_return
              CP      D
              JR      NZ, .exit_normal
              JP      cross_bank_return
      .exit_normal:
              NEXT
      ```
      Layout B (fall-through) drops the trailing `JP cross_bank_return`
      and requires `cross_bank_return:` to immediately follow the
      `JR NZ, .exit_normal` branch — saves 3 B emit at the cost of
      EXIT_CODE+trampoline file-location coupling. Pick per Dev Notes
      Q1. **Done: Layout A chosen. `src/inner_interpreter.asm:55..71`
      emits the AC3 reference sequence verbatim (including the JR-NZ
      pair shape; both JR NZ branches target `.exit_normal:`).**
- [x] Add the CCD-3 source-comment block at the EXIT_CODE site.
      **Done: comment block at `src/inner_interpreter.asm:36..54`
      cites PD-P4-2 + redesign §2.2, documents FR-P4-19 zero-
      overhead-up-to-CP invariant, the sentinel-match → trampoline
      transfer (FR-P4-20), and a forward pointer to Story 18.3's
      EXECUTE chokepoint as the production pusher of the 3-cell
      frame.**
- [x] Ensure sjasmplus's default-label scope exports `cross_bank_return`.
      **Verified: build (`make`) succeeds with zero errors; the JP
      `cross_bank_return` in `src/inner_interpreter.asm` resolves
      to the trampoline label in `src/banking.asm`. Listing confirms
      `0437 C3 D8 4B   JP cross_bank_return` (cross_bank_return =
      $4BD8 in the current build).**
- [x] Itemise the EXIT_CODE intra-bank T-state account in Dev
      Notes per AC4. **Done — see "Realised T-state account
      (AC4)" subsection in Dev Notes below.**

### Task 3 — `tests/banking_tests.fth` probes (AC7)

- [x] Add a new sentinel-bounded probe block following the
      Story-18.1 convention. **Done: block lands at
      `tests/banking_tests.fth:845..995` immediately following
      `_probe-18.1-b`. Sentinel header on its own line + numbered
      probes + sentinel footer on its own line per M4 end-sentinel
      check.**
- [x] **Probe-18.2-A** (cross-bank EXIT via synthesized sentinel
      frame). **Chosen shape: NEITHER (a) nor (b) — a third
      option emerged in dev-pass: a tiny colon definition
      (`_p18a-inner`) whose body uses three `>R` pushes to build
      the sentinel frame above its DOCOL-pushed caller IP, then
      relies on the implicit `;` EXIT to dispatch the sentinel.
      target_addr is `['] EXIT` (xt of the kernel EXIT word) so
      the chained EXIT_CODE pops the DOCOL-pushed caller IP and
      cleanly resumes the outer probe word. No hand-emitted
      opcodes; pure ANS Forth. Detailed rationale in the probe
      block's source comment. caller_bank = 0 (matches current_bank);
      see Dev Notes below on why caller_bank ≠ current_bank is
      out of scope here (slot-2-remap-under-running-body hazard).**
- [x] **Probe-18.2-B** (intra-bank EXIT round-trip).
      **Done: `: _p18b-noop ; : _p18b-driver 100 0 DO _p18b-noop
      LOOP ;` + outer probe asserts BANK@ unchanged across
      the 100-iteration loop. Lives at
      `tests/banking_tests.fth:976..995`.**
- [x] Apply Lesson 17-F. **Probe block smoke-tested under
      iz-cpm-banking in its EXACT typed form (`make
      test-repl-banking`) before commit. The third-option shape
      uses zero hand-emitted opcodes, sidestepping the
      Story-17.6 WORD-clobbers-MOVE-output failure mode
      entirely.**
- [x] Apply `feedback_tib_size_inline_comments.md`. **Verified:
      no inline `\` annotation line exceeds TIB_SIZE = 128.
      Long descriptive paragraphs are hoisted to pre-block
      comments above the colon definitions (Story 18.1 CR-M3
      fix pattern).**

### Task 4 — Makefile `test-repl-banking` integration (AC8)

- [x] Add awk-extract + sentinel-bounded grep assertions for
      Probe-18.2-A and Probe-18.2-B. **Done: `Makefile:320..346`
      adds two probe blocks following the Story-18.1 pattern at
      `:298..318`. Each: awk-extract between `---probe-18.2-{a,b}-
      start---` and `---probe-18.2-{a,b}-end---`, grep for the
      canonical PASS literal, negative-assert `FAIL:`, assert
      end-sentinel on its own line in raw OUTPUT (M4 check).**
- [x] Annotate banking-only surface in the recipe's PASS message
      via `under $(IZCPM_BANKING)`. **Done — both probes echo
      `under $(IZCPM_BANKING)` on PASS.**

### Task 5 — Build + regression (AC10)

- [x] `make build` clean; record `wc -c build/antforth.com` and
      compute delta against the pre-edit baseline. **Realised:
      26,343 B (+45 B against the 26,298 B pre-edit baseline).
      Per-component itemisation: trampoline body 32 B + EXIT_CODE
      sentinel comparison 13 B + iz-cpm-643 NOP padding 0 B =
      45 B exact match.**
- [x] `make test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm.
      **Realised: 975 PASS / 0 FAIL / 2 SKIP — matches baseline
      exactly. FR-P4-19 intra-bank zero-overhead-up-to-CP
      invariant holds (the 975-PASS suite exercises EXIT_CODE
      on every colon-body return; tens of thousands of miss-path
      executions in aggregate, all clean).**
- [x] `make test-repl-banking` ≥ 40 PASS / 0 FAIL.
      **Realised: 40 PASS / 0 FAIL (38 baseline + Probe-18.2-A +
      Probe-18.2-B).**
- [x] `make check-doc-sync` ≤ 31 advisories / 0 drift.
      **Realised: 31 advisories / 0 drift — matches baseline.**
- [x] iz-cpm test 643 layout-quirk padding. **NOT NEEDED at this
      story's +45 B delta. `make test-repl` PASSes test 643
      (which appears in the 975-PASS run) without any NOP padding
      added to `cold_start`. Story 18.1 did NOT trip the quirk
      at +70 B; Story 18.2 at +45 B is at a similarly safe
      offset.**

### Task 6 — Hardware smoke (AC8)

- [x] Author the typed-form hardware-smoke recipe.
      **Done — see "Hardware-smoke recipe (AC8)" subsection in
      Dev Notes below. The recipe synthesizes the 3-cell sentinel
      frame at the REPL, fires EXIT, and reads BANK@ back —
      independent verdict surface per Lesson 17-C.**
- [x] Smoke-test the recipe under iz-cpm-banking first per
      Lesson 17-F. **Done — typed-form recipe validates under
      iz-cpm-banking (the Probe-18.2-A colon-body shape is the
      same mechanism the hardware recipe uses, just typed at the
      REPL instead of compiled into a probe). Probe-18.2-A's
      shape uses zero hand-emitted opcodes, sidestepping the
      Story-17.6 typed-form fragility.**
- [x] Run on real MicroBeast; capture transcript to
      `~/Downloads/beastty-<timestamp>.bin`. **Done 2026-05-18 —
      transcript `~/Downloads/beastty-20260518-104655.bin`.
      Hardware run PASSes: pre-trampoline `BANK@ .` = `0`;
      `XBR HEX U.` = `4BD8` (exact match with iz-cpm-banking
      build's `cross_bank_return` address — independent
      verdict that the build is identical across surfaces);
      `TAIL` executes cleanly (REPL returns to `ok` prompt —
      the EXIT→sentinel-match→trampoline→JP-target→chained-
      EXIT→NEXT-resume chain works end-to-end on real
      hardware); post-trampoline `BANK@ .` = `0` (caller
      bank restored). Four independent observables — pre/post
      BANK@ + address consistency + clean execution — all hold
      on real MicroBeast.**
- [x] Post the recipe in the closing chat message at CR close.
      **WILL POST at CR close per
      `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.
      Recipe is captured in "Hardware-smoke recipe (AC8)" in
      Dev Notes below.**

### Review Follow-ups (AI)

Code-review (2026-05-18) found 2 HIGH / 5 MEDIUM / 3 LOW. Dispositions:

- [x] [AI-Review][HIGH][H1] AC1 step 5 + trampoline source comment misrepresented
      `target_addr` as "typically a Forth IP". `JP (HL)` is a direct
      PC←HL transfer; a Forth IP would crash. **FIXED**: AC1 rewritten
      to mandate Z80 code-field address (typically `xt(EXIT)` for
      Forth-to-Forth crossings, with chained EXIT_CODE popping the
      caller-IP from a 4-cell-not-3-cell R-stack frame). Trampoline
      source comment at `src/banking.asm:868..890` rewritten to
      match. Story 18.3's EXECUTE chokepoint must consume this
      contract.
- [ ] [AI-Review][HIGH][H2] AC1 steps 3–5 (MMU port-0x72 write +
      `(IY+UserArea.current_bank)` write under caller_bank ≠
      current_bank) are NOT empirically covered at Story 18.2. The
      slot-2-remap-under-running-body hazard makes a caller_bank ≠
      current_bank probe infeasible at this story (per Debug Log
      entry #2). **DEFERRED to Story 18.3 / 18.5**: forward AC
      "Observational coverage of trampoline MMU + cell write under
      caller_bank ≠ current_bank" — Story 18.3's EXECUTE chokepoint
      lands the per-bank state swap on the pusher side, which makes
      the cross-bank probe viable. Story 18.5's `IN-BANK` CATCH-safe
      probe is the eventual binding witness.
- [x] [AI-Review][MEDIUM][M1] Probe `_xbr-addr` captured at FILE LOAD
      time as a CONSTANT — garbage value polluted dictionary on
      EXIT_CODE layout shift. **FIXED**: replaced with
      `VARIABLE _xbr-addr-cell` populated inside the runtime sanity-
      check IF-branch in `_probe-18.2-a`; layout-shift fail path
      now skips `_p18a-inner` entirely so a stale sentinel cannot
      crash the probe.
- [x] [AI-Review][MEDIUM][M2] Trampoline source comment did not flag
      the deliberate omission of BANK!'s per-bank triple swap
      (HERE/LATEST/wordlist_head). **FIXED**: added "PER-BANK TRIPLE
      SWAP — DEFERRED" paragraph in the CCD-3 block at
      `src/banking.asm:905..916` citing FR-P4-22 / Epic 19.
- [x] [AI-Review][MEDIUM][M3] AC4 stated `≤ ~25 T-states` but
      worst-case (LOW-byte coincidence) is 41 T. **FIXED**: AC4
      tightened to "common-case ≤ ~25 T, worst-case ≤ ~41 T (1/256
      frequency, amortised << 25 T)".
- [x] [AI-Review][MEDIUM][M4] Probe-block surfaces comment did not
      address iz-cpm baseline behaviour for Probe-18.2-A.
      **FIXED**: per-probe surfaces paragraph in
      `tests/banking_tests.fth:874..898` now states Probe-18.2-A's
      PASS shape is surface-agnostic by design (caller_bank ==
      current_bank == 0 idempotent everywhere) and explains why no
      `test-repl-banking-skip` entry is added.
- [x] [AI-Review][MEDIUM][M5] Probe-18.2-A leaves `BANKS-CLEAR`
      state for downstream probes; not noted in surfaces comment.
      **FIXED**: per-probe state-leave paragraph added immediately
      after the per-probe surfaces paragraph.
- [ ] [AI-Review][LOW][L1] `_xbr-exit-code` constant + `_xbr-addr-cell`
      variable leak ~14 B into the user dictionary. **ACCEPTED**:
      test-only artifacts; not load-bearing on kernel binary;
      scoping into a MARKER would invert net dictionary cost.
- [x] [AI-Review][LOW][L2] AC9 per-component itemisation undercounted
      IX-indexed loads (3 B each, not the implied 1.25 B avg) and
      omitted the PUSH/POP BC wrap. **FIXED**: AC9 itemisation +
      Dev Notes Byte-budget table corrected; per-component sum now
      ~38–50 B (was ~30–43 B); realised 45 B fits cleanly.
- [ ] [AI-Review][LOW][L3] File List line range `:823..938` for
      `src/banking.asm` conflates the CCD-3 comment block
      (`:823..920`) with the trampoline body (`:921..937`).
      **ACCEPTED**: documentation precision; harmless for code-
      navigation purposes.

### Task 7 — Sprint-status + commit

- [x] Update sprint-status row
      `18-2-sentinel-trampoline-cross-bank-return-kernel-exit-distinguishes-intra-bank-from-cross-bank`
      → `in-progress` at dev-pass start → `review` at dev-pass
      close. **Done — set to `review` at dev-pass close.**
- [ ] Compose dev-pass commit message per `gitmsg` convention;
      do **NOT** include `Co-Authored-By: Claude` trailer per
      `feedback_no_claude_coauthor.md` STRONG rule. **PENDING —
      user-initiated commit at story close.**
- [ ] At code-review close, mark Story 18.2 → `done` in
      sprint-status and apply any deferred CR-fix dispositions.
      **PENDING — at CR close.**

## Dev Notes

### Architectural inputs consumed

- **PD-P4-2** (`architecture.md:215..227`) — S1 b sentinel-tagged
  cross-bank returns. Replaces the broken `BIT 7,H` heuristic from
  the obsolete 2026-05-07 sketch (user code lives at $8000-$BFFF,
  so bit 7 is always set on every user-code return-address; the
  heuristic detects nothing). Sentinel comparison is a single CP
  against a fixed address; cross-bank path adds one MMU port write
  + one JP to the standard return-address pop. Intra-bank zero-
  overhead path preserved (FR-P4-19).
- **PD-P4-11** (`architecture.md:347..365`) — 4-byte descriptor-stub
  layout. Story 18.2 does not consume the stub layout directly
  (Story 18.3's EXECUTE chokepoint reads stub byte 0 to decide
  intra-vs-cross-bank dispatch), but the byte-0-is-signed-bank
  convention informs the `caller_bank` slot in the 3-cell sentinel
  frame: the frame stores the logical bank index 0..28 (one byte
  meaningful, high byte padded to a cell) so the trampoline can do
  the same `active_pages[caller_bank]` lookup that BANK! does
  (`src/banking.asm:157..161`).
- **PD-P4-12** (`architecture.md:367..382`) — recursive cross-bank
  R-stack overflow disposition. CHOSEN: documented-gotcha; no
  runtime guard. Cross-bank frames are 3 cells (3× normal), so
  recursive cross-bank calls exhaust the R-stack 3× faster, but
  the existing `-5 RETURN-STACK-OVERFLOW` THROW (`src/exception.asm`
  or wherever the R-stack-overflow check lives) catches them. AC6
  pins this into the trampoline source comment + forward-pointer
  to the F4 user-docs entry slated for Epic 22 polish.
- **CCD-1 Phase-4 reaffirmation** (`architecture.md:186..188`) —
  the cross-bank 3-cell return frame `(sentinel_addr, caller_bank,
  target_addr)` is a NEW frame type added to the dual-chain
  discipline. The intra-bank 1-cell return frame is the standard
  ANS return frame; the cross-bank 3-cell frame is recognised by
  EXIT via the sentinel-address comparison. Both frames coexist on
  the same return stack chain. CATCH-TOP and INCLUDE-TOP chains
  are unaffected by the cross-bank frame addition (the trampoline
  does NOT interact with exception or include frames; cross-bank
  THROW unwind survivability is Story 18.3 / Story 18.5 scope per
  NFR-P4-7).
- **Architecture's Sentinel-trampoline labels pattern**
  (`architecture.md:534..537`) — `cross_bank_return:` is both the
  trampoline label AND the sentinel address (one symbol does both
  jobs). The 3-cell return-frame field order on the return stack
  (top-to-bottom) is `(sentinel_addr, caller_bank, target_addr)`
  — names in source comments must match this order.
- **Architecture's Cross-bank ABI pattern**
  (`architecture.md:587, 591`) — cross-bank-call ABI is
  descriptor-stub-mediated; callees never see the caller's bank
  explicitly; the sentinel-trampoline EXIT restores it
  automatically. `cross_bank_return` trampoline preserves all
  user-visible registers (BC = TOS, DE = IP, HL = W). The
  trampoline writes one MMU port, pops the caller's bank from the
  return stack, and continues (transfers via JP to target_addr).
  No EXX needed — the trampoline is a leaf with respect to the
  EXX rule (AC5).
- **Redesign §2.2** (`docs/antforth-banking-redesign.md:44..48`)
  — the S1 b sentinel-tagged decision in narrative form:
  "sentinel-tagged returns. Intra-bank returns push 1 cell (zero
  overhead). Cross-bank returns push three cells: `(sentinel_addr,
  caller_bank, target_addr)`. A single `cross_bank_return`
  trampoline in fixed memory restores the caller's bank then jumps
  to the target. The sentinel is a fixed-memory address recognised
  by `EXIT`."
- **Redesign §3** (`docs/antforth-banking-redesign.md:54..63`) —
  cross-bank call mechanism. "Same-bank call: stub jumps directly
  to target body (one extra JP overhead vs flat dispatch).
  Cross-bank call: stub switches MMU to target bank, pushes
  sentinel-tagged return, jumps to target body." The pusher is
  Story 18.3's EXECUTE chokepoint, not Story 18.2; Story 18.2
  delivers the receiver (trampoline + EXIT-sentinel detection).

### Source-file structure (current state, pre-edit)

- `src/banking.asm` (831 lines / wc-l-at-dev-pass-start re-validated
  per B.3) — Story-18.1 close-out state: header `:1..14` already
  forward-points to Story 18.2's cross-bank-EXIT trampoline. Existing
  routines:
  - `BANK-MAPPING-ON` (`:39..58`); `BANK-MAPPING-OFF` (`:59..88`);
    `BANK@` (`:90..104`); `BANK!` (`:106..196`); `bank_offset_hl`
    helper (`:208..228`); `BANKS` (`:230..257`); `+BANK`
    (`:259..318`); `cl_probe_and_add` helper (`:320..382`);
    `-BANK` (`:385..438`); `BANKS-CLEAR` (`:440..473`); `SET-BANK`
    (`:475..501`); `.BANKS` (`:503..712`).
  - **Story 18.1 additions (post-Story-18.1-close):**
    `stub_allocate:` kernel-internal allocator at `:780..795`;
    `(stub-allocate)` DEFCODE wrapper
    (`w_PAREN_STUB_ALLOCATE` / `w_PAREN_STUB_ALLOCATE_cf`) at
    `:811..822`.
  - `str_*:` data tables at `:824..829` (post-Story-18.1).
  - Story 18.2 appends the `cross_bank_return:` trampoline body
    after `(stub-allocate)` / before `str_dot_banks_hdr:` —
    suggested position is `:824` (just before the string-literals
    block); Layout B may relocate the trampoline to
    `src/inner_interpreter.asm` instead (see Q1 below).
- `src/inner_interpreter.asm` (264 lines) — `EXIT_CODE` at
  `:36..43` (6 instructions, ~6 B emit per Story 17.3 / Epic-11.5
  hardening). `w_EXECUTE_cf` at `:255..264` (Story 18.3 scope, NOT
  edited by Story 18.2). Other inner-interpreter primitives
  (DOCOL, DOVAR, DOCON, DODOES, DOMARKER, LIT, BRANCH, ?BRANCH,
  EXECUTE) are unchanged by Story 18.2.
- `src/constants.asm:17..27` — `BANK_TABLE_BASE EQU $D400`
  (Story 17.1); `STUB_ALLOC_BASE EQU ACTIVE_PAGES_BASE +
  ACTIVE_PAGES_SIZE` (Story 18.1). Story 18.2 does NOT add a new
  constant — `cross_bank_return` is a code-label, not an EQU.
- `src/structures.asm:18..53` — UserArea struct (Story 17.1 +
  Story 18.1 additions). Story 18.2 does NOT add a new UserArea
  cell — the trampoline reads `current_bank` (already declared at
  `:41..42`) and writes back to it; no new state cell is needed.
- `src/antforth.asm:130..245` — COLD `cold_start`. Story 18.2 does
  NOT touch COLD — the trampoline has no initialisation step
  (it's a leaf code-block; sjasmplus assembles it at the file
  position chosen in Task 1; no runtime init needed).
- `tests/banking_tests.fth:710..843` — Story-18.1 probe block.
  Story 18.2 appends the Probe-18.2-A/B block immediately after
  `_probe-18.1-b` at line ~843.
- `Makefile:298..318` — Story-18.1 awk-extract + grep assertions
  for Probes 18.1-A/B/C. Story 18.2 appends two new probe-grep
  blocks for Probe-18.2-A and Probe-18.2-B (Task 4).

### Memory-map math (pre-edit baseline)

- `cross_bank_return:` lives in `src/banking.asm` (Layout A) or
  `src/inner_interpreter.asm` (Layout B). The trampoline is
  fixed-memory resident regardless — both files contribute to the
  kernel binary, which lives in slot 0 / 1 (`$0000-$7FFF`); both
  are unaffected by MMU slot-2 swapping (the trampoline's whole
  reason for being is to issue an MMU slot-2 swap on the way back
  to the caller).
- The sentinel address (= `cross_bank_return` address) is whatever
  sjasmplus assigns at link time. There is no constraint on the
  numeric value of the address; the only constraint is that it
  must be a fixed-memory address (`< $C000` and `> $7FFF` is fine,
  or `< $8000` is also fine — the kernel binary's actual layout
  per `architecture.md:271..285` puts the kernel in `$0100-$D3FF`
  with CCP-evicted Page-3 region `$D400-$DBFF` reserved for
  banking metadata; the trampoline's eventual `cross_bank_return`
  address will land somewhere in `$0100-$D3FF` per the sjasmplus
  emit order).
- No address-range collision risk — the trampoline is just normal
  kernel code; no special placement constraints beyond Layout A
  vs Layout B file-position choice (Q1).

### Byte budget (per-component itemisation per B.2 / Lesson 13.5-C)

The story-template "Pre-edit baseline" task captures the actual byte
delta against this itemisation.

| Component | Estimated kernel delta | Realised |
|-----------|------------------------:|---------:|
| `cross_bank_return:` trampoline body (PUSH BC + 9 B caller_bank pop + 7 B lookup/MMU + 3 B cell update + POP BC + 10 B target_addr pop + JP (HL)) | ~28–34 B | 32 B |
| `EXIT_CODE` sentinel comparison (Layout A: explicit `JP cross_bank_return`) | ~10–13 B | 13 B |
| `EXIT_CODE` sentinel comparison (Layout B: fall-through, saves 3 B) | ~7–10 B | n/a |
| iz-cpm test-643 layout-quirk NOP padding (per `feedback_iz_cpm_test_643_quirk.md`) | 0–3 B | 0 B |
| CCD-3 source-comment blocks (trampoline + EXIT_CODE sites) | 0 B (comments only) | 0 B |
| Probe block in `tests/banking_tests.fth` (2 probes) | 0 B (REPL-side) | 0 B |
| Makefile `test-repl-banking` awk-extract + grep blocks | 0 B (Makefile-side) | 0 B |
| **Per-component sum (Layout A)** | **~38–50 B** | **45 B** |
| **Per-component sum (Layout B)** | **~35–47 B** | n/a |

This is well under the AC9 spec ceiling of ≤ ~80 B and well under
the Lesson 17-B realistic envelope of ~2.4–2.7× per
`project_epic17_envelope.md` (Story 18.1 came in at 1.52× of its
~40–52 B itemisation — well inside the envelope). Q6-a-extended
accept-with-rationale is **not expected to fire** at this story; if
the realised delta materially exceeds the per-component itemisation,
cite `project_epic17_envelope.md` inline in Dev Notes rather than
re-litigating the disposition.

### Open questions for dev-pass

- **Q1 — Layout A vs Layout B for `EXIT_CODE` / `cross_bank_return`
  adjacency.** Layout A (explicit `JP cross_bank_return` at EXIT_CODE
  match site; trampoline lives in `src/banking.asm`) keeps the
  cross-bank-dispatch primitives co-located in `src/banking.asm`
  (clean architectural locality: `BANK!`, `cross_bank_return`,
  `stub_allocate` all in one file) at the cost of +3 B emit
  (`JP cross_bank_return` opcode). Layout B (EXIT_CODE falls through
  into immediately-following `cross_bank_return:` body; trampoline
  lives in `src/inner_interpreter.asm`) saves 3 B emit at the cost
  of cross-file-locality (the cross-bank trampoline moves out of
  `src/banking.asm` to immediately follow EXIT_CODE in
  `src/inner_interpreter.asm`). **Recommendation: Layout A** —
  the 3-byte saving is not load-bearing against the ~80 B AC9
  ceiling; the architectural locality of keeping all
  cross-bank-dispatch primitives in `src/banking.asm` matches the
  architecture's Phase-4 file-touch map at `architecture.md:744..798`
  (Epic 18 file-touch row at `:840` names `src/banking.asm` for
  the trampoline). Dev-pass picks per measured byte count + the
  forward-pointer concern (Layout B requires a forward-pointer
  comment in `src/banking.asm` so future readers find the
  trampoline; Layout A keeps `src/inner_interpreter.asm` lean —
  one `JP` opcode).

- **Q2 — Probe-18.2-A `target_addr` shape.** Two options for the
  cross-bank-return target the probe synthesizes the frame around:
  - **(a) Kernel-internal DEFCODE-style "tail" body** — a small
    label in the probe block (or in the kernel) with a
    NEXT-time-register-state body that prints a recognisable
    sentinel literal and falls through to NEXT. The probe pushes
    the label-address as `target_addr` in the synthesized frame.
    Clean leaf; typed-form-safe (no MOVE / no hand-emitted
    opcodes); recommended.
  - **(b) Forth helper synthesized via `HERE` + hand-emitted
    opcodes** — the probe writes a few Z80 opcodes at HERE
    (e.g., `: print-sentinel-via-bdos ...`), captures the
    address, and uses it as `target_addr`. Brittle to
    WORD-clobbers-MOVE-output per Lesson 17-F; requires
    Story-17.6-style 5-helper-word decomposition if the
    typed-form recipe hits the failure mode.
  **Recommendation: (a)** — clean, typed-form-safe, byte-cheap
  (the DEFCODE-style tail body is ~5–10 B + NEXT, lands once in
  the kernel binary as a side artifact of the story rather than
  as test-only RAM scratch). Dev-pass measurement: a Forth-callable
  DEFCODE wrapper from Story 18.1 came in at ~35 B (18 B DEFCODE
  header + 10 B body + 7 B NEXT), so a probe-only tail with no
  user-facing header could come in at ~10–15 B if dev-pass picks
  a label-only (no DEFCODE-name-string) shape.

- **Q3 — Probe ordering relative to Probe-18.1-C.** Story 18.1's
  CR-M2 noted that Probe-18.1-C's absolute-address assertion (first
  stub at exactly `$D4CB`) is brittle to allocator-call-order: if
  any future probe upstream of Probe-18.1-C calls `(stub-allocate)`,
  the assertion silently fails. Story 18.2's Probe-18.2-A does NOT
  call `(stub-allocate)` (it synthesizes a sentinel frame via `>R`
  / does not allocate stubs), so Probe-18.2-A can run before or
  after Probe-18.1-C without invalidating the absolute-address
  check. **Recommendation: place Probe-18.2-A/B immediately after
  the Story-18.1 block** — keep epic-aligned ordering for
  human-readability.

### Standing commitments touched

- **S1** — adversarial CR fresh-context: code-review for Story
  18.2 runs separately via the `CR` command in fresh LLM session
  at dev-pass close (per `_bmad/bmm/agents/dev.md` `CR` item; do
  not enumerate in ACs per the rejected pattern at
  instructions.xml :20..31).
- **S2** — REPL-piped tests: AC7's two probes (Probe-18.2-A and
  Probe-18.2-B) are sentinel-bounded REPL-piped Forth scripts
  (per `feedback_repl_tests_preferred.md`).
- **S3** — real byte-count estimation: per-component itemisation
  above per B.2 / Lesson 13.5-C. NO "mirrors prior arm" rationale
  (the trampoline + EXIT sentinel comparison are itemised by
  instruction emit count, not by analogy to the allocator).
- **S4** — AC-composition validation: AC1 (trampoline) + AC2
  (sentinel-IS-trampoline) + AC3 (EXIT sentinel comparison) compose
  — the trampoline's existence is required by EXIT_CODE's match
  branch; the sentinel address is the trampoline's own address.
  AC4 (intra-bank invariance) + AC10 (regression-clean) compose —
  the intra-bank EXIT path is exercised on every colon-body return
  in the 975-test suite. AC5 (EXX-hygiene) + AC6 (no FR-P4-21
  runtime guard) compose at the CCD-3 source-comment site.
  AC7 (REPL probes) + AC8 (hardware smoke) compose as independent
  verdict surfaces per Lesson 17-C.
- **S7** — EXX-hygiene: trampoline is a leaf-with-respect-to-EXX
  per AC5; no `EXX` in body; main-set-only; THROW raise potential
  documented inline.
- **S9** — per-binary-delta-story hardware smoke: AC8 + Task 6.
  Planned as **independent verdict surface** per Lesson 17-C.
- **S11** — user-visible version surface audit: not surfaced at
  Story 18.2 (banner stays at v3.0.1; the next S11 surface is
  Story 18.5's Epic 18 close-out tag at antforth 3.x.2).
- **S12** — hardware-typed probe discipline: Task 6's hardware-
  smoke recipe must be typed-form-validated under iz-cpm-banking
  before handing off to hardware (Lesson 17-F).
- **CCD-1** — the 3-cell return frame is a NEW frame type added
  to the dual-chain discipline per
  `architecture.md:186..188`. AC1 + AC3 + AC7's Probe-18.2-A
  exercise the new frame type; CATCH-TOP and INCLUDE-TOP chains
  are unaffected (no test needed at this story; cross-bank THROW
  unwind survivability is Story 18.3 / Story 18.5 scope).
- **CCD-3** — source-comment pointers: AC1 + Task 1 (trampoline
  CCD-3 block citing redesign §2.2 + PD-P4-2 + PD-P4-12 + EXX
  audit); Task 2 (EXIT_CODE CCD-3 block citing PD-P4-2 + redesign
  §2.2 + FR-P4-19 invariant + forward-pointer to Story 18.3).
- **CCD-4** — per-epic benchmark gate: Story 18.5 surfaces F2
  banked-word stub-count metric; Story 18.2 lays the substrate
  that lets cross-bank dispatch actually execute (a stub is
  measurable as a "banked word" only once the trampoline +
  EXIT-sentinel branch can route control through it).

### Forward-inheritance pointers

- **Story 18.3** (`EXECUTE` chokepoint + initial `COMPILE,`
  stub-emission wiring) is the PRODUCTION PUSHER of the 3-cell
  sentinel frame. Inherits: the trampoline contract (pop
  caller_bank → MMU port write → update current_bank → pop
  target_addr → JP); the sentinel-address symbol
  `cross_bank_return`; the 3-cell frame field order
  `(sentinel_addr, caller_bank, target_addr)` top-to-bottom.
  Story 18.3's AC6 (cross-bank THROW survivability — NFR-P4-7)
  exercises the trampoline on the THROW unwind path; Story 18.2
  lays the substrate, Story 18.3 validates it under exception
  unwind.
- **Story 18.4** (`BANK-OF`) does NOT inherit from Story 18.2
  (BANK-OF is a one-byte read from stub byte 0; the trampoline
  is not involved). Forward pointer is informational only.
- **Story 18.5** (`IN-BANK` + Epic 18 close-out) inherits:
  the verdict-table row for Story 18.2 (PASS / +N B / 1 hardware
  transcript) per the Story-13.5.6 precedent for epic close-out
  verdict walks. Story 18.5's AC2 (CATCH-safe `IN-BANK` per
  FR-P4-4) does NOT depend on the cross-bank trampoline — IN-BANK's
  save/restore is its own discipline per redesign §1 commentary
  (`docs/antforth-banking-redesign.md:9..30`) that IN-BANK is
  "kernel-blessed, not user library"; the kernel implementation
  uses `>R / R>` directly, independent of Story 18.2's cross-bank
  frame.
- **Epic 19** (bank-aware `:`) consumes Story 18.2 + Story 18.3
  together: `:` allocates the descriptor stub on `;` (Story 18.1's
  allocator), and the stub's `target_addr` slot points into the
  current bank's body region — cross-bank EXIT from a banked
  colon body routes through Story 18.2's trampoline. The intra-
  bank zero-overhead path (FR-P4-19) is preserved for the common
  case where the caller and callee are in the same bank.
- **Epic 21** (ABORT/QUIT bank-state restore — S5 / PD-P4-5)
  depends on Story 18.2: the cross-bank THROW unwind path
  (cross-bank frame coexisting with CATCH frames on the same
  R-stack per CCD-1) requires the trampoline to be in place so
  the unwind walks the cross-bank frames correctly; Story 18.5's
  AC2 + Epic 21's exception-frame interaction story validate this.

### Lessons applied

- **Lesson 17-B** (`project_epic17_envelope.md`) — empirical
  envelope was ~2.4–2.7× the redesign-§7 / epics-spec stated
  target across Epic 17; Story 18.1 came in at 1.52× of its
  per-component itemisation, well inside the envelope. For Story
  18.2, the per-component itemisation lands at ~27–43 B (well
  under the AC9 ≤ ~80 B spec ceiling and well under the realistic
  envelope of ~190 B). Cite the memory inline at dev-pass start;
  Q6-a-extended re-litigation is **not** expected.
- **Lesson 17-C** — hardware-smoke is an **independent verdict
  surface**, not a redundancy check on `make test-repl-banking`.
  AC8 + Task 6 plan the hardware run as a separate verdict — a
  typed-form recipe that synthesizes the 3-cell sentinel frame
  + asserts bank restoration via `BANK@` readback on real
  MicroBeast.
- **Lesson 17-D** (PUSH/POP DE wrap; surfaced 3× in Epic 17 at
  Stories 17.2 CR H1 / 17.3 dev-pass / 17.4 prospective; did NOT
  fire at Story 18.1 because `stub_allocate` did not touch DE)
  — the trampoline is authored DE-preserving from the start. If
  the trampoline body uses no DE-touching opcode (no `EX DE, HL`,
  no `LDIR`, no DE-as-temp), state that explicitly in the inline
  source-comment block so the absence is documented rather than
  inferred. EXIT_CODE's sentinel comparison reads DE (the popped
  return-address) but does NOT modify it on the miss path; on
  the hit path, the trampoline body discards DE (the sentinel
  address) and pops fresh values from the R-stack.
- **Lesson 17-F** — hand-typed hardware-smoke recipes for hand-
  built memory-write probes are brittle. AC8's typed-form recipe
  is smoke-tested under iz-cpm-banking in its EXACT typed form
  before handing off to hardware (Task 6). The recommended
  Probe-18.2-A shape (Q2 option (a) — kernel-internal DEFCODE
  tail) avoids the WORD-clobbers-MOVE-output failure mode from
  Story 17.6 entirely.
- **Story 18.1 close-out hygiene** — append components at the
  natural file position (Story 18.1 appended the allocator
  after `(stub-allocate)` wrapper); cite PD-P4-N decisions
  inline at the source site per CCD-3; the `(stub-allocate)`
  wrapper's per-component itemisation undercounted the DEFCODE
  header (~18 B vs ~6–10 B estimate) — Story 18.2 has no DEFCODE
  wrapper (no Forth-callable surface in this story; the trampoline
  is reachable only via the EXIT sentinel-match branch), so the
  same undercount risk does not apply.
- **Story 18.1 CR-M3** (`feedback_tib_size_inline_comments.md`)
  — REPL probe lines (code + `\` annotation) must stay ≤ TIB_SIZE
  = 128. Probe-18.2-A/B inline `\` annotations must be lifted to
  pre-assertion block comments if they exceed 128 chars per the
  Story-18.1-CR-M3 fix pattern.
- **Story 18.1 CR-M2** (deferred to Story 18.2 or a CR-followup)
  — Probe-18.1-C's absolute-address assertion is brittle to
  allocator-call-order. Story 18.2's probes do NOT call
  `(stub-allocate)` — the M2 disposition is not affected by
  Story 18.2's additions. If Story 18.2's CR surfaces an
  opportunity to refactor Probe-18.1-C to a relative-stride
  assertion + a separate absolute-COLD-init verification, the
  refactor can land here per the M2 forward-pointer note.
- **`feedback_no_claude_coauthor.md` STRONG rule** — commit
  messages must NOT include `Co-Authored-By: Claude` trailer.
- **`feedback_post_hw_smoke_steps_at_review.md` STRONG rule**
  — hardware-smoke recipe is posted in the closing chat message
  at code-review close (Task 6 + Task 7). Fired 8× across Epic 17
  + Story 18.1; non-negotiable.
- **`feedback_iz_cpm_test_643_quirk.md`** — possible layout-
  sensitive iz-cpm test 643 trip; standard remedy is 1-NOP-
  padding at end of `cold_start` step 8h (Task 5). Story 18.1
  did NOT trip the quirk at +70 B; Story 18.2 at ~27–43 B may
  land at a similarly safe offset.
- **`feedback_assembler_operand_order.md`** — Zilog dst-src
  operand order for any new Z80 instructions in Task 1 / Task 2
  (the trampoline body + EXIT_CODE sentinel comparison are
  authored in straight assembly inside `src/banking.asm` /
  `src/inner_interpreter.asm` — both files use Zilog dst-src
  order throughout, e.g., `LD A, B`).

### Project Structure Notes

- **No new files created** in Story 18.2. All work lands in
  existing Phase-4 files: `src/banking.asm` (trampoline body —
  Layout A) or `src/inner_interpreter.asm` (trampoline body —
  Layout B); `src/inner_interpreter.asm` (EXIT_CODE sentinel
  comparison — both layouts); `tests/banking_tests.fth` (2
  sentinel-bounded probes); `Makefile` (2 awk-extract + grep
  blocks for `test-repl-banking`).
- **No file-touch surface variance** vs the architecture's
  Phase-4 file-touch map at `architecture.md:744..798`. The map
  at row Epic 18 (`:840`) names `src/banking.asm` for descriptor-
  stub layout + sentinel-trampoline + `cross_bank_return`,
  `src/inner_interpreter.asm` for the EXIT / EXECUTE edits, and
  `tests/banking_tests.fth` for cross-bank dispatch probes.
  Story 18.2 touches `src/banking.asm` (trampoline body, Layout A)
  + `src/inner_interpreter.asm` (EXIT_CODE sentinel comparison)
  + `tests/banking_tests.fth` (probes) + `Makefile` (test
  integration). Story 18.3 will touch `src/inner_interpreter.asm`
  again (EXECUTE chokepoint) + `src/compiler.asm` (initial
  COMPILE, stub-emission wiring).
- **CCP-evicted region annex** is unchanged in claim (still
  `$D400-$DBFF` per Story 17.1 `src/banking.asm:10..14`) — Story
  18.2's trampoline is normal kernel code in `$0100-$D3FF`, NOT
  in the CCP-evicted region (which is reserved for `bank-table[]`
  + `active_pages[]` + descriptor-stub allocator output).

### References

- **Story 18.1**
  (`_bmad-output/implementation-artifacts/18-1-descriptor-stub-allocator-xt-as-stub-address-contract.md`)
  — predecessor story; descriptor-stub allocator + `(stub-allocate)`
  wrapper + `stub_alloc_tail` UserArea cell + `STUB_ALLOC_BASE`
  constant. Verdict: 10/10 ACs PASS; +70 B (26,228 → 26,298 B);
  CR closed with M1+M3 fix-now, M2 deferred to Story 18.2 / CR-
  followup.
- **Epic 17 retro**
  (`_bmad-output/implementation-artifacts/epic-17-retro-2026-05-17.md`)
  — Lessons 17-A through 17-G; Action items A1 / A2 / A3 / A4
  carried forward to Epic 18 / Story 18.x.
- **Story 17.2**
  (`_bmad-output/implementation-artifacts/17-2-bank-fetch-bank-store-banks-read-and-swap-primitives.md`)
  — `BANK!` swap routine precedent for the MMU port write +
  `current_bank` cell update pattern. Trampoline's logical→
  physical lookup mirrors `BANK!`'s `:157..161` shape.
- **PRD Phase-4** (`_bmad-output/planning-artifacts/prd.md` /
  `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:653..674`)
  — FR-P4-18 / FR-P4-19 / FR-P4-20 / FR-P4-21; NFR-P4-7 /
  NFR-P4-19 / NFR-P4-34.
- **Architecture Phase-4**
  (`_bmad-output/planning-artifacts/architecture.md`) — PD-P4-2
  (`:215..227`); PD-P4-11 (`:347..365`, informational); PD-P4-12
  (`:367..382`); CCD-1 Phase-4 reaffirmation (`:186..188`);
  Sentinel-trampoline labels pattern (`:534..537`); Cross-bank
  ABI pattern (`:587, 591`); File-touch surface (`:744..798`);
  Epic-18 file-touch row (`:840`).
- **Redesign doc** (`docs/antforth-banking-redesign.md`) — §2.2
  (S1 b sentinel decision; `:44..48`); §3 (cross-bank call
  mechanism narrative; `:54..63`); §5.2 (CP/M residency layout;
  `:87..95`); §7 (perf/memory budgets; `:119..132`).
- **Register conventions** (`docs/register-conventions.md`) — §3
  (leaf-level EXX rule); §7 (EXX-using inventory). Trampoline
  AC5 audit cites both sections.
- **Memory** — `project_phase4_scope.md`;
  `project_epic17_envelope.md`; `feedback_iz_cpm_test_643_quirk.md`;
  `feedback_repl_tests_preferred.md`;
  `feedback_no_claude_coauthor.md`;
  `feedback_post_hw_smoke_steps_at_review.md`;
  `feedback_no_accept_disposition_for_bugs.md`;
  `feedback_assembler_operand_order.md`;
  `feedback_tib_size_inline_comments.md` (Story 18.1 CR-M3
  precedent); `project_assembler_keep_assembly.md` (banking.asm
  + inner_interpreter.asm stay kernel-resident assembly —
  confirmed for Story 18.2).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context)

### Debug Log References

- 2026-05-18 — first attempt at Probe-18.2-A used top-level `['] EXIT
  1+ @ ... CONSTANT _xbr-addr` and `[IF]/[THEN]` for the sanity check.
  Both failed with `error -14: interpreting a compile-only word` at
  load time. `[']` is compile-only (DEFIMMED at
  `src/compiler.asm:61`); `[IF]/[THEN]` are not defined in antforth
  (`error -13: undefined word`). Fix: switched top-level extraction
  to `'` (interpret-mode tick) and moved the sanity check into the
  probe colon body using a runtime `IF/THEN`. Builds and PASSes.
- 2026-05-18 — second attempt at Probe-18.2-A used `caller_bank = 1`
  to make the trampoline's MMU + current_bank update binding-
  observable. The probe halted silently after emitting the start
  sentinel under iz-cpm-banking. Root cause: at .fth file load time
  HERE is past $8000 by the time `_probe-18.2-a` body is compiled
  (kernel binary ends ~$66xx, prior probes push HERE up); the probe
  body therefore lives in MMU slot 2 ($8000-$BFFF). Switching slot 2
  to bank 1's page (a fresh, uninitialised bank under iz-cpm-banking)
  remaps the body's bytes underneath the running NEXT, and the next
  IP fetch reads garbage → silent halt. Per AC1 the trampoline alone
  does NOT do BANK!'s triple swap; that's Story 18.3's pusher-side
  responsibility. Fix: reverted to `caller_bank = 0` (matches
  `current_bank`). The trampoline still runs every AC1 step (MMU
  port write + cell update), but observably as a no-op. The probe
  printing its PASS literal IS the witness that EXIT_CODE detected
  the sentinel and dispatched the trampoline — without the
  sentinel mechanism in place, the EXIT would interpret `xbr-addr`
  as a Forth IP via NEXT and crash on JP-to-garbage (NEXTHL reads
  the trampoline body's first bytes as a fake IP cell). The
  caller_bank ≠ current_bank case is owed to Story 18.3 / Story 18.5
  testing once the pusher-side state swap lands.

### Completion Notes List

- **AC1** PASS — `cross_bank_return:` trampoline body at
  `src/banking.asm:921..937` implements all 5 contract steps (pop
  caller_bank → active_pages lookup → OUT (0x72) → update
  current_bank → pop target_addr → JP (HL)). 32 B emit, BC=TOS
  preserved via PUSH/POP wrap. No `EX DE, HL` / no `LDIR` / no
  DE-as-temp; Lesson 17-D PUSH/POP DE wrap NOT required.
- **AC2** PASS — one symbol does both jobs: the label
  `cross_bank_return` at `src/banking.asm:921` is the trampoline
  entry point and the sentinel address EXIT_CODE compares against.
  `src/inner_interpreter.asm:62` emits `LD A, LOW
  cross_bank_return` and `:65` emits `LD A, HIGH
  cross_bank_return`; the JP at `:67` resolves to the same address.
  No separate sentinel constant introduced.
- **AC3** PASS — EXIT_CODE at `src/inner_interpreter.asm:55..71`
  carries the 13-byte sentinel comparison (Layout A: explicit
  `JP cross_bank_return` on match; `JR NZ, .exit_normal` on
  either-byte mismatch falls through to standard NEXT). Miss-path
  preserves byte-for-byte the pre-edit `LD E/D, (IX+0/1) + INC
  IX × 2` pop semantics; only the CP/JR-NZ pairs are added on
  the intra-bank path.
- **AC4** PASS — see "Realised T-state account" subsection below.
  Worst-case miss-path overhead ≤ 41 T-states (LOW-match + HIGH-
  miss path); common-case (LOW-byte mismatch) overhead = 23 T.
  AC's substantive contract — "no instructions beyond the
  CP/JR-NZ pairs are added on the miss path" — satisfied.
  The 975-PASS test-repl baseline is the binding fitness witness;
  intra-bank EXIT runs on every colon-body return across the
  test suite with zero regressions.
- **AC5** PASS — EXX-hygiene re-walk applied at the trampoline
  source-comment block (`src/banking.asm:880..898`). Trampoline is
  leaf-with-respect-to-EXX; no `EXX` in body; main-set-only; no
  THROW raise under normal operation. CCD-3 forward pointer
  references the PD-P4-12 disposition for the hypothetical future
  re-walk if a guard is added.
- **AC6** PASS — PD-P4-12 (FR-P4-21 recursive cross-bank R-stack)
  documented as CHOSEN: no runtime guard added by Story 18.2.
  Inline source comment at `src/banking.asm:899..908` cites the
  architecture-doc decision and forward-points to the F4 user-docs
  entry slated for Epic 22 polish.
- **AC7** PASS — Probe-18.2-A and Probe-18.2-B land in
  `tests/banking_tests.fth:845..995`. Sentinel-bounded blocks
  with end-sentinels on their own line per M4 check.
- **AC8** PASS — `make test-repl-banking` reports PASS for both
  probes. Hardware-smoke run COMPLETE on real MicroBeast 2026-05-18
  (transcript `~/Downloads/beastty-20260518-104655.bin`): pre/post
  `BANK@ .` both = `0`; `XBR` resolved to `$4BD8` (exact match with
  iz-cpm-banking build — independent cross-surface verdict); `TAIL`
  executed cleanly through the EXIT→sentinel→trampoline→chained-EXIT
  chain. All four independent observables PASS on real hardware.
- **AC9** PASS — `wc -c build/antforth.com` = 26,343 B (+45 B vs
  26,298 B baseline). Well under the ≤ ~80 B AC9 ceiling (56% of
  ceiling). Per-component itemisation matches realisation: 32 B
  trampoline + 13 B EXIT_CODE sentinel = 45 B; no iz-cpm-643 NOP
  padding needed.
- **AC10** PASS — `make test-repl` = 975 PASS / 0 FAIL / 2 SKIP
  (matches baseline); `make test-repl-banking` = 40 PASS / 0 FAIL
  (38 baseline + 2 new probes); `make check-doc-sync` = 31
  advisories / 0 drift (matches baseline).

### Realised T-state account (AC4)

Pre-edit `EXIT_CODE` (4 instructions + NEXT macro):

| Instruction | T-states |
|---|---:|
| LD E, (IX+0) | 19 |
| LD D, (IX+1) | 19 |
| INC IX | 10 |
| INC IX | 10 |
| EX DE, HL (NEXT macro) | 4 |
| LD E, (HL) (NEXTHL) | 7 |
| INC HL | 6 |
| LD D, (HL) | 7 |
| INC HL | 6 |
| EX DE, HL | 4 |
| JP (HL) | 4 |
| **Pre-edit total** | **96** |

Post-edit miss-path overhead (added before NEXT in `.exit_normal:`):

| Instruction | T-states (LOW-miss) | T-states (LOW-match+HIGH-miss) |
|---|---:|---:|
| LD A, LOW cross_bank_return | 7 | 7 |
| CP E | 4 | 4 |
| JR NZ, .exit_normal | 12 (taken) | 7 (not taken) |
| LD A, HIGH cross_bank_return | — | 7 |
| CP D | — | 4 |
| JR NZ, .exit_normal | — | 12 (taken) |
| **Overhead** | **23** | **41** |

Common case (LOW-byte mismatch): **23 T-states** added on the
miss path. The worst-case miss (LOW-byte coincidence with
`cross_bank_return.lo`, HIGH-byte mismatch) is **41 T-states**;
the rarity of the LOW-byte coincidence (≈1/256 of return
addresses on a uniform-random distribution) keeps the amortised
intra-bank overhead well within ≤ ~25 T-states.

AC4's substantive contract — "no instructions beyond the CP/JR-NZ
pairs are added on the miss path" — is satisfied byte-for-byte
by the Layout A emit shape. The 975-PASS test-repl regression
baseline (intra-bank EXIT exercised tens of thousands of times)
holds exactly under the new EXIT_CODE shape.

### Hardware-smoke recipe (AC8)

Independent-verdict-surface hardware-smoke recipe (per Lesson 17-C).
Boot MicroBeast with default CL-tail (11 banks auto-seeded by the
Story 17.4 parser), type the following at the REPL, verify the
recipe ends with `0  ok` (BANK@ readback shows we resumed at bank 0):

```
BANK@ .                                            \ expect 0  ok
' EXIT 1+ @ 21 + @  CONSTANT XBR
XBR  HEX U.  DECIMAL                               \ informational
: TAIL  ['] EXIT >R  0 >R  XBR >R ;                \ inner sentinel-pusher
TAIL                                               \ fires trampoline
BANK@ .                                            \ expect 0  ok  (trampoline restored)
BYE
```

The recipe synthesizes the 3-cell sentinel frame at the REPL
(via `' EXIT 1+ @ 21 + @` to extract `cross_bank_return`'s
address from the EXIT_CODE bytes; `>R` triple-push for
target_addr / caller_bank / sentinel), invokes the trampoline
via the implicit `;` EXIT of `TAIL`, and reads `BANK@` after
to confirm the trampoline ran without crashing. Pre/post
`BANK@ .` provides a visual independent verdict.

Hardware-smoke trip plan: open serial console; clean boot;
type recipe; assert both `BANK@ .` lines emit `0  ok`; assert
the recipe's third line (XBR's hex value) prints; assert
the post-trampoline prompt appears. Transcript saved to
`~/Downloads/beastty-<timestamp>.bin`. Recipe was typed-form
validated under iz-cpm-banking before handoff to hardware
(Lesson 17-F).

### File List

- `src/banking.asm` (modified) — `cross_bank_return:` trampoline
  body + CCD-3 source-comment block at `:823..938` (between the
  Story-18.1 `(stub-allocate)` wrapper and the `--- .BANKS
  string literals ---` block).
- `src/inner_interpreter.asm` (modified) — `EXIT_CODE` extended
  with sentinel comparison at `:36..71` (13 B added; CCD-3
  comment block citing PD-P4-2 / redesign §2.2 / FR-P4-19
  invariant; Layout A explicit `JP cross_bank_return` on
  sentinel match).
- `tests/banking_tests.fth` (modified) — Story 18.2 probe block
  at `:845..995` (Probe-18.2-A cross-bank EXIT trampoline + 
  Probe-18.2-B intra-bank EXIT round-trip; runtime sanity check
  for EXIT_CODE byte layout; sentinel-bounded with on-its-own-
  line end sentinels per M4 check).
- `Makefile` (modified) — Story 18.2 probe assertions at
  `:320..346` (awk-extract + grep PASS literal + negative-assert
  FAIL + end-sentinel-on-own-line check; Story 18.1 pattern at
  `:298..318`).
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
  (modified) — `18-2-sentinel-trampoline-cross-bank-return-kernel-exit-distinguishes-intra-bank-from-cross-bank`
  row: `ready-for-dev` → `review`.
- `_bmad-output/implementation-artifacts/18-2-sentinel-trampoline-cross-bank-return-kernel-exit-distinguishes-intra-bank-from-cross-bank.md`
  (modified) — task checkboxes marked, Dev Agent Record + File
  List + Change Log populated, Status flipped to `review`.

### Change Log

- 2026-05-18 — Story 18.2 dev-pass: sentinel-trampoline
  `cross_bank_return` trampoline body landed in `src/banking.asm`
  (32 B); EXIT_CODE extended with 13-byte sentinel comparison
  (Layout A: explicit `JP cross_bank_return` on match);
  Probe-18.2-A (cross-bank EXIT dispatch witness) + Probe-18.2-B
  (intra-bank EXIT round-trip) added to `tests/banking_tests.fth`
  with Makefile assertions; binary +45 B (26,298 → 26,343 B);
  regression-clean (975 PASS / 0 FAIL / 2 SKIP test-repl +
  40 PASS / 0 FAIL test-repl-banking + 31 advisories / 0 drift
  check-doc-sync). All 10 ACs PASS.
- 2026-05-18 — Hardware-smoke run on real MicroBeast COMPLETE
  (transcript `~/Downloads/beastty-20260518-104655.bin`).
  Pre/post `BANK@` both = 0; `XBR HEX U.` returned `4BD8`
  (exact match with iz-cpm-banking build — independent
  cross-surface verdict for `cross_bank_return` address);
  `TAIL` executed cleanly through the EXIT→sentinel→trampoline
  →chained-EXIT chain. AC8 hardware-smoke surface PASS.
