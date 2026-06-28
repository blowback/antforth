---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
phase: 5
phaseScope: 'Phase 5 — standards & I/O polish (Epic 23)'
lastEdited: '2026-06-28'
inputDocuments:
  - docs/WISHLIST.md
  - docs/dev_journal.md
  - docs/ans-forth-core-compliance.md
  - _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md
  - _bmad-output/implementation-artifacts/epic-22-retro-2026-06-14.md
---

# antforth — Epic Breakdown (Phase 5 — standards & I/O polish, Epic 23)

## Overview

Phase 5 is a **standards & I/O polish** phase: four small, additive features that
close long-standing ANS gaps and one assembler conformance bug. There is **no new
execution model** — the cooperative multitasker, semaphores, and full ANS `{: :}`
locals were considered for Phase 5 and **deliberately deferred** (see Deferred
section) because each is a platform shift, not an increment.

Phase 5 ships as **antforth v3.1.0**, a single epic (Epic 23) on top of the
Phase-4 close-out baseline (antforth v3.0.7 — banked build, 975 PASS / 0 FAIL on
real CP/M 2.2 / MicroBeast, HEAD 28,499 B). This document is deliberately
right-sized per the standing solo-dev lesson (`feedback_ceremony_diminishing_returns`):
conventions are kept (frontmatter, FR inventory, per-story ACs, standalone /
byte-budget / S9 lines) without re-enumerating the full Phase-4 NFR catalogue —
the Phase-4 process commitments (S1–S12, regression baseline, hardware-smoke
cadence) carry forward by reference (see Carried-Forward Constraints).

## Requirements Inventory

### Functional Requirements

#### Standards gaps (FR-P5-1..8)

- **FR-P5-1 (`VALUE`):** `VALUE ( x "name" -- )` — defining word. Creates a word
  `name` that, when executed, pushes its stored cell `x`. ANS Forth 1994
  §6.1.2380 (Core). Read-by-name, no `@`.
- **FR-P5-2 (`TO`):** `TO ( x "name" -- )` (interpret) / `TO ( x -- )` compiling a
  store to the next parsed `VALUE` (compile). STATE-aware: stores into the target
  `VALUE` at interpret time, compiles a store at compile time. ANS Forth 1994
  §6.1.2295 (Core). Targets a `VALUE`; applied to a non-`VALUE` raises a defined
  THROW (see AC).
- **FR-P5-3 (`UD.`):** `UD. ( ud -- )` — display an unsigned double-cell integer
  in the current `BASE`, followed by one space, no leading sign. ANS Forth 1994
  §8.6.1.1230 (Double-Number word set). Built on the existing pictured-numeric
  foundation (`<# # #S #>`, `UM/MOD`).
- **FR-P5-4 (`ENVIRONMENT?` "EXCEPTION"):** `ENVIRONMENT?` returns `true true` for
  query string `EXCEPTION` (the Exception word set is present — `CATCH`/`THROW`,
  Epic 11). DPANS94 §9.6 environment query.
- **FR-P5-5 (`ENVIRONMENT?` "EXCEPTION-EXT"):** returns `true true` for
  `EXCEPTION-EXT` (`ABORT`/`ABORT"` present). DPANS94 §9.6.
- **FR-P5-6 (`ENVIRONMENT?` "DOUBLE" / "DOUBLE-EXT"):** returns `true true` for
  `DOUBLE` and `DOUBLE-EXT` (Double-Number word set, Epic 10). DPANS94 §8.6.
- **FR-P5-7 (`ENVIRONMENT?` "SEARCH-ORDER" / "SEARCH-ORDER-EXT"):** returns
  `true true` for `SEARCH-ORDER` and `SEARCH-ORDER-EXT` (Search-Order word set,
  Epic 12). DPANS94 §16.6.
- **FR-P5-8 (env-query regression):** all pre-existing `ENVIRONMENT?` keys
  continue to answer identically; the new rows are additive to `env_table`
  (`src/system.asm`).

#### Z80 I/O primitives — antforth extensions (FR-P5-9..10)

