---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
phase: 7
phaseScope: 'Phase 7 — common-word gaps (Epic 27)'
targetVersion: 'v3.3.0'
lastEdited: '2026-10-08'
inputDocuments:
  - docs/dev_journal.md
  - docs/ans-forth-core-compliance.md
  - _bmad-output/planning-artifacts/epics-phase5-epic-23.md
  - _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md
  - _bmad-output/implementation-artifacts/epic-26-retro-2026-07-02.md
  - src/stack_ops.asm
  - src/logic.asm
  - src/control_flow.asm
---

# antforth — Epic Breakdown (Phase 7 — common-word gaps, Epic 27)

## Overview

Phase 7 closes twelve small word-level gaps logged in `docs/dev_journal.md`:
stack shufflers, comparisons, two control-flow words, and `?`. There is no new
execution model and no banking-subsystem change. Every word is either an ANS
Forth 1994 word currently marked "Deliberately-omitted" in
`docs/ans-forth-core-compliance.md`, or a common-practice extension.

Phase 7 ships as **antforth v3.3.0**, a single epic (Epic 27) on top of the
v3.2.1 baseline (HEAD 30,754 B; `make test` PASS; `make test-repl`
1012 PASS / 0 FAIL). As with Epic 23, this document is sized to the work:
conventions are kept (FR inventory, per-story ACs, byte budget, S9 lines) and
the standing process commitments carry forward by reference.

No PRD or architecture document covers this phase; requirements come from
`docs/dev_journal.md` and the ANS 94 section numbers in the compliance doc.

## Requirements Inventory

### Functional Requirements

#### Stack words (FR-P7-1..3)

- **FR-P7-1 (`NIP`):** `NIP ( x1 x2 -- x2 )`. ANS Forth 1994 §6.2.1930 (Core Ext).
- **FR-P7-2 (`TUCK`):** `TUCK ( x1 x2 -- x2 x1 x2 )`. ANS Forth 1994 §6.2.2300
  (Core Ext).
- **FR-P7-3 (`-ROT`):** `-ROT ( x1 x2 x3 -- x3 x1 x2 )`, the inverse of `ROT`.
  **antforth extension** (common practice; not in ANS 94).

#### Comparisons (FR-P7-4..9)

All return a well-formed flag: TRUE = -1 (all bits set), FALSE = 0.

- **FR-P7-4 (`<>`):** `<> ( x1 x2 -- flag )`, true if x1 ≠ x2. §6.2.0500 (Core Ext).
- **FR-P7-5 (`0<>`):** `0<> ( x -- flag )`, true if x ≠ 0. §6.2.0260 (Core Ext).
- **FR-P7-6 (`0>`):** `0> ( n -- flag )`, true if n > 0 (signed). §6.2.0280
  (Core Ext).
- **FR-P7-7 (`U>`):** `U> ( u1 u2 -- flag )`, true if u1 > u2 (unsigned).
  §6.2.2350 (Core Ext).
- **FR-P7-8 (`<=`):** `<= ( n1 n2 -- flag )`, true if n1 ≤ n2 (signed).
  **antforth extension** (common practice; not in ANS 94).
- **FR-P7-9 (`>=`):** `>= ( n1 n2 -- flag )`, true if n1 ≥ n2 (signed).
  **antforth extension** (common practice; not in ANS 94).

#### Control flow (FR-P7-10..11)

- **FR-P7-10 (`AGAIN`):** `AGAIN ( C: dest -- )`, immediate, compile-only.
  Compiles an unconditional branch back to the `BEGIN` it pairs with. §6.2.0700
  (Core Ext).
- **FR-P7-11 (`?DO`):** `?DO ( C: -- do-sys ) ( n1|u1 n2|u2 -- ) ( R: -- loop-sys )`,
  immediate, compile-only. Like `DO`, but if the limit equals the start index the
  loop body is skipped entirely and execution continues after the matching
  `LOOP`/`+LOOP`. §6.2.0620 (Core Ext). Must pair with both `LOOP` and `+LOOP`,
  and `LEAVE`, `UNLOOP`, `I`, `J` must behave inside a `?DO` loop exactly as they
  do inside a `DO` loop.

