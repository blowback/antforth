# Sprint Change Proposal — Stack Tag Encoding Refactor

**Date:** 2026-04-12
**Author:** Bob (Scrum Master) — captured from BMAD party-mode design session
**Project:** antforth
**Epic in flight:** Epic 4 — Built-in Z80 Assembler
**Status:** APPROVED — 2026-04-12
**Scope classification:** Moderate (mid-epic re-scope, single new story, no PRD/MVP impact)

---

## Section 1 — Issue Summary

### Problem statement

The Epic 4 inline assembler (stories 4.1–4.3, all complete) tags operand types on the data stack using sentinel **high bytes**:

| Current sentinel | Meaning | Encoded as |
|---|---|---|
| `0xFF` | Label | `0xFFnn` (low byte = label index) |
| `0xFE` | Condition code | `0xFEnn` (low byte = cc, 0..7) |
| `0xFD` | Immediate marker | `0xFD00` (single-cell, value lost in low byte) |
| `0x00nn` | Register | low byte = r-field index (0..7 for 8-bit, 0x10..0x14 for 16-bit pairs) |

This scheme has two unrelated but compounding defects:

1. **Reserved-range bloat.** ~768 distinct stack values (`0xFD00`–`0xFFFF`) cannot appear as ordinary data without being misinterpreted as tagged operands. This forecloses a large slice of the cell value space for any future operand class or data use.
2. **The "forgot a `#`" footgun.** Because untagged registers occupy `0x0000`–`0x0014`, a bare integer like `0` is structurally indistinguishable from register `B` (r-field 0). The intuitive expression `A 0 LD,` (intended: `LD A, 0`) silently mis-assembles as `LD A, B`. The user gets working machine code that does the wrong thing — the worst possible failure mode.

### Discovery context

Identified during a design review of Epic 4 ahead of story 4.4 (Extended Z80 Opcodes). Triggered by Ant's discomfort with the current scheme while preparing to add IX/IY indexed addressing modes, where additional operand classes will pile further pressure on the already cramped sentinel space.

### Evidence

- **Code reference:** `src/assembler.asm` constants block (around line 106): `ASM_LABEL_TAG_HI EQU 0xFF`, `ASM_IMM_TAG_HI EQU 0xFD`, `ASM_COND_TAG_HI EQU 0xFE`. Register tags are documented inline in story 4.1/4.3 implementation (`asm_push_tag` uses `B = 0`).
- **Footgun example:** `A 0 LD,` parses as `LD A, B` because `0x0000` (bare zero) and the register-B tag (also `0x0000`) collide. The assembler has no way to distinguish them.
- **Story 4.3 immediate-marker workaround:** the team already accepted a two-cell pattern for immediates (`value # destreg LD,`) where `#` pushes a single-cell marker. This proves the two-cell shape is workable; we just need to apply it consistently and decouple the marker from the value cell.

---

## Section 2 — Impact Analysis

### 2.1 Change Navigation Checklist results

**Section 1 — Trigger and Context**
- [x] 1.1 Triggering story: design review preceding story 4.4 (no in-flight implementation broken; refactor is preventive).
- [x] 1.2 Issue type: **Technical limitation discovered during implementation** (combined with **failed approach requiring different solution** for the bare-int collision).
- [x] 1.3 Evidence collected: see Section 1.

**Section 2 — Epic Impact**
- [x] 2.1 Epic 4 can still be completed; it requires one inserted story before 4.4.
- [x] 2.2 Modify scope: **add new story 4.3.5 (Stack Tag Encoding Refactor)**; lightly annotate story 4.4 ACs.
- [x] 2.3 Future epics reviewed: Epic 5 (MARKER) — no dependency on tag encoding, **N/A**.
- [N/A] 2.4 No future epics invalidated; no new epics required.
- [x] 2.5 Epic order unchanged. Story order within Epic 4 changes: 4.0 → 4.1 → 4.2 → 4.3 → **4.3.5 (new)** → 4.4.

**Section 3 — Artifact Conflict and Impact Analysis**
- [N/A] 3.1 PRD: no conflict. Tag encoding is implementation-internal; PRD describes user-facing assembler behaviour, which is unchanged (and slightly improved by the new typo-detection error path).
- [!] 3.2 Architecture: minimal current coverage of stack tag scheme. **Action-needed:** add a short tag-encoding subsection to `architecture.md` as part of story 4.3.5.
- [N/A] 3.3 UX/UI: no UI surface; assembler is a REPL DSL.
- [!] 3.4 Other artifacts:
  - **Tests** in `_bmad-output/implementation-artifacts/4-1-*.md` and `4-3-*.md` that hand-construct or assert on `0xFD`/`0xFE` literal sentinels need migration. Owned by story 4.3.5 dev work.
  - **CI/build pipeline:** no impact; the test thread is the regression surface and it stays.