- **FR-P5-9 (`IN`):** `IN ( port -- byte )` — read one byte from Z80 I/O port.
  Runtime code word emitting `IN A,(C)` with `BC = port` (so the full 16-bit
  port address is available: high byte in `B`, low in `C`). **antforth extension**
  (not ANS); flagged per CCD-3 with a hardware-I/O design note.
- **FR-P5-10 (`OUT`):** `OUT ( x port -- )` — write the low byte of `x` to a Z80
  I/O port. Runtime code word emitting `OUT (C),A` with `BC = port`. Stack order
  `( x port -- )` mirrors `!` (datum below address). **antforth extension**;
  flagged per CCD-3.

#### Assembler conformance fix (FR-P5-11)

- **FR-P5-11 (`IN,` / `OUT,` operand order = Zilog dst-src):** The inline
  assembler's `IN,` and `OUT,` are corrected to the project's documented Zilog
  dst-src operand order (`feedback_assembler_operand_order`: `B C LD,` = `LD B,C`,
  i.e. dst = NOS, src = TOS). Today both are reversed:
  - `IN,` currently expects `( port reg -- )` → user types `(C) A IN,` (src-dst).
    After fix: `( reg port -- )` → `A (C) IN,` assembles `IN A,(C)`; `A 0x74 IN,`
    assembles `IN A,(n)`.
  - `OUT,` currently expects `( reg port -- )` → user types `A (C) OUT,` (src-dst).
    After fix: `( port reg -- )` → `(C) A OUT,` assembles `OUT (C),A`;
    `0x74 A OUT,` assembles `OUT (n),A`.
  This is a **source-breaking** change for any existing CODE word using `IN,`/`OUT,`;
  the story owns a sweep of `tests/`, `disk/`, and `examples/` to migrate call
  sites (per `feedback_no_preexisting_discharge` — the wrong convention is a bug,
  surfaced and fixed, not accepted).

### Carried-Forward Constraints (from Phase 4, by reference — no re-decision)

- **Regression baseline (release blocker):** the Phase-4 close-out suite
  (975 PASS / 0 FAIL / isolated + straddle green on the banked build) passes on
  every Phase-5 candidate. A single regression blocks the v3.1.0 tag.
- **ANS §-level compliance auditability:** every new Core / Core-Ext / Double /
  Exception / Search-Order word adds its own `§`-level row to
  `docs/ans-forth-core-compliance.md`, verifiable in < 10 min.
- **Extension discipline (CCD-3):** non-ANS words (`IN`, `OUT`) flagged in source
  `; antforth extension <word> — <design reason>`.
- **S1–S12 standing commitments:** adversarial fresh-context `/CR` review (S1);
  REPL-piped Forth tests as default (S2); real-byte-count per-part byte budgets
  (S3); AC-composition validation (S4); PARTIAL→HALT (S5); helper-layer inventory
  grep (S6); EXX-hygiene per raise site (S7); "pre-existing" cannot discharge a
  correctness defect (S8); **mid-epic hardware-smoke per binary-delta story**
  (S9 / NFR-P4-11); workflow > memory > prompt (S10); user-visible version-surface
  audit at tag (S11); hardware-typed probe authoring — word-existence pre-flight +
  TIB-128 line lint (S12).
- **Post-HW-smoke recipe at review (STRONG):** every binary-delta story posts its
  deferred hardware-smoke recipe **in the closing chat message**, not only in Dev
  Notes (`feedback_post_hw_smoke_steps_at_review`).
- **CP/M EOF discipline:** any `.FTH` placed in `disk/a/` for SLIDE-transfer is
  0x1A-terminated (`feedback_cpm_0x1a_eof_marker`).

### FR Coverage Map

| FR | Story | Notes |
|---|---|---|
| FR-P5-1 (`VALUE`) | 23.2 | Defining word, self-fetching cell |
| FR-P5-2 (`TO`) | 23.2 | STATE-aware store to a `VALUE` |
| FR-P5-3 (`UD.`) | 23.4 | Double-number unsigned print |
| FR-P5-4..7 (`ENVIRONMENT?` rows) | 23.4 | 6 flag rows added to `env_table` |
| FR-P5-8 (env regression) | 23.4 | Existing keys unchanged |
| FR-P5-9 (`IN`) | 23.3 | `IN A,(C)`, 16-bit port in BC |
| FR-P5-10 (`OUT`) | 23.3 | `OUT (C),A`, stack `( x port -- )` |
| FR-P5-11 (`IN,`/`OUT,` order) | 23.1 | Zilog dst-src fix + call-site sweep |