#### Tools (FR-P7-12)

- **FR-P7-12 (`?`):** `? ( a-addr -- )`, display the cell at a-addr, as `@ .`.
  ANS Forth 1994 §15.6.1.0600 (Programming-Tools).

#### Documentation (FR-P7-13)

- **FR-P7-13 (doc sync):** `docs/ans-forth-core-compliance.md` rows for the eight
  Core-Ext words flip from "Deliberately-omitted" to "Implemented" with a source
  location; `?` gets a Tools row; `-ROT`, `<=`, `>=` are listed as extensions.
  `docs/dev_journal.md` entries for all twelve words are marked resolved.

### NonFunctional Requirements

- **NFR-P7-1 (regression):** the v3.2.1 baseline (`make test` PASS,
  `make test-repl` 1012 PASS / 0 FAIL) passes on every Phase-7 candidate. New
  probes are added; none are removed. A single regression blocks the v3.3.0 tag.
- **NFR-P7-2 (byte budget):** every story records its real byte delta against
  the 30,754 B baseline. Epic estimate ≈ 300–350 B; agreed envelope ≤ 500 B
  (2026-10-08). Growth beyond it needs a stated reason.
- **NFR-P7-3 (no hot-path tax):** no change to `NEXT`, `EXIT_CODE`, `DOCOL`, or
  the existing `DO`/`LOOP`/`+LOOP` runtimes' cost on loops that don't use `?DO`.
- **NFR-P7-4 (stack-safety parity):** new CODE words use the same
  `check_underflow` / `check_underflow_2` discipline as their neighbours
  (`SWAP`, `OVER`, `U<`, etc.).
- **NFR-P7-5 (register contract):** new CODE words preserve DE = IP and leave
  BC = TOS (`project_multitasker_pause_register_contract`); no EXX use.
- **NFR-P7-6 (testing):** behaviour is tested through the Forth threading
  model with REPL-piped scripts. Probe lines stay ≤ 128 chars (TIB_SIZE). New
  colon-body probes respect the `$8000` straddle lint.
- **NFR-P7-7 (hardware smoke):** every binary-delta story runs an S9 hardware
  smoke on real CP/M 2.2 / MicroBeast, and posts the recipe in the closing review
  chat message.

### Additional Requirements

From the existing code and project conventions (no architecture doc for this
phase):

- **Brownfield, no setup story.** Starts from the v3.2.1 working tree.
- **Home files follow existing grouping:** `NIP`/`TUCK`/`-ROT` in
  `src/stack_ops.asm`; comparisons in `src/logic.asm` (next to `=`, `<`, `>`,
  `0=`, `0<`, `U<`); `AGAIN`/`?DO` in `src/control_flow.asm`; `?` next to `.S`
  or the other Tools words.
- **Extension flagging (CCD-3):** non-ANS words (`-ROT`, `<=`, `>=`) carry a
  `; antforth extension` source comment.
- **`?DO` must use the existing LEAVE chain.** `DO` saves the outer
  `leave_chain_head` on the compile-time stack and resets it; `LOOP`/`+LOOP` walk
  the chain to patch forward branches, then restore it. `?DO`'s skip branch needs
  to land at the same exit point, so linking its forward cell into the LEAVE
  chain is the obvious route. The runtime must drop limit+index from the data
  stack without pushing a loop frame on the skip path.
- **`AGAIN` mirrors `UNTIL`** but compiles `BRANCH` instead of `?BRANCH`;
  `?COMP` guard as for the other control-flow immediates.
- **Comparisons are CODE words** (decided 2026-10-08), matching `=`, `<`, `>`,
  `0=`, `0<`, `U<`, and building the flag the same way (`LD BC,0` / `DEC BC`).
  Threaded wrappers (`= 0=`, `SWAP U<`) were about 50 B smaller in total but
  slower, and were rejected.