**Section 4 — Path Forward Evaluation**
- [x] 4.1 **Option 1: Direct adjustment (insert new story 4.3.5)** — Effort: **Medium**, Risk: **Low–Medium**. **Viable.**
- [x] 4.2 **Option 2: Rollback story 4.3** and re-implement on the new encoding — Effort: **High**, Risk: **Medium**. Not viable: throws away passing code and tests for no incremental benefit. The refactor can land cleanly on top of 4.3.
- [x] 4.3 **Option 3: PRD MVP review** — Not viable. The MVP (working assembler producing correct machine code) is achievable; this is a quality refactor, not a scope cut.
- [x] 4.4 **Selected approach: Option 1 — Direct Adjustment.**

### 2.2 Epic Impact

**Epic 4 — Built-in Z80 Assembler** (currently in-progress)
- Story 4.0 — `done`, no impact.
- Story 4.1 — `done`. Implementation will be revisited by story 4.3.5; AC text unchanged; user-facing syntax unchanged.
- Story 4.2 — `done`. Same as 4.1. Label encoding sentinel byte (`0xFF` high) is preserved; only the low-byte layout changes (class bits added).
- Story 4.3 — `done`. Same as 4.1/4.2. Condition (`0xFE`) and immediate (`0xFD`) sentinels are migrated to the unified `0xFF` sentinel with class bits; user-facing syntax (`#`, condition words `NZ`, `Z`, ...) unchanged.
- **Story 4.3.5 — NEW.** Stack Tag Encoding Refactor. Inserts between 4.3 and 4.4.
- Story 4.4 — `backlog`, **delayed by one story slot**. Receives a small AC annotation about three-operand bit-op stack pictures (`BIT n, (IX+d)` family). Lands on the new encoding foundation.

### 2.3 Story Impact

| Story | Status before | Status after | Change |
|---|---|---|---|
| 4.3 Basic Z80 Opcodes | done | done | None (foundation preserved) |
| **4.3.5 Stack Tag Encoding Refactor** | — | **backlog (NEW)** | New story to insert |
| 4.4 Extended Z80 Opcodes | backlog | backlog | Two AC annotations added; sequencing pushed by one slot |

### 2.4 Artifact Conflicts

| Artifact | Conflict? | Action |
|---|---|---|
| `_bmad-output/planning-artifacts/prd.md` | No | None |
| `_bmad-output/planning-artifacts/epics.md` | Yes | Insert story 4.3.5; annotate 4.4 ACs (this proposal includes the diff) |
| `_bmad-output/planning-artifacts/architecture.md` | Gap, not conflict | Story 4.3.5 to add a tag-encoding subsection |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | Yes | Add `4-3-5-stack-tag-encoding-refactor: backlog` (this proposal includes the diff) |
| `src/assembler.asm` | Will change during 4.3.5 dev | NOT touched by this proposal — owned by the 4.3.5 dev story |
| Existing test files referencing `0xFD`/`0xFE` literals | Migration needed | Owned by 4.3.5 dev story |

### 2.5 Technical Impact

- **All operand-consuming assembler words** (`LD,`, `ADD,`, `SUB,`, `AND,`, `OR,`, `XOR,`, `CP,`, `JP,`, `JR,`, `CALL,`, `RET,`, `PUSH,`, `POP,`, `INC,`, `DEC,`, ...) need their pop/decode sequences rewritten against the new encoding.
- **`asm_is_imm_tag`** and **`asm_is_cond_tag`** helpers (story 4.3 task 1.4 and 3.3) become **`asm_is_tagged`** + class extractor — single sentinel check, then mask off class bits.
- **`forgot-#` detector** is a new helper called at the entry of every operand-consuming word: if a popped operand has high byte `≠ 0xFF`, the word raises a clear error (`expected tagged operand, got bare integer N — did you mean #N ?`) instead of mis-assembling.
- **Two-cell layout for immediates** changes the stack picture for any word taking an immediate: it pops a marker cell *and* a value cell. Side benefit: 16-bit immediates are no longer bottled up in the 8 low bits of a single sentinel cell — `0x1234 # BC LD,` works without contortions.
- **Two-cell layout for indexed-addressing displacements** is the same pattern, ready for use by story 4.4.
- **Performance:** all decoding is compile-time (assembling source). The extra cycles are utterly inconsequential.