## Epic 23: Standards & I/O polish — antforth v3.1.0

**Goal:** Close four standing ANS / ergonomics gaps and one assembler conformance
bug, shipping a clean v3.1.0 point-release with zero regressions. Each story is
small, independently testable, and binary-delta-bounded. No new execution model;
no banking-subsystem changes.

**Standalone:** ✅ Each story below ships observable value on its own at the REPL
or assembler. The epic close-out (23.5) ties them into a tagged release.

**Depends on:** Phase-4 close-out baseline (v3.0.7) only. No intra-phase
sequencing constraints between 23.1–23.4 — they may land in any order; 23.5 gates
on all four.

**Aggregate byte budget (fixed memory, rough — refine per-story at spec time):**
≈ 300 B (23.1 ≈ 0 ±15 B · 23.2 ≈ 120 B · 23.3 ≈ 50 B · 23.4 ≈ 130 B). Well inside
a polish-phase envelope; logged per CCD-4 at close-out.

---

### Story 23.1 — Assembler `IN,` / `OUT,` operand-order fix (Zilog dst-src)

**As** an antforth assembler user,
**I want** `IN,` and `OUT,` to follow the same dst-src operand order as every
other mnemonic,
**so that** `A (C) IN,` and `(C) A OUT,` read like `IN A,(C)` / `OUT (C),A` and I
don't hit "bad operand" typing the natural order.

**Acceptance Criteria:**
1. `A (C) IN,` assembles `IN A,(C)` (`ED 78`); `A 0x74 IN,` assembles `IN A,(n)`
   (`DB 74`). Old src-dst order (`(C) A IN,`) no longer assembles `IN`.
2. `(C) A OUT,` assembles `OUT (C),A` (`ED 79`); `0x74 A OUT,` assembles
   `OUT (n),A` (`D3 74`).
3. Operand-class / index validation and `asm_bad_operand` paths preserved
   (immediate port still A-only; `(C)` still the only valid indirect).
4. All call sites in `tests/`, `disk/`, `examples/` migrated to the new order;
   grep confirms no surviving old-order `IN,`/`OUT,` usage. (S6 helper-layer grep.)
5. New REPL-piped assembler probe asserts the emitted bytes for all four forms
   (`IN A,(C)`, `IN A,(n)`, `OUT (C),A`, `OUT (n),A`) plus a `bad operand` round.
6. `docs/dev_journal.md:10-13` note resolved/removed; `docs/z80-instruction-coverage*.md`
   updated if it documents operand order.

**Notes:** source-breaking by design (the old order was the bug). No ANS bearing —
assembler is an antforth extension. Touches `src/assembler.asm` `w_IN_COMMA_cf` /
`w_OUT_COMMA_cf` (swap pop order). Byte-neutral expected.

**S9:** binary-delta → hardware-smoke required; post recipe at review.

---

### Story 23.2 — `VALUE` / `TO` (ANS Core named values)

**As** a Forth programmer,
**I want** `VALUE` and `TO`,
**so that** I can declare a named mutable cell read by name (`X`) and rewritten
with `TO` (`99 TO X`) without the `@`/`!` box dance.

**Acceptance Criteria:**
1. `42 VALUE X` defines `X`; `X` pushes `42`. (§6.1.2380.)
2. `99 TO X` updates `X`; `X` now pushes `99`. (§6.1.2295.)
3. `TO` is STATE-aware: inside a `: BUMP X 1 + TO X ;`, `BUMP` compiles a store and
   increments `X` at run time.
4. `TO` applied where the next token is not a `VALUE` raises a defined THROW
   (recommend `-32 invalid name argument (TO)`; final code pinned at spec time
   against `docs/throw-codes.md`) — not silent corruption.
5. `VALUE`/`TO` interoperate with the banked compiler: `5 BANK! 7 VALUE Y` defines
   `Y` in bank 5; `Y` and `8 TO Y` work from any bank (xt-stable; via the
   descriptor-stub path, same as any banked word). (Smoke on banked build.)