- **`CORE-EXT` environment query stays `false`.** Adding 8 Core-Ext words
  doesn't complete the word set; the `env_table` comment count
  (`src/system.asm:576`, "13/46") is updated to match.
- **Follow-on cleanup (optional, in scope for the `AGAIN` story):** the
  `BEGIN … 0 UNTIL` workaround in the multitasker demos and docs can switch
  to `BEGIN … AGAIN`.
- **Carried-forward constraints:** S1–S12 standing commitments; CP/M 0x1A
  EOF discipline for any `.FTH` in `disk/a/`; `git tag v3.3.0` is left to the
  project lead.

### FR Coverage Map

| FR | Epic | Words |
|---|---|---|
| FR-P7-1..3 | 27 | `NIP`, `TUCK`, `-ROT` |
| FR-P7-4..9 | 27 | `<>`, `0<>`, `0>`, `U>`, `<=`, `>=` |
| FR-P7-10 | 27 | `AGAIN` |
| FR-P7-11 | 27 | `?DO` |
| FR-P7-12 | 27 | `?` |
| FR-P7-13 | 27 | compliance doc + dev journal sync |

## Epic List

### Epic 27: Common-word gaps (antforth v3.3.0)

Twelve words Forth programmers expect to type without defining them first:
`NIP TUCK -ROT`, `<> 0<> 0> U> <= >=`, `AGAIN ?DO`, and `?`. Code ported from
gforth or written from Forth tutorials runs without local definitions, and the
demos lose their `BEGIN … 0 UNTIL` workaround. No new execution model, no
banking change, zero regressions.

**FRs covered:** FR-P7-1 … FR-P7-13

## Epic 27: Common-word gaps (antforth v3.3.0)

**Goal:** Add twelve words Forth programmers expect to find built in, so code
ported from gforth or written from Forth tutorials runs without local
definitions. Ship as v3.3.0 with zero regressions.

**Standalone:** each of 27.1–27.4 depends only on the v3.2.1 baseline and may
land in any order. 27.5 needs all four.

**Byte budget:** estimate ≈ 335 B (27.1 ≈ 85 · 27.2 ≈ 150 · 27.3 ≈ 30 ·
27.4 ≈ 70 · 27.5 ≈ 0); envelope ≤ 500 B.

**Inventory found while drafting:** `examples/batnball.fth:85-86` defines its
own `>=`/`<=` (removed in 27.2). 17 `BEGIN … 0 UNTIL` sites exist across
`disk/a/TRAFFIC.FTH`, 8 test files and 3 docs; 27.3 converts the demo and the
docs, and leaves test files alone so regression probes don't change shape.

---

### Story 27.1: Stack words `NIP`, `TUCK`, `-ROT` and `?`

**Covers:** FR-P7-1, 2, 3, 12, 13 (part)

As a Forth programmer,
I want `NIP`, `TUCK`, `-ROT` and `?` built in,
So that common stack shuffles and quick variable inspection work without
defining them myself.

**Acceptance Criteria:**

**Given** the candidate kernel
**When** I run `1 2 NIP .S`, `1 2 TUCK .S`, `1 2 3 -ROT .S`
**Then** the stack shows `2`, `2 1 2`, `3 1 2` respectively (§6.2.1930,
§6.2.2300; `-ROT` is the inverse of `ROT`)
**And** `1 2 3 -ROT ROT` leaves `1 2 3`

**Given** `VARIABLE V  42 V !`
**When** I run `V ?`
**Then** it prints `42 ` (§15.6.1.0600)
**And** `HEX V ?` prints `2A ` (BASE is honoured)

**Given** a stack with too few items
**When** `NIP`, `TUCK` or `-ROT` runs
**Then** it raises the same underflow error as its neighbour (`SWAP`/`OVER`
for `NIP`/`TUCK`, `ROT` for `-ROT`)
**And** no new checking scheme is introduced