---

## Section 3 — Recommended Approach

**Option 1 — Direct Adjustment.** Insert one new story (4.3.5) between completed story 4.3 and backlog story 4.4. No rollback, no MVP change.

### Rationale

- Rolling back 4.3 (Option 2) would discard a complete, tested, working set of basic-opcode words to no benefit. The refactor can be applied to the existing assembler in place and re-verified by the existing test suite plus new tests for the typo-detection path.
- A scope reduction (Option 3) is not warranted — the MVP is intact, the user-facing language is intact, and this is preventive quality work, not damage control.
- Doing the refactor *before* story 4.4 is essential. Story 4.4 introduces IX/IY indexed addressing with displacements, which already needs a two-cell operand layout. Building 4.4 on the old encoding would mean either bolting on a third sentinel byte (worse) or rewriting 4.4's internals during 4.3.5 (much more work). **The right time is now.**

### Effort estimate

**Medium.** Comparable in scope to story 4.3 itself: every operand-consuming assembler word touches its pop/decode sequence; tests need migration; a new typo-detection helper is added; existing user-facing tests must continue to pass. Estimated as a single sprint slot.

### Risk assessment

**Low–Medium.**
- *Low* on user-visible behaviour: existing CODE-word source files continue to work (modulo intended typo-detection errors that previously silently misassembled).
- *Medium* on implementation churn: many small changes across `assembler.asm`. Mitigation — the existing story-4.1/4.2/4.3 test suite is the regression net, plus a dedicated typo-detection test suite added in 4.3.5.

### Timeline impact

One additional story slot in Epic 4. Story 4.4 starts after 4.3.5 lands rather than directly after 4.3.

---

## Section 4 — Detailed Change Proposals

### 4.1 Locked design decisions (carried forward from party-mode session, 2026-04-12)

| # | Decision |
|---|---|
| D1 | Single sentinel byte: `0xFF` high byte for ALL tagged operand cells. Untagged cells (high byte ≠ `0xFF`) are bare integer values. |
| D2 | Low byte split into 3-bit class (top) + 5-bit index (bottom). |
| D3 | Initial class assignment: `000` 8-bit register, `001` condition code, `010` immediate marker, `011` 16-bit register, `100` indexed/indirect addressing mode, `101` label, `110` reserved, `111` reserved. |
| D4 | Immediates use a **two-cell** stack layout: tag cell `0xFF<class=010 index=0>` plus a value cell directly below it. Fixes 8-bit limitation and gives 16-bit immediates natively. |
| D5 | Indexed addressing modes carrying a displacement (`(IX+d)`, `(IY+d)`) use the same two-cell pattern: tag cell + displacement cell. |
| D6 | Bit numbers (`BIT`/`SET`/`RES`), interrupt mode (`IM`), and restart vectors (`RST`) all use the general immediate class with per-word range validation in the consuming assembler word (rather than baked-in word-per-value or a separate "small constant" class). Prioritises uniformity over micro-optimisation. |
| D7 | A **`forgot-#` detection helper** is called at the entry of every operand-consuming word. If a popped operand has high byte `≠ 0xFF`, the word raises a clear error rather than mis-assembling. This is the headline user-facing benefit. |
| D8 | The two reserved classes (`110`, `111`) stay reserved. No speculative use. |

### 4.2 Strawman tag table (Winston's design, 2026-04-12)

```
Tag cell format:  0xFF <CCCIIIII>
                       │   │
                       │   └── 5-bit index (0..31 per class)
                       └────── 3-bit class (0..7)

Class 000  8-bit register     A,B,C,D,E,H,L (Z80 r-field 0..7)
                              Headroom for I, R, IXH, IXL, IYH, IYL
Class 001  Condition code     NZ,Z,NC,C,PO,PE,P,M (3 bits used)
Class 010  Immediate marker   value lives in next stack cell
Class 011  16-bit register    BC,DE,HL,SP,IX,IY,AF,AF', shadow set
Class 100  Indexed/indirect   (HL),(BC),(DE),(IX+d),(IY+d),(nn)
                              Forms with displacement use a second stack cell
Class 101  Label              forward & backward refs
Class 110  RESERVED
Class 111  RESERVED
```

### 4.3 Edit proposals — `_bmad-output/planning-artifacts/epics.md`

#### 4.3.a Insert new Story 4.3.5 between Story 4.3 and Story 4.4 (after line 925)

**Proposed new content:**