6. REPL-piped test covers interpret-time get/set, compile-time `TO`, the
   not-a-VALUE THROW, and a banked round.
7. `docs/ans-forth-core-compliance.md` gains `§6.1.2380 VALUE` and `§6.1.2295 TO`
   rows marked Implemented.

**Notes:** `VALUE` is a defining word (body = one cell; runtime pushes it). `TO`
parses the next name, finds it, and either stores now (interpret) or compiles a
store (compile). Touches `src/compiler.asm` and/or a small new defining-word body;
verify FIND of the `TO` target resolves the stub xt, not a raw CFA, on the banked
build (`project_story20_1_fat_pointers`). Est. ≈ 120 B.

**S9:** binary-delta → hardware-smoke required (incl. one banked-`VALUE` probe).

---

### Story 23.3 — Z80 runtime `IN` / `OUT` port words

**As** a MicroBeast hacker,
**I want** built-in `IN` and `OUT`,
**so that** I can poke hardware ports from the REPL without dropping into a CODE
word every time.

**Acceptance Criteria:**
1. `IN ( port -- byte )` reads one byte via `IN A,(C)` with `BC = port`; high byte
   of a 16-bit port honoured (B = high). Result zero-extended to a cell.
2. `OUT ( x port -- )` writes the low byte of `x` via `OUT (C),A` with `BC = port`.
   Stack order matches `!` (datum below address).
3. Both flagged `; antforth extension` per CCD-3 with a one-line hardware-I/O
   design note.
4. REPL-piped probe round-trips against a safe, side-effect-free readback port
   (probe targets a port confirmed inert on iz-cpm / MicroBeast; documents which).
5. Stack-depth underflow guarded (`IN` needs 1, `OUT` needs 2) per existing
   `check_underflow_*` discipline.
6. Does **not** collide with the assembler's `IN,`/`OUT,` (distinct names).

**Notes:** two small code words; likely `src/io.asm` or a new `src/hardware.asm`
chokepoint. Decide home file at spec. Confirm no ISR/banking interaction
(NFR-P4-26 — these run from fixed or banked user code, MMU-agnostic). Est. ≈ 50 B.

**S9:** binary-delta → hardware-smoke required; pick a genuinely inert probe port.

---

### Story 23.4 — `UD.` + `ENVIRONMENT?` query gaps

**As** a Forth programmer,
**I want** `UD.` and the missing `ENVIRONMENT?` rows,
**so that** unsigned doubles print correctly and wordset-detection queries answer
truthfully.

**Acceptance Criteria:**
1. `UD. ( ud -- )` prints an unsigned double in the current `BASE`, one trailing
   space, no sign. `0. UD.` → `0 `; large values (> single-cell max) print without
   sign-flip. (§8.6.1.1230.) Built on `<# #S #>` / `UM/MOD`.
2. `S" EXCEPTION" ENVIRONMENT?` → `( true true )`; likewise `EXCEPTION-EXT`,
   `DOUBLE`, `DOUBLE-EXT`, `SEARCH-ORDER`, `SEARCH-ORDER-EXT` — all `true true`.
3. All pre-existing `ENVIRONMENT?` keys return byte-identical results (FR-P5-8);
   miss path (`S" NOPE" ENVIRONMENT?` → `false`) unchanged.
4. New rows are flag-kind (`kind=2`) additions to `env_table` in `src/system.asm`;
   table walk / advance arithmetic unaffected.
5. REPL-piped tests: `UD.` across `BASE` 10/16, a value above `0x7FFF` and above
   `0xFFFF`; each new env key; one regression assert on an existing key + the miss.
6. `docs/ans-forth-core-compliance.md` gains the `UD.` row and the six env-query
   rows; `docs/dev_journal.md:5-8` gaps resolved/removed.

**Notes:** `UD.` is small (pictured-output sequence); the env rows are pure
table data. Est. ≈ 130 B (≈ 40 B `UD.` + ≈ 90 B six rows).

**S9:** binary-delta → hardware-smoke required.

---

### Story 23.5 — Epic 23 close-out: CCD-4 regression gate + v3.1.0 tag