**Given** the new CODE words
**When** they are reviewed
**Then** each preserves DE = IP and leaves BC = TOS, with no EXX use
**And** `-ROT` carries a `; antforth extension` source comment
**And** a new REPL-piped probe file plus Makefile target, wired into
`test-repl`, covers every case above at interpret level and inside a colon body
**And** the compliance doc rows for `NIP`/`TUCK` flip to Implemented, `?` gets a
§15.6.1.0600 Tools row, `-ROT` is listed as an extension, and the dev-journal
entries are marked resolved
**And** the real byte delta is recorded (est. ≈ 85 B)
**And** the S9 hardware-smoke recipe is posted in the closing review message

---

### Story 27.2: Comparison words `<>`, `0<>`, `0>`, `U>`, `<=`, `>=`

**Covers:** FR-P7-4..9, 13 (part)

As a Forth programmer,
I want the common comparison words as fast CODE words,
So that I can write conditions directly instead of `= 0=` or `SWAP U<`.

**Acceptance Criteria:**

**Given** the candidate kernel
**When** each word is tested at boundary values
**Then** it returns -1 / 0 as follows:
- `<>`: equal and unequal pairs, including `-1 -1` and `0 -1` (§6.2.0500)
- `0<>`: `0`, `1`, `-1`, `$8000` (§6.2.0260)
- `0>`: `0` → false, `1` → true, `-1` → false, `$7FFF` → true,
  `$8000` → false (§6.2.0280)
- `U>`: `$FFFF 1 U>` → true, `1 $FFFF U>` → false, equal → false (§6.2.2350)
- `<=` and `>=`: equal, less and greater, plus the signed-overflow pairs
  `$7FFF $8000` and `$8000 $7FFF`, where a plain subtraction gives the
  wrong answer

**Given** each new word
**When** it is reviewed
**Then** it is a CODE word in `src/logic.asm` using the existing flag idiom
(`LD BC,0` / `DEC BC`)
**And** it uses the same underflow checks as its sibling (`=`/`<`/`U<` for
2-operand words, `0=`/`0<` for 1-operand words)
**And** it preserves DE = IP
**And** `<=` and `>=` carry `; antforth extension`

**Given** `examples/batnball.fth`
**When** its local `>=`/`<=` definitions are removed
**Then** it still loads and runs

**Given** the probe file
**When** `test-repl` runs
**Then** every boundary case above passes at interpret level and inside a
colon body
**And** the compliance doc rows for the four Core-Ext words flip to
Implemented, `<=`/`>=` are listed as extensions, and the dev-journal entries
are marked resolved
**And** the real byte delta is recorded (est. ≈ 150 B)
**And** the S9 hardware-smoke recipe is posted in the closing review message

---

### Story 27.3: `AGAIN`

**Covers:** FR-P7-10, 13 (part)

As a Forth programmer,
I want `BEGIN … AGAIN`,
So that infinite loops (task bodies, event loops) read as what they are.

**Acceptance Criteria:**

**Given** `: T 0 BEGIN 1+ DUP 5 = IF EXIT THEN AGAIN ;`
**When** I run `T .`
**Then** it prints `5`
**And** `AGAIN` compiles an unconditional `BRANCH` back to the matching `BEGIN`
(§6.2.0700), structured like `UNTIL` with `BRANCH` in place of `?BRANCH`

**Given** `BEGIN … AGAIN` nested inside `IF … THEN`, and enclosing an inner
`DO … LOOP` with `LEAVE`
**When** the definitions run
**Then** each exits through the expected path with balanced stacks
**And** control-structure checking is the same as `UNTIL`'s, no stricter

**Given** `STATE` = 0
**When** `AGAIN` is typed at the prompt
**Then** it raises `-14` (compile-only), as `UNTIL` does

**Given** a banked colon definition near the `$C000` window top
**When** `AGAIN` compiles its branch
**Then** the existing window-top guard on `,` raises `-8`, with no new guard
code; a probe confirms it