```markdown
### Story 4.3.5: Stack Tag Encoding Refactor

As an antforth assembler user,
I want operand type errors (like `A 0 LD,` instead of `A 0 # LD,`) to be caught at assemble time with a clear message,
So that I cannot silently produce machine code that does the wrong thing.

**Background:**
The original tag encoding (story 4.1/4.2/4.3) used three sentinel high bytes
(`0xFF` label, `0xFE` condition, `0xFD` immediate) and tagged 8-bit registers as
`0x00nn`. This made bare integer 0 indistinguishable from register B and burned
~768 reserved cell values. This story unifies the encoding and adds typo
detection without changing user-facing syntax.

**Acceptance Criteria:**

**Given** any tagged operand (register, condition, label, immediate marker,
addressing mode) on the data stack
**When** examined
**Then** the high byte of the cell is exactly `0xFF` and the low byte holds a
3-bit class field (top) and a 5-bit index field (bottom)

**Given** an operand-consuming assembler word receives an operand
**When** the operand cell's high byte is not `0xFF`
**Then** the word raises a clear error (e.g. `expected tagged operand, got
bare integer N — did you mean #N ?`) and does not assemble any bytes

**Given** an immediate operand
**When** `42 # A LD,` is typed
**Then** the stack picture during `LD,` execution is `[..., 42, <imm-tag>, A-tag]`
(two cells for the immediate: marker cell with class=immediate, value cell
directly below) and the assembled bytes are `0x3E 0x2A`

**Given** a 16-bit immediate operand
**When** `0x1234 # BC LD,` is typed
**Then** the assembled bytes are `0x01 0x34 0x12` (the value cell holds the
full 16-bit value, no longer bottled into the low byte of a sentinel)

**Given** the user types `A 0 LD,` (forgetting the `#`)
**When** `LD,` examines its operands
**Then** an error is raised pointing at the bare integer 0, and no bytes are
assembled

**Given** the existing story 4.1, 4.2, and 4.3 test suite
**When** re-run after the encoding refactor
**Then** every existing test continues to pass (modulo migration of any test
that hand-constructs `0xFD`/`0xFE` literal sentinels)

**Given** new REPL-piped test scripts covering the typo-detection path
**When** run against the refactored assembler
**Then** all "forgot the #" cases produce clear errors and all "correctly
written" cases assemble identically to before

**Given** the architecture document
**When** updated as part of this story
**Then** it contains a new subsection describing the tag-cell format
(`0xFF <class:3><index:5>`), the class table, the two-cell layout for
immediates and displacements, and a worked example showing `LD A, #42` and
`LD A, B` side by side
```

#### 4.3.b Annotate Story 4.4 (around line 938 — "bit operations" AC)

**OLD:**
```markdown
**Given** a CODE definition using bit operations
**When** `3 A BIT,` (BIT 3, A), `5 B SET,` (SET 5, B), `7 C RES,` (RES 7, C) are typed
**Then** the correct CB-prefixed opcodes are assembled
```

**NEW:**
```markdown
**Given** a CODE definition using bit operations
**When** `3 # A BIT,` (BIT 3, A), `5 # B SET,` (SET 5, B), `7 # C RES,` (RES 7, C) are typed
**Then** the correct CB-prefixed opcodes are assembled
**And** bit numbers outside 0..7 raise a clear range error at assemble time

**Given** a CODE definition using bit operations on indexed memory
**When** e.g., `3 # (IX) 5 +D BIT,` (BIT 3, (IX+5)) is typed
**Then** the correct DDCB-prefixed opcode sequence is assembled
**And** the three-operand stack picture (bit-immediate + indexed-addr-tag + displacement-cell)
is consumed correctly by `BIT,` / `SET,` / `RES,`
```

**Rationale:** Story 4.4's bit-op AC was written assuming the old encoding where
`3` was a bare integer that the word interpreted positionally. With the new
encoding, bit numbers are explicit immediates (`#`) for uniformity with all
other immediate operands (Decision D6). The three-operand `BIT n, (IX+d)`
case is called out explicitly because its stack picture is non-trivial and
deserves a dedicated test.

#### 4.3.c Annotate Story 4.4 (around line 946 — I/O instructions AC)