**As** the project lead,
**I want** the Phase-5 close-out gate,
**so that** v3.1.0 ships with the full baseline green and the version surface
aligned.

**Acceptance Criteria:**
1. Full regression sweep green: Phase-4 baseline (975 PASS / 0 FAIL) **plus** the
   new Phase-5 probes (23.1–23.4), on iz-cpm + banking-capable emulator + real
   MicroBeast. Zero regressions (release blocker).
2. CCD-4 benchmark/byte-budget row logged: HEAD byte delta vs v3.0.7 (28,499 B)
   recorded and justified against the ≈ 300 B aggregate estimate.
3. S11 user-visible version-surface audit: banner string (`src/antforth.asm`),
   `README.md` version reference, and memory `description` fields all read v3.1.0.
4. `make check-doc-sync` clean-pass; `docs/ans-forth-core-compliance.md`,
   `docs/dev_journal.md`, `docs/WISHLIST.md` reflect Phase-5 deliverables and
   deferrals; verdict-table walk per Story-13.5.6 precedent.
5. New project memory: a Phase-5 successor to `project_phase4_scope.md` recording
   v3.1.0 close, deltas, and the deferral decisions.
6. `git tag v3.1.0` **gated on explicit project-lead authorization** (tags are
   never auto-applied — `project_phase4_scope.md` precedent).

**Notes:** zero-feature story; mostly verification + surface alignment. Post the
aggregated hardware-smoke verdict in the closing chat message (S9 / STRONG recipe
rule).

---

## Post-close-out follow-up stories (appended after the original 23.1–23.5 plan)

> These stories were added to Epic 23 **after** the v3.1.0 close-out (Story 23.5).
> 23.6 came from the 23.2/23.3 code review; 23.7 and 23.8 came from the Epic-23
> retrospective (2026-06-28, action items AI-23-2 and AI-23-1); 23.9 came from a
> /code-review of the 23.5–23.8 branch (2026-06-28). They are correctness and
> test-infra hardening — **no new feature FRs** — and do **not** gate the
> already-applied/authorised v3.1.0 tag. 23.7/23.9 carry small binary deltas (next
> release / v3.1.1); 23.8 is 0 B test-infra. Full specs live in the per-story files
> under `_bmad-output/implementation-artifacts/`.

### Story 23.6 — Banked dictionary window-top overflow guard *(done — shipped in v3.1.0)*

**Summary:** banked defining words and raw `,`/`C,`/`ALLOT`/`COMPILE,` growth that
would place any byte at or past the slot-2 window top (`$C000`) now raise a clean
`-8` dictionary-overflow THROW (shared `check_banked_headroom` guard +
`GUARD_BANKED_WRITE` macro), instead of silently corrupting a banked word through
slot 3. From code-review finding #5 of 23.2/23.3. **+115 B.** Done; full AC set and
boundary semantics in `23-6-banked-dictionary-window-top-overflow-guard.md`.

### Story 23.7 — Banked MARKER window-top overflow guard *(done — correctness)*

**As** a MicroBeast Forth programmer using `MARKER` inside a banked dictionary,
**I want** a banked `MARKER <name>` whose 192-byte saved-bucket body would cross
`$C000` to raise a clean `-8` **before anything commits**,
**so that** I never get a silently-corrupt MARKER whose body reads back through
slot 3 — the one banked-growth path 23.6 left unguarded.

**Why:** 23.6 surfaced this residual and scoped it out — MARKER calls `build_header`
(commits header/LATEST/bucket) then LDIRs the 192-byte body with no headroom check;
a MARKER within ~195 B of `$C000` on a bank straddles silently. **Design:** the
guard must be all-or-nothing, so it cannot sit at the LDIR (half-built-header trap);
instead parameterise 23.6's `build_header` guard with a caller-supplied
code-field/body reserve (default `DOER_RESERVE=5`) that MARKER raises to its full
footprint pre-commit. Reuses the `-8` / `check_banked_headroom` infra — no new throw
code. **Est. ≈ 28–36 B.** Real (narrow) correctness gap in shipped v3.1.0; S9
hardware-smoke required.

### Story 23.8 — In-suite bank-switching probe isolation *(ready-for-dev — test-infra, closes AI-22-5)*