**Given** the demo and docs that use the workaround
**When** this story lands
**Then** `disk/a/TRAFFIC.FTH` (still 0x1A-terminated), `docs/phase6-multitasker.md`
and `docs/throw-codes.md` use `BEGIN … AGAIN` in place of `BEGIN … 0 UNTIL`
**And** test files are not changed
**And** a REPL-piped probe file covers the cases above
**And** the compliance doc row flips to Implemented (workaround note removed)
and the dev-journal entry is marked resolved
**And** the real byte delta is recorded (est. ≈ 30 B)
**And** the S9 hardware smoke includes running the updated `TRAFFIC.FTH`, and
the recipe is posted in the closing review message

---

### Story 27.4: `?DO`

**Covers:** FR-P7-11, 13 (part)

As a Forth programmer,
I want `?DO`,
So that a counted loop whose limit equals its start runs zero times instead
of 65,536.

**Acceptance Criteria:**

**Given** `: C ( n -- count ) 0 SWAP 0 ?DO 1+ LOOP ;`
**When** I run `0 C .`, `1 C .`, `5 C .`
**Then** it prints `0`, `1`, `5` (§6.2.0620)

**Given** `?DO` paired with `+LOOP`
**When** limit = start
**Then** the body is skipped
**And** when limit ≠ start, behaviour matches `DO … +LOOP` for positive and
negative steps

**Given** a `?DO` loop containing `LEAVE` (bare and inside `IF … THEN`),
`UNLOOP EXIT`, `I`, and a nested `?DO`/`DO` using `J`
**When** the definitions run
**Then** each behaves exactly as in a `DO` loop
**And** the data and return stacks are balanced after a skipped loop, a
completed loop, and a `LEAVE` exit; the REPL -274 return-stack guard does not
fire

**Given** the implementation
**When** it is reviewed
**Then** `?DO` compiles a `(?DO)` runtime followed by a forward-branch cell
linked into the existing `leave_chain_head`, so `LOOP`/`+LOOP` patch it with
no change to `LOOP`, `+LOOP` or `(DO)`
**And** on the skip path `(?DO)` drops limit and start without pushing a loop
frame
**And** `(?DO)` preserves DE = IP conventions as `BRANCH`/`(DO)` do
**And** `DO`/`LOOP`/`+LOOP` runtime cost is unchanged (NFR-P7-3)

**Given** `STATE` = 0
**When** `?DO` is typed at the prompt
**Then** it raises `-14`

**Given** a banked colon definition
**When** it contains a `?DO` loop
**Then** it compiles and runs, and the window-top guard on `,` covers it
**And** a REPL-piped probe file covers all cases above
**And** the compliance doc row flips to Implemented (workaround note removed)
and the dev-journal entry is marked resolved
**And** the real byte delta is recorded (est. ≈ 70 B)
**And** the S9 hardware-smoke recipe is posted in the closing review message

---

### Story 27.5: Epic 27 close-out and v3.3.0

**Covers:** FR-P7-13 (final sync); NFR-P7-1, NFR-P7-2

As the project lead,
I want the v3.3.0 close-out checks,
So that the release ships with the full baseline green and the version
surface aligned.

**Acceptance Criteria:**

**Given** stories 27.1–27.4 are done
**When** the full suite runs
**Then** `make test` passes and `make test-repl` shows the 1012-test baseline
plus the new probes at 0 FAIL, on iz-cpm and the banking emulator
**And** the aggregated hardware smoke passes on real MicroBeast
**And** any regression blocks the tag

**Given** the final binary
**When** it is measured
**Then** the byte delta against 30,754 B is logged against the ≤ 500 B
envelope, with a reason if it is exceeded

**Given** the version surface
**When** it is audited (S11)
**Then** the banner in `src/antforth.asm`, the REPL banner assertion (test 80)
and `README.md` read v3.3.0
**And** the `env_table` CORE-EXT count comment (`src/system.asm:576`) is
updated, while `ENVIRONMENT? CORE-EXT` still answers false
**And** `make check-doc-sync` passes; the compliance doc, dev journal and
WISHLIST reflect what shipped
**And** a Phase-7 project memory records the v3.3.0 close and byte delta
**And** `git tag v3.3.0` is left to the project lead