**OLD:**
```markdown
**Given** a CODE definition using I/O instructions
**When** `(C) A IN,` (IN A, (C)), `(C) A OUT,` (OUT (C), A), `0x42 # A IN,` (IN A, (0x42)) are typed
**Then** the correct opcodes are assembled for port I/O
```

**NEW:**
```markdown
**Given** a CODE definition using I/O instructions
**When** `(C) A IN,` (IN A, (C)), `A (C) OUT,` (OUT (C), A), `0x42 # A IN,` (IN A, (0x42)) are typed
**Then** the correct opcodes are assembled for port I/O
```

**Rationale:** `(C) A OUT,` reads as "to (C), source A" under the established
RPN destination-first convention; the original AC text reversed source and
destination. Minor textual fix surfaced while reviewing 4.4 ACs in context of
this refactor.

### 4.4 Edit proposal — `_bmad-output/implementation-artifacts/sprint-status.yaml`

**OLD (lines 67–73):**
```yaml
  epic-4: in-progress
  4-0-startup-banner: done
  4-1-code-word-framework-and-basic-instructions: done
  4-2-labels-and-data-definition-words: done
  4-3-basic-z80-opcodes: done
  4-4-extended-z80-opcodes: backlog
  epic-4-retrospective: optional
```

**NEW:**
```yaml
  epic-4: in-progress
  4-0-startup-banner: done
  4-1-code-word-framework-and-basic-instructions: done
  4-2-labels-and-data-definition-words: done
  4-3-basic-z80-opcodes: done
  4-3-5-stack-tag-encoding-refactor: backlog
  4-4-extended-z80-opcodes: backlog
  epic-4-retrospective: optional
```

### 4.5 Edit proposal — `_bmad-output/planning-artifacts/architecture.md`

No diff in this proposal. The new tag-encoding subsection is folded into the
acceptance criteria of story 4.3.5 (final AC: "the architecture document …
contains a new subsection describing the tag-cell format …"). Paige (Tech
Writer) volunteered to own the diagram during the party-mode session. The
content lives where it belongs — created alongside the implementation it
describes.

### 4.6 No edits proposed for

- `prd.md` — no PRD impact
- `src/assembler.asm` — owned by the 4.3.5 dev story, not by this proposal
- Memory files — the existing memory entry on assembler operand order remains correct (Zilog dst-src order is unaffected by tag encoding)

---

## Section 5 — Implementation Handoff

### Scope classification

**Moderate.** This is a backlog reorganisation (one new story inserted, one existing story annotated, status file updated). No PRD/architecture/MVP rework. Standard SM + Dev handoff.

### Roles and responsibilities

| Role | Agent | Responsibilities |
|---|---|---|
| **Scrum Master** | Bob | Apply the epics.md and sprint-status.yaml diffs in this proposal once approved. Ensure story 4.4 does not start until 4.3.5 is `done`. |
| **Story author** | Bob (via `bmad-bmm-create-story`) | When 4.3.5 is up next, create the dedicated story file (`_bmad-output/implementation-artifacts/4-3-5-stack-tag-encoding-refactor.md`) with full task breakdown, referencing this proposal. |
| **Developer** | Amelia (via `bmad-bmm-dev-story`) | Implement the refactor in `src/assembler.asm`. Migrate existing tests. Add new typo-detection REPL tests. Update architecture.md with the tag-encoding subsection. |
| **Tech Writer** | Paige | Architecture-doc subsection is folded into the dev story per Paige's offer in the party-mode session. |
| **QA** | Quinn | Author the typo-detection REPL test cases (`A 0 LD,` → error, `A #0 LD,` → clean) as part of the dev story. |

### Success criteria for story 4.3.5

1. All existing story 4.1/4.2/4.3 tests pass after the refactor.
2. New typo-detection REPL tests pass (forgotten `#` produces a clear error, never silent miscompilation).
3. 16-bit immediate test (`0x1234 # BC LD,`) passes with no bottlenecking through low-byte sentinels.
4. `architecture.md` contains the tag-encoding subsection per the final AC.
5. Memory entries on stack-tagging conventions are added or updated as needed.

### Sequencing

```
[done] 4.3 Basic Z80 Opcodes
   ↓
[NEW] 4.3.5 Stack Tag Encoding Refactor   ← gating story
   ↓
4.4 Extended Z80 Opcodes
   ↓
4.4 starts on the new encoding foundation; IX/IY indexed addressing
inherits the two-cell displacement pattern for free.
```

---

## Section 6 — Approval

**Approved by Ant on 2026-04-12.**

All epics.md and sprint-status.yaml diffs have been applied.

---

*Generated 2026-04-12 by `bmad-bmm-correct-course` workflow.*
*Source design discussion: BMAD party-mode session, 2026-04-12, with Winston, Amelia, Quinn, Mary, Barry, Bob, Paige, John, Sally, BMad Master.*