**As** a maintainer of the banking test suite,
**I want** the main in-suite `test-repl-banking` run to carry no foreign-`BANK!`
probe, plus a lint that fails the build if one is re-introduced,
**so that** future kernel growth can never again push a bank-switching probe across
the `$8000` portal boundary and trip the unguardable straddle halt.

**Why:** the portal-aliasing halt was patched reactively three times (22.2 / 23.2 /
23.6); Epic-22's AI-22-5 committed to migrating in-suite non-zero-bank probes to
isolated fixtures and it was never done. The retro chose hardening over blessing the
reactive pattern. **Honest current state (verified 2026-06-28):** 0 in-suite probes
are presently at risk (the `.BANKS` probes were de-coloned to interpret level during
23.6) — so this is *prevention*: move the `.BANKS` bank-switching probes into an
isolated fixture so the main suite is structurally immune, and add a minimal
grep-based `make lint-banking-probes` (with a negative test) so the discipline
can't silently rot back. **0 kernel bytes.**

### Story 23.9 — Complete banked window-top guard coverage *(review — correctness)*

**As** a MicroBeast Forth programmer compiling into a banked dictionary,
**I want** *every* word that grows the dictionary at `HERE` in a bank — not just the
`,`/`C,`/`ALLOT`/`COMPILE,`/defining-word/`MARKER` paths 23.6/23.7 cover — to raise a
clean `-8` before it would cross `$C000`,
**so that** `;`, `LITERAL`, `DOES>`, `S"`, `."` and `ABORT"` in a near-full bank can
never silently write through slot 3 and corrupt it.

**Why:** a /code-review of the 23.5–23.8 branch found the 23.6/23.7 guard *mechanism*
correct but the *coverage* incomplete — five more paths write to `HERE` through their
own hand-rolled stores with no headroom check. `;` is the sharpest (every banked
colon ends with it, and the 23.6-guarded body compilers legally let `HERE` reach
exactly `$C000`); `S"`/`."`/`ABORT"` are the most damaging (overrun scales with the
string length). **Design:** reuse the 23.6 infra — fixed-width writes (`;`=2,
`LITERAL`=4, `DOES>`=2) take one `GUARD_BANKED_WRITE`; the inline-string copiers take
a framing `GUARD_BANKED_WRITE 3` plus a **per-character** `check_banked_headroom`
(an up-front TIB bound would over-reject a short string with a long line tail). All
sites run primary-set → direct `dict_overflow_throw`, no EXX; no new throw code.
**+88 B (29,091→29,179).** Probe `tests/banking_tests_23_9.fth` +
`make test-repl-banking-23-9` (8 cases A–H; non-vacuity proven — A–F fail vs an
unguarded kernel). Opportunistic same-review hardening: 23.6 ALIVE gate →
echo-proof computed `===42`; `lint-banking-probes` regex tightened to catch
hex/variable/computed/post-string `BANK!`. Real (narrow) correctness gap in shipped
v3.1.0; S9 hardware-smoke required (pending). Full AC set in
`23-9-complete-banked-window-top-guard-coverage.md`.

---

## Deferred (considered for Phase 5, deliberately out of scope)

- **Cooperative multitasker** (`TASK` / `ACTIVATE` / `PAUSE`, `KEY`-yields,
  timer-ISR-driven `PAUSE`) — a new execution model, not an increment; touches the
  banking subsystem (per-task stacks + per-bank triples). Own epic + ADR when
  taken up. (`docs/WISHLIST.md` "Multitasker".)
- **Semaphores** (`SIGNAL` / `WAIT`, mutex mailbox) — gated behind the
  multitasker; ≈ 50 B *on top of* a working scheduler, no standalone value.
- **Full ANS `{: a b -- c :}` locals** — compiler-surgery feature (new
  compile-time name-resolution phase, per-call return-stack frame, `EXIT` +
  `CATCH`/`THROW` frame unwind). `VALUE`/`TO` (23.2) delivers the named-mutable
  ergonomics for ~10% of the cost; full locals revisited later, possibly bundled
  with the multitasker (shared stack-frame discipline). (`docs/WISHLIST.md`
  "ANS Forth locals".)

These remain in `docs/WISHLIST.md` as forward-looking candidates.
