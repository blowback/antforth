---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-04-14'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-04-14.md
  - _bmad-output/planning-artifacts/architecture-phase1-epics-1-8.md
  - _bmad-output/planning-artifacts/prd-phase1-epics-1-8.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-03-11.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/epic6-code-size-optimization.md
  - _bmad-output/planning-artifacts/epic7-shadow-register-optimization.md
  - _bmad-output/planning-artifacts/epic8-shadow-register-followup.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-12.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-03-12.md
  - docs/ans-forth-core-compliance.md
  - docs/z80_forth_assemblers.md
  - docs/z80-instruction-coverage.md
  - docs/z80-instruction-coverage-reaudit.md
  - docs/WISHLIST.md
  - docs/shadow-register-survey.md
  - docs/shadow-register-followup-survey.md
  - docs/register-conventions.md
workflowType: 'architecture'
project_name: 'antforth'
user_name: 'Ant'
date: '2026-04-14'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The 2026-04-20-revised PRD specifies **47 Functional Requirements** organised into 6 capability areas, each tagged to the epic that delivers it:

- **FR1–FR9 (Epic 9):** Numeric-literal prefix recognition (Forth 2014 §3.4.1.3 + `0x` extension). Architectural impact: extension of the outer-interpreter number-parsing path — a single hot loop touched by every token.
- **FR10–FR15 (Epic 10):** Double-precision arithmetic, pictured numeric output, Core-gap word completion to 100%. Architectural impact: new data-type handling on the parameter stack (double-cells), a dedicated output-formatting buffer, and a scattering of primitive additions across existing modules.
- **FR16–FR22 (Epic 11):** Exception wordset (`CATCH`/`THROW`) with **full internal error migration** — every error path in the interpreter, compiler, and primitives routes through THROW. Architectural impact: deep — touches the return stack discipline (exception frames), every error-raising primitive, and the REPL top-level loop.
- **FR23–FR29, FR31 (Epic 12):** Multi-vocabulary Search-Order wordset (`WORDLIST`, `SET-ORDER`, `DEFINITIONS`, ...). Architectural impact: generalisation of the existing single-vocabulary hash dictionary into per-wordlist hash tables; new search-order data structure consumed by word lookup on every token. Built-in opcode words remain kernel-resident in the global dictionary as today (no ASSEMBLER wordlist; FR30 withdrawn 2026-04-27).
- **FR32–FR44 (Epic 13):** File-Access wordset against CP/M 2.2 BDOS. Architectural impact: new kernel subsystem for file-handle management, byte-stream I/O abstracted over CP/M's 128-byte record model.
- **FR45–FR47 (phase-wide constraint):** Backward compatibility with all Epics 1–8 behaviour and test suites.

**Non-Functional Requirements:**

The PRD specifies **21 NFRs** across five categories, with the architecturally load-bearing ones being:

- **NFR1 (prefix parse overhead ≤ ~20 cycles), NFR2 (multi-vocab lookup regression ≤ 10%)** — constrain the hot-path designs for the number recogniser and the word-lookup fan-out
- **NFR3 (CATCH/THROW overhead ≤ ~15 cycles uncaught)** — constrains the exception-frame implementation on the return stack
- **NFR4 (kernel ROM footprint budget, per-epic)** — each epic logs its delta and justifies increases; Phase-2 net-delta is expected to be positive (no lazy-load offset); size-reduction opportunities are post-2.0 dedicated stories
- **NFR6 / NFR7 (REPL survivability, state integrity after THROW)** — architectural discipline: every error-raising site has a defined unwind protocol
- **NFR8 (filesystem error recovery, no orphaned handles)** — file-handle lifecycle discipline
- **NFR13 (CP/M 2.2 BDOS function allow-list, specific functions)** — constrains the BDOS integration

**Scale & Complexity:**

- **Primary domain:** Embedded language implementation (Z80 assembly + bootstrapped Forth) on CP/M 2.2
- **Complexity level:** Low by enterprise-software metrics; high in technical precision (cycle-accurate, byte-accurate). Brownfield with a strong existing kernel to extend.
- **Estimated new architectural components/subsystems for this phase:** 5 distinct subsystems, one per epic:
  1. **Numeric-literal recogniser extension** — integrates with the existing outer-interpreter parse loop
  2. **Double-precision primitive suite + pictured-output buffer** — mostly new primitives on existing register conventions
  3. **Exception subsystem** — new return-stack frame type + pervasive error-path retargeting
  4. **Multi-vocabulary dictionary** — generalisation of existing XOR-rotate 64-bucket hash scheme
  5. **File-Access subsystem** — new BDOS integration layer + INCLUDE parser

### Technical Constraints & Dependencies

**Hard platform constraints (inherited from phase 1, unchanged):**

- Zilog Z80 @ 8 MHz, instruction set only (no Z80N / eZ80 / Z180 extensions)
- CP/M 2.2 TPA (`0100h`–`FFFFh` minus BDOS/CCP) — typically ~56–58 KB usable
- MicroBeast 512K banked RAM/ROM; kernel + dictionary live in bank 0 under TPA
- All I/O via BDOS calls; no direct hardware I/O in kernel
- Standard CP/M console (BDOS 1, 2, 6, 9); no ANSI / cursor / colour

**Register conventions (inherited — must be preserved):**

- **BC** = TOS (top-of-stack cached in register per existing TOS-in-register optimisation)
- **SP** = parameter stack pointer
- **IX** = return stack pointer
- **IY** = user area pointer (USER variable base)
- **DE** = instruction pointer (IP) in the inner interpreter
- **HL** = working register (W)
- **Shadow registers** — used per Epic 7/8 conventions (`docs/register-conventions.md`, memory entry on EXX usage)

**Threading model (inherited — must be preserved):**

- Direct threading (JP-based), per memory entry
- DEFWORD cf label via `EQU body-3` pointing to `JP DOCOL`
- Compiled colon definitions: sequence of CFAs with EXIT sentinel

**New dependencies introduced this phase:**

- **BDOS functions 15, 16, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40** — required for File-Access wordset (Epic 13); function 25 resolves the current drive letter for filenames without an explicit drive prefix
- No new external software dependencies — everything is in-tree source

**Backward-compatibility contract:**

- Every Epic 1–8 test script must pass on 2.0 (NFR10)
- Every pre-phase CODE-word source file must assemble identically (FR31, NFR15)
- Unprefixed `<BASEnum>` numeric-literal form continues to parse per `BASE` exactly as before (FR52)

### Cross-Cutting Concerns Identified

These concerns span multiple epics and warrant dedicated architectural decisions upfront:

1. **Return-stack usage discipline.** Epic 11 (exception frames), Epic 13 (INCLUDE nesting / file-handle state), and existing Epic 3 (colon-definition return-addr frames) all write to the return stack at IX. Frame layouts must be disambiguable and nesting must not alias. A **return-stack frame taxonomy** is needed before Epic 11 implementation begins.

2. **Dictionary layout changes.** Epic 12 generalises the single-vocabulary hash scheme to per-wordlist tables. This is a breaking change to in-memory dictionary layout. Epic 12 defines the binary-compatibility contract with saved session state — or explicitly breaks it. A **dictionary header format** decision is needed.

3. **Error-code allocation.** ANS standard THROW codes (Epic 11) must coexist with any antforth-specific codes. A **throw-code allocation scheme** is needed (standard `-1`–`-58` reserved, extension range designated).

4. **File-handle lifecycle.** Epic 13 introduces file handles (FIDs). These are finite resources on CP/M 2.2. Handle acquisition, release on THROW, and the relationship between `INCLUDE` nesting and file-handle depth need a clear contract. A **file-handle lifecycle policy** is needed.

5. **Performance regression surface.** NFR1, NFR2, NFR3, NFR4, NFR5 all set performance envelopes. The existing benchmark suite (Epic 7/8) is the regression net. A **per-epic benchmark gate** (epic done only when benchmarks pass) formalises the discipline.

6. **Standards-citation discipline.** NFR17 requires every standard-derived behaviour to cite its spec section in source. This is a writing-convention concern that applies across Epics 9, 10, 11, 12, 13.

These cross-cutting concerns will be addressed in the subsequent architectural decision steps.

## Starter Template Evaluation

**Not applicable.** antforth is a brownfield Z80 assembly project (`developer_tool_embedded`) with no relevant starter-template ecosystem. The "starter" is the existing Epic 1–8 kernel itself, which provides:

- **Inner interpreter:** direct-threaded (JP-based), register allocation preserved (BC=TOS, SP=pstack, IX=rstack, IY=user, DE=IP, HL=W)
- **Outer interpreter / REPL:** established text parser, interpret/compile state machine, error-reporting convention
- **Dictionary:** XOR-rotate 64-bucket hash (single vocabulary — generalised in Epic 12)
- **Language extension layer:** colon definitions, CREATE/DOES>, control flow, MARKER, immediate words, POSTPONE
- **Built-in Z80 assembler:** 168+ opcode words, label system, two-cell tag encoding (post-4.3.5 refactor)
- **Test harness:** REPL-piped Forth test scripts (convention since Epic 3)
- **Shadow-register optimisation framework:** EXX usage conventions per Epics 7/8

All phase-2 architectural decisions build on this foundation without replacing any part of it. No external template, no scaffolding tool, no version pinning — the toolchain is a Z80 cross-assembler invoked by the project's existing build scripts.

## Core Architectural Decisions

> **Phase-1 cross-reference:** The phase-1 architecture document (`architecture-phase1-epics-1-8.md`) is the canonical reference for all inherited subsystems: inner interpreter details, DOCOL/EXIT semantics, existing XOR-rotate 64-bucket hash algorithm, CREATE/DOES> machinery, MARKER implementation, the shadow-register optimisation framework, and the existing 168+ Z80 assembler opcode implementations. **This document specifies only the additions and changes for phase 2.** Dev-agent invocations must consult both documents — phase-1 for the foundation their code integrates with, phase-2 for what they are changing or adding. Where the two documents disagree, phase-2 wins (because phase-2 describes the target state).

### Decision Priority Analysis

**Critical Decisions (block implementation of a specific epic):**
- Exception frame layout on the return stack (blocks Epic 11)
- Per-wordlist hash table layout + search-order storage (blocks Epic 12)
- File-handle representation + INCLUDE nesting (blocks Epic 13)

**Important Decisions (shape the architecture significantly):**
- Numeric recogniser integration point (Epic 9)
- Double-cell stack byte-order (Epic 10 and onward)
- Pictured-output buffer placement (Epic 10)
- Internal error migration strategy (Epic 11, phased or atomic)
- THROW code allocation scheme

**Deferred Decisions (post-2.0):**
- Whether to expose `TRAVERSE-WORDLIST` as part of Epic 12 or defer — lean defer; not in PRD scope
- Second-platform portability concerns — explicitly post-2.0 per PRD

---

### Cross-Cutting Architectural Decisions

#### CCD-1: Return-Stack Frame Taxonomy with Dual Chain Discipline

**Decision:** Four frame types live on the IX return stack. The two new types (exception, INCLUDE source) each maintain their own LIFO chain via a dedicated USER variable, avoiding any need to walk or tag the return stack.

| Frame type | Footprint | Introduced by | Chain |
|---|---|---|---|
| Colon return-addr | 2 bytes | Epic 3 (inherited) | — |
| DO-LOOP frame | 4 bytes | Epic 3 (inherited) | — |
| **Exception frame** | **8 bytes** (see E11-D1) | **Epic 11 (new)** | `CATCH-TOP` USER variable |
| **INCLUDE source frame** | **10 bytes** (see E13-D2) | **Epic 13 (new)** | `INCLUDE-TOP` USER variable |

**Chain discipline:**
- Each exception and INCLUDE frame reserves its top 2 bytes for a "previous" link — pointing to the rstack address of the next frame below it in its own chain.
- `CATCH-TOP` points to the most recent exception frame (or 0 if none).
- `INCLUDE-TOP` points to the most recent INCLUDE source frame (or 0 if the current input source is the outermost — typically keyboard at REPL startup, command-line at batch boot).
- Colon return-addr and DO-LOOP frames are **not** linked into either chain; they are entirely private to the threading model and to the iteration construct respectively.

**Rationale:** Avoids the "walk the rstack looking for a sentinel" design (which risks false positives where legitimate data happens to match a sentinel pattern) and avoids a unified cleanup chain (which would require a discriminator byte inside every frame). With dual chains, THROW gets its target frame address in O(1) (one `CATCH-TOP` read), and cleanup for INCLUDE source frames happens by walking the `INCLUDE-TOP` chain until reaching the target exception frame. Total per-frame overhead: 2 bytes (the prev-link). CATCH and INCLUDE each do one additional store (update their respective TOP variable); THROW does one read plus the cleanup walk.

**Consequences for dev agents:**
- When CATCH pushes its frame, it stores the current `CATCH-TOP` into the frame's prev-link slot, then sets `CATCH-TOP` to the frame's own address.
- When CATCH exits normally, it restores `CATCH-TOP` from the frame's prev-link before popping the frame.
- INCLUDE follows the exact symmetric pattern with `INCLUDE-TOP`.
- THROW never walks the rstack directly — it jumps to `CATCH-TOP`, processes the INCLUDE chain via `INCLUDE-TOP`, and restores state from the target frame.

#### CCD-2: THROW Code Allocation

**Decision:** Three ranges:

| Range | Use |
|---|---|
| `-1` to `-58` | **Reserved for ANS standard codes** (ANS Forth 2014 §9.3.5 table). Do not reuse these for antforth-specific errors. |
| `-59` to `-255` | **Reserved for future ANS extensions.** Do not use. |
| `-256` to `-32767` | **antforth-specific extension codes.** Allocated as needed by epics; first use claims an unused number and documents it in a table in `docs/`. |
| `+n` | User-defined codes per ANS. Never issued by the kernel. |

**Rationale:** Keeping the standard range pristine means user code written against ANS THROW codes works identically on antforth and any other ANS Forth. The antforth range is large (~32k codes) — no scarcity.

#### CCD-3: Standards-Citation Discipline (NFR18 realisation)

**Decision:** Every word whose behaviour is specified by ANS Forth 1994, Forth 2014, or an explicit antforth-specific design note shall carry a one-line comment in its assembly source citing the specification:

```
; ANS Forth 1994 §6.1.0090  `*/`           — star-slash
; Forth 2014 §6.2.2270       CATCH          — catch
; antforth extension         0x             — C-style hex prefix
```

**Rationale:** When a behaviour disagrees with what a reader expects, the citation is the authoritative answer. This directly supports future ANS compliance re-audits.

#### CCD-4: Per-Epic Benchmark Gate (NFR5, NFR1, NFR2, NFR4, NFR6)

**Decision:** Each of Epics 9, 10, 11, 12, 13 includes a final "benchmarks + size delta" story that:
1. Runs the inherited Epic 7/8 performance benchmark suite on the epic's final commit
2. Records ROM size delta vs the epic's baseline
3. Records cycle-count delta for the words each epic touches most
4. Gates epic completion on the relevant NFR envelopes

**Rationale:** Performance NFRs are meaningful only if measured. Existing benchmark infrastructure makes this near-zero-cost per epic.

---

### Epic 9 — Numeric Literal Recogniser

#### E9-D1: Integration point

**Decision:** Extend the existing number-parse path inside the outer interpreter's unknown-token handler. When a token fails word-lookup, the recogniser peels a prefix (`#`, `$`, `%`, `0x`, `-#`, `-$`, `-%`, `-0x`, `'`) before falling through to the existing `<BASEnum>` path. No modification to `INTERPRET`, `NUMBER`, or `BASE` usage elsewhere.

**Rationale:** Zero impact on the unprefixed hot path (the 99th-percentile case); prefixed path adds ~20 cycles per NFR1. Self-contained change — all prefix logic lives in one new helper word.

#### E9-D2: Prefix dispatch strategy

**Decision:** Small dispatch table keyed on the first (or first two) characters of the token. The helper word accumulates digits into a working cell without mutating `BASE`; conversion uses a local base literal held in HL or a shadow register during the accumulation.

**Rationale:** Lookup is O(1) on the prefix set (5 prefixes + negation); no `BASE` mutation means no THROW-safety concerns during parsing.

---

### Epic 10 — Double-Cell & Pictured Output

#### E10-D1: Double-cell stack byte-order

**Decision:** **Low cell on top of stack, high cell below** (i.e., `2@` fetches low cell first into TOS, high cell becomes second-on-stack). This is the ANS Forth convention. `S>D` pushes high cell (zero or sign-extended) under the original single cell, which then becomes the low cell.

**Rationale:** Locked by the standard — the stack diagrams in ANS Forth 1994 §6.1.0350 (`2@`) and related specifications dictate this order. Any other choice breaks portability. Implementation cost is neutral either way.

#### E10-D2: Pictured-output buffer placement

**Decision:** A dedicated 40-byte buffer in the user area (IY-relative, addressed via a USER variable `HLD`). `<#` resets `HLD` to the buffer end; `#` decrements `HLD` and writes a digit; `#>` returns the accumulated string (c-addr u).

**Rationale:** 40 bytes comfortably holds the longest double-precision formatted output (20 digits decimal + sign + padding); USER-area placement means the buffer is per-task when multitasking lands (post-2.0) and doesn't collide with the PAD used by string words. IY-relative addressing is zero-cost on Z80.

#### E10-D3: Core gap word implementation approach

**Decision:** Implement Core gap words **in assembly** where the word is performance-critical (arithmetic primitives, stack ops) and **in Forth, compiled into the kernel image at build time** where the word is a thin wrapper or convenience (e.g., `D.R` on `D.` + `SPACES`). The kernel image includes a small pre-compiled Forth portion, as it does today for a handful of existing words.

**Rationale:** Balances ROM size (Forth-defined words are more compact in compiled colon form) against speed (assembly primitives are 3-10x faster for hot words). Existing Epic 1-8 convention; no new pattern needed.

---

### Epic 11 — Exception Subsystem

#### E11-D1: Exception frame layout

**Decision:** Eight-byte frame pushed on the IX return stack by `CATCH`, linked into the `CATCH-TOP` chain per CCD-1:

```
+6: previous CATCH-TOP   (chain link — value of CATCH-TOP just before CATCH entered)
+4: catching-IP          (where to resume after THROW)
+2: saved BC             (i*x's TOS-cell value at CATCH entry — captured
                          from BC immediately after CATCH's POP BC. Restored
                          to the data stack on THROW caught path so the
                          i*x cells underneath the catching frame are
                          preserved across xt's CALL/RET clobbering of
                          memory at [SP_safe-2]. Pre-Story-11.4.1 this slot
                          was named "saved IX" but was unused — see Story
                          11.4.1 root-cause analysis.)
+0: saved SP             (parameter stack pointer AFTER CATCH's POP BC —
                          i.e., one cell above the original i*x's TOS-cell
                          memory slot. Pre-Story-11.4.1 this was captured
                          BEFORE POP BC, leading to the bug that Story
                          11.4.1 fixes — see "i*x preservation under THROW"
                          note below E11-D2.)
```

CATCH's implementation:
1. Push 8-byte frame with `previous CATCH-TOP` = current value of `CATCH-TOP`; `catching-IP` = IP to resume at on THROW; `saved BC` = i*x's TOS-cell value (= BC immediately after POP BC); `saved SP` = current SP after POP BC (= SP_safe).
2. Set `CATCH-TOP` to the address of the frame just pushed.
3. Execute the caller-supplied XT.
4. On normal return: restore `CATCH-TOP` from the frame's prev-link, pop the frame, push `0`.

**Rationale:** 8 bytes is the minimum to support ANS semantics (SP restore, rstack restore, IP resume) plus the chain-link that makes CCD-1's dual-chain approach work. Total cycle cost for uncaught CATCH (frame push + update CATCH-TOP + execute + pop + restore CATCH-TOP): well within NFR4's per-epic budget. Story 11.4.1 added ~5 t-states to CATCH frame-push (SP_safe capture idiom less the saved-IX backfill removal) and ~50 t-states to the THROW caught path (the `LD C,(IX-6) / LD B,(IX-5) / PUSH BC` i\*x-restore sequence). The caught path is cold (only fires on errors), so the CATCH-side ~5 t-state delta is the only addition to the hot uncaught-CATCH cycle budget — still cycle-neutral within the NFR4 envelope.

#### E11-D2: CATCH/THROW mechanism

**Decision:** O(1) target-frame access via `CATCH-TOP`; cleanup via `INCLUDE-TOP` chain walk; no rstack scanning.

**THROW algorithm:**
1. Read `CATCH-TOP`. If zero: uncaught throw — display diagnostic (THROW code + standard message), reset REPL state.
2. While `INCLUDE-TOP` points to a frame at an rstack address above the target exception frame (i.e., more recent than the target): close the current `SOURCE-ID` (which is the FID of the current INCLUDE); restore input state from the INCLUDE frame (SOURCE-ID, input buffer, `>IN`); set `INCLUDE-TOP` to the frame's prev-link; pop the frame from the rstack.
3. Restore SP from the target exception frame's saved-SP slot (`LD SP, HL` where HL = saved-SP = SP_safe); push saved-BC from frame +2 onto the data stack (via `PUSH BC` after loading BC from the popped frame's +2 slot) to restore the i*x's TOS-cell that was captured at CATCH entry; then load BC = n (the THROW code).
4. Set `CATCH-TOP` to the target frame's previous-CATCH-TOP; pop the exception frame from the rstack.
5. Jump to the target frame's catching-IP — execution resumes inside the caller of the original CATCH with the THROW code on top of stack.

**Rationale:** Direct CATCH-TOP access avoids rstack scanning entirely. INCLUDE chain walk only touches frames that need cleanup (the ones more recent than the target). File handles close deterministically as their frames unwind — satisfies NFR9 (no orphaned FIDs after THROW). O(active-INCLUDE-nesting) cleanup work on THROW; paid only on error paths. Non-INCLUDE frames (colon returns, DO-LOOP frames) between the THROW site and the target catch frame are **not** explicitly popped here — they are abandoned as part of the SP/IX restore, which conceptually "snaps back" the return stack to the state it had at CATCH entry.

**i*x preservation under THROW (Story 11.4.1):** The frame's saved-SP is captured AFTER CATCH's POP BC (which consumes xt → HL and i*x's TOS → BC). The cell at the original (pre-POP-BC) `[SP]` held i*x's TOS at CATCH entry; xt's CALLs write at `[SP_safe - 2]` (= the original `[SP]`), clobbering the original i*x-TOS-cell memory. To preserve the value, frame +2 holds saved-BC = the i*x-TOS-cell value, captured from BC immediately after the POP. THROW's caught path: `LD SP, HL` (HL = saved-SP = SP_safe); `PUSH BC` (where BC has been reloaded with saved-BC from the popped frame's +2 slot via `LD C, (IX-6) / LD B, (IX-5)`); `LD BC, n`; `NEXT`. Result: BC = n (real TOS), `[SP]` = i*x's TOS-cell, `[SP+2]` = i*x's second-from-top, … `[SP+2*(K-1)]` = i*x's deepest, where K = the i*x cell count at CATCH entry. DEPTH = K + 1 = pre-CATCH-DEPTH (xt consumed, n on top instead).

#### E11-D3: Internal error migration strategy

**Decision:** **Phased, word-by-word, over the course of Epic 11.** Each primitive that currently emits an ABORT (stack underflow, division by zero, undefined-word lookup failure, compile-state violation, etc.) is migrated to THROW in a distinct commit with its own REPL-piped test. Order-independent — no single atomic "switch the error model" commit.

**Rationale:** Matches the memory entry on testing discipline (individual REPL tests per change). Regression-safer than a big-bang migration. `ABORT` / `ABORT"` are retargeted to `-1 THROW` / `-2 THROW` last, once all internal callers are migrated, so legacy ABORT-emitting paths don't double-throw during the transition.

---

### Epic 12 — Multi-Vocabulary

#### E12-D1: Per-wordlist hash table layout

**Decision:** Each wordlist is a 130-byte structure: a 2-byte "next-wordlist" chain pointer + a 64-entry × 2-byte hash-bucket array (each entry being a dictionary-head pointer or `$0000` for empty bucket). Identical bucket layout to today's single hash table — just instanced per wordlist.

**Rationale:** Preserves the established XOR-rotate 64-bucket scheme (memory entry on TOS-in-register & hash). 130 bytes per wordlist is a small cost; even 16 wordlists consume ~2 KB, well within the TPA budget. No re-engineering of the hashing primitive — just a pointer indirection to find the right bucket array.

#### E12-D2: Search-order storage

**Decision:** A fixed-size 16-slot array in the user area holding wordlist identifiers (= wordlist-struct addresses). A `SEARCH-ORDER-DEPTH` USER variable tracks active slots. `GET-ORDER` reads this array onto the parameter stack; `SET-ORDER` writes to it. Maximum search-order depth is therefore 16 (an antforth implementation limit — `FORTH-WORDLIST-LIST-MAX` per ANS terminology).

**Rationale:** 16 is generous (Gforth defaults to 8); fixed array avoids dynamic allocation. NFR2's 10% regression budget for multi-vocab lookup is tight but achievable with a straightforward outer loop over the search order calling the existing hash lookup.

#### E12-D3: Wordlist identifier representation

**Decision:** Wordlist identifiers are raw addresses of the 130-byte wordlist struct. `WORDLIST` creates a new struct by `ALLOT`-ing 130 bytes at `HERE`, initialising it, and returning the address.

**Rationale:** Zero-cost identifier — no translation table. Directly usable in `SEARCH-WORDLIST` as a pointer to the hash bucket array.

#### E12-D4: ~~ASSEMBLER wordlist auto-activation~~ — **WITHDRAWN 2026-04-27**

**Decision (superseded):** This decision proposed `CODE` pushing the current `SEARCH-ORDER-DEPTH` and activating an `ASSEMBLER` wordlist at the top of the search order, with `END-CODE` restoring it.

**Status:** Withdrawn 2026-04-27 per project-lead direction (sprint-change-proposal-2026-04-27.md). The 2026-04-20 ASSEMBLER.FTH rollback (which deleted `ASSEMBLER.FTH` and lazy-load) was extended on 2026-04-27 to also drop the ASSEMBLER wordlist itself and its auto-activation. The hard-coded assembler in `src/assembler.asm` stays as-is forever; opcode words remain in the global dictionary as they are today. The Story 10.7 asm-`#` dispatch hack (`project_asm_hash_dispatch_hack.md`) is permanent — no retirement vehicle planned. Story 11.5.5 (Epic 12 redraft, closed 2026-04-28) deleted the original Story 12.6 from `epics.md`. This decision record is preserved for historical reference; no Epic 12 implementation work depends on it.

---

### Epic 13 — File-Access

#### E13-D1: File-handle representation

**Decision:** A FID is the address of a 36-byte File Control Block (FCB) structure in an antforth-managed FCB pool. The pool holds **up to 8 FCBs**, implemented as a **kernel-resident static array** — a labelled byte region (`fcb_pool: ds 288`) in `src/file_access.asm`, linked into the `.COM` binary at build time, accessed by absolute address. `OPEN-FILE`/`CREATE-FILE` allocate from the pool; `CLOSE-FILE` releases. A pool-exhausted error throws `-69` (ANS "file access method" code).

**Rationale:** CP/M FCB is the native object the BDOS understands — using it as the FID avoids a translation layer. 8 FCBs is enough for realistic INCLUDE nesting (typically 1-3 deep) plus user-opened files. Kernel-resident placement (as opposed to user-area placement) is correct because the FCB pool is system-wide state (open files would survive task switches in a future multitasker); belongs with system data, not per-task USER area. Cost: 288 bytes (8 × 36) added to the `.COM` binary — negligible.

#### E13-D2: INCLUDE source-input nesting

**Decision:** `INCLUDE` pushes a **10-byte INCLUDE source frame** on the IX return stack, linked into the `INCLUDE-TOP` chain per CCD-1:

```
+8: previous INCLUDE-TOP     (chain link — value of INCLUDE-TOP just before INCLUDE entered)
+6: saved SOURCE-ID          (parent's source-id — 0 for keyboard, -1 for EVALUATE, or a FID if parent is itself an INCLUDE)
+4: saved input-buffer-addr  (parent's SOURCE buffer address)
+2: saved input-buffer-length (parent's SOURCE buffer length)
+0: saved >IN                (parent's parse offset)
```

INCLUDE's implementation:
1. `OPEN-FILE` the named file, receiving a new FID.
2. Push 10-byte frame with `previous INCLUDE-TOP` = current `INCLUDE-TOP`; saved fields = current input state (parent's SOURCE-ID, buffer addr/len, `>IN`).
3. Set `INCLUDE-TOP` to the new frame's address.
4. Set current `SOURCE-ID` to the new FID; re-point SOURCE to the first line read from the file; set `>IN` = 0.
5. Return control to the outer interpreter, which now parses from the new source.

On EOF (normal completion):
- Close the current SOURCE-ID (the FID being read).
- Restore parent input state from the frame (SOURCE-ID, buffer, `>IN`).
- Set `INCLUDE-TOP` to the frame's prev-link.
- Pop the 10-byte frame from the rstack.
- Outer interpreter resumes parsing the parent source.

On THROW: handled by the unwind in E11-D2 (walks `INCLUDE-TOP` chain, closing each FID in turn).

**Rationale:** Fixed 10-byte layout resolves the "variable size" ambiguity of the earlier draft. Chain-based discipline per CCD-1 means EOF and THROW share the same frame-pop primitive. Using `SOURCE-ID` as the FID-to-close (rather than storing the FID redundantly in the frame) saves 2 bytes per frame and keeps a single source of truth.

#### E13-D3: BDOS wrapper abstraction level

**Decision:** A small private layer in the kernel wraps the BDOS functions needed by File-Access, exposing byte-oriented read/write over CP/M's 128-byte record model. File-Access primitives call the wrapper layer, not BDOS directly. `READ-FILE` / `WRITE-FILE` handle the record-to-byte impedance with an in-FCB read-buffer.

**Rationale:** Hides the 128-byte record awkwardness from Forth code; single place to update if the BDOS call conventions ever need to change. Minimal layer — not full abstraction, just impedance matching.

---

### Decision Impact Analysis

**Implementation sequence (locked by dependencies):**

1. **Epic 9 first** — numeric prefixes; zero dependencies on other decisions
2. **Epic 10 second** — double-cell + pictured output; needed by several Core gap words and by later test scripts
3. **Epic 11 third** — CATCH/THROW; exception frames land; internal errors migrate; preq for Epic 13 error paths
4. **Epic 12 fourth** — multi-vocabulary Search-Order wordset only; existing kernel opcode words stay in the global dictionary (no ASSEMBLER wordlist; per 2026-04-27 direction)
5. **Epic 13 last** — File-Access on top of the new exception system

**Cross-component dependencies:**

- CCD-1 (return-stack frame taxonomy) is prerequisite to E11-D1, E13-D2. Write it into the architecture doc before Epic 11 starts, not discovered mid-sprint.
- E11-D1 (exception frame) must be defined before E13-D2 (INCLUDE source frame) — so THROW unwind logic knows how to skip over source frames.

## Implementation Patterns & Consistency Rules

These rules ensure that successive dev-agent invocations (across stories within an epic, across epics, and across Ant working alone) produce compatible, consistently-styled code. Many of these are formalisations of conventions already in project memory; a few are new for this phase.

### Conflict Points Identified

The potential sources of cross-invocation divergence in an antforth epic are:

1. **Word-definition style** — macro (`DEFCODE`/`DEFWORD`) vs. raw assembly with manual dictionary-header construction
2. **Code-field addressing** — where the code-field pointer for a DEFWORD points
3. **Standards citation comments** — presence, format, and accuracy
4. **Error-raising mechanism** — `ABORT` vs `THROW` (phase 2 tightens this)
5. **Test placement and style** — REPL-piped Forth vs assembly test-thread extensions
6. **Source file organisation** — which file a new word's implementation lives in
7. **TOS-in-register discipline** — BC as TOS contract; DEPTH calculation; ABORT-recovery semantics
8. **Shadow-register (EXX) usage** — when to swap, what's preserved
9. **Assembler operand order** — Zilog dst-src convention for inline CODE words
10. **Label conventions in CODE words** — explicit `LABEL`/`FIX` vs sigil-based

### Naming & Structure Patterns

#### Forth word naming

- **Standard-defined words** use their exact ANS/Forth-2014 spelling, case-insensitive in source (upper by convention): `CATCH`, `THROW`, `INCLUDED`, `WORDLIST`
- **antforth-extension words** carry no special prefix but are clearly flagged in their source comment as extensions: `; antforth extension   0x     — C-style hex prefix`
- **Internal helper words** (not user-facing) use a `(paren)` convention per Forth tradition: `(CATCH-FRAME-POP)`, `(INCLUDE-FRAME-POP)`
- **USER variables** use UPPER-CASE with hyphens: `SEARCH-ORDER-DEPTH`, `HLD`, `CATCH-TOP`, `INCLUDE-TOP`

#### Assembly label naming

- **Word implementations** use `w_` prefix followed by the lowercased word name with underscores replacing non-identifier characters: `w_catch`, `w_throw`, `w_search_wordlist`
- **Code field labels** (for DEFWORDs) use `w_XXX_cf`, computed via `EQU body - 3` to point at the `JP DOCOL` (**per project memory: `feedback_defword_cf_label.md`**)
- **Internal subroutines** (not dictionary entries) use descriptive snake_case: `find_catch_frame`, `cpm_bdos`
- **Constants / EQU** use UPPER_SNAKE_CASE: `FCB_SIZE EQU 36`, `WORDLIST_SIZE EQU 130`, `THROW_STACK_UNDERFLOW EQU -4`

#### Source file organisation

New phase-2 code goes into dedicated source files matching its epic:

| File | Epic | Contents |
|---|---|---|
| `src/number_prefixes.asm` | 9 | Numeric-literal recogniser extension, prefix-dispatch helper |
| `src/double.asm` | 10 | Double-precision primitives (`D+`, `M*`, `UM/MOD`, `2@`, `2!`, etc.) |
| `src/pictured.asm` | 10 | Pictured numeric output (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`) |
| `src/exception.asm` | 11 | `CATCH`, `THROW`, exception-frame management |
| `src/wordlists.asm` | 12 | Multi-vocabulary Search-Order, `WORDLIST`, `SET-ORDER`, etc. |
| `src/file_access.asm` | 13 | File-Access wordset, FCB pool, INCLUDE, BDOS file wrapper |

Existing source files (`outer_interpreter.asm`, `assembler.asm`, `dictionary.asm`, etc.) are edited in-place when the change is a modification rather than a new subsystem — e.g., migrating `ABORT` paths to `THROW` in Epic 11 touches every existing `.asm` file.

### Format Patterns

#### Standards-citation comments (NFR18)

Every word whose behaviour derives from a specification carries a standards-citation comment at its implementation site. Format:

```
; ANS Forth 1994 §<section>  <word>       — <brief semantic note>
; Forth 2014 §<section>      <word>       — <brief semantic note>
; antforth extension          <word>       — <design reason>
```

Bad:
```
; CATCH — handles exceptions
```

Good:
```
; Forth 2014 §9.6.1.0875   CATCH          — execute xt with exception frame
```

#### THROW codes

Every THROW code used in phase-2 source cites its definition inline. Standard codes reference the ANS table; antforth-extension codes reference the allocation table in `docs/throw-codes.md` (to be created in Epic 11 first story):

```
THROW_UNDEFINED_WORD   EQU -13  ; ANS Forth 1994 §9.3.5
THROW_FCB_EXHAUSTED    EQU -69  ; ANS Forth 1994 §9.3.5
THROW_ASM_LOAD_FAIL    EQU -257 ; antforth extension — see docs/throw-codes.md
```

#### Stack effect comments

Every word — standard or new — carries a stack-effect comment on the line of its `DEFCODE`/`DEFWORD` macro, using Forth's `( inputs -- outputs )` notation:

```
DEFCODE "CATCH", 5, 0, w_catch     ; ( xt -- exception-code | 0 )
DEFCODE "WORDLIST", 8, 0, w_wordlist  ; ( -- wid )
```

### Communication Patterns (inter-word contracts)

#### TOS-in-register discipline (inherited, unchanged)

Per project memory `project_tos_in_register.md`:

- **BC holds TOS when stack depth ≥ 1.** SP-based parameter stack holds second-on-stack and below.
- **BC may be "phantom" after ABORT/THROW — check DEPTH first.** `DEPTH = (sp_base - SP) / 2` counts SP cells only, not BC. `DEPTH = 0` means BC is invalid and must not be used.
- **On entry to a primitive, assume BC is valid iff DEPTH ≥ 1.**

#### Shadow-register usage (inherited, unchanged)

Per project memory on EXX convention and `docs/register-conventions.md`:

- `EXX` swap is permitted within a word to gain temporary registers
- Shadow state must be restored before `NEXT` or any transfer out
- Words that hold shadow-set data across calls must be documented
- No word may leave the shadow set in an inconsistent state for the next word

#### Assembler operand order (inherited, unchanged)

Per project memory `feedback_assembler_operand_order.md`:

- Inline Z80 assembler in `CODE` blocks uses **Zilog dst-src order**: `B C LD,` means `LD B, C`
- Kernel-side Z80 assembly uses the cross-assembler's convention (which is also Zilog dst-src)
- Consistent direction across both layers; no reversal at the language boundary

#### Assembler label conventions (inherited, unchanged)

Per project memory `feedback_assembler_label_design.md`:

- Labels in CODE words are declared with explicit `LABEL name` and resolved with `name FIX`
- No INTERPRET hooks, no sigil syntax
- Labels are block-scoped to the enclosing `CODE`/`END-CODE`

### Process Patterns

#### Error raising (phase 2 tightens this)

- **All new error sites in phase 2 code raise via `THROW`, not `ABORT`.**
- **Existing `ABORT` call sites migrate to `THROW` during Epic 11** (one per commit, each with its own REPL-piped test, per decision E11-D3).
- **`ABORT` and `ABORT"`** become wrappers for `-1 THROW` and `-2 THROW` respectively, once all internal callers have migrated.
- **Never both** — a word does not raise ABORT in one path and THROW in another.

#### Test placement (inherited, phase 2 reaffirms)

Per project memory `feedback_repl_tests_preferred.md`:

- **New tests are REPL-piped Forth scripts.** No new assembly test-thread extensions in phase 2.
- Tests live alongside their epic's source or in `test/repl/` under a filename matching the word or capability under test
- Tests must be runnable via the standard pipe-into-antforth mechanism
- Manual tests must exercise actual Forth primitives, not raw BDOS (per `feedback_testing_rules.md`)

#### Standards-compliance discipline (inherited, reaffirmed)

Per project memory `feedback_standards_compliance.md`:

- **Investigate the standard before defending existing code.** When the project lead flags a discrepancy with ANS Forth 1994 or Forth 2014, the default response is to check the spec, not to argue for current behaviour.
- **Never rationalise divergence silently.** An antforth extension is documented as such (CCD-3); undocumented divergence from the standard is a bug.

#### Adversarial review (inherited, reaffirmed)

Per project memory `feedback_adversarial_review.md`:

- **Reviews MUST find things.** A review that surfaces zero findings is itself suspect — either the review was shallow or the change is too big to have been clean.
- Apply especially to Epic 11 (exception migration) and Epic 13 (capstone) — both touch enough of the system that clean reviews are unlikely.

### Enforcement Guidelines

**All dev-agent (or author) invocations MUST:**

1. Place new words in the epic-appropriate source file per the table above
2. Include a standards-citation comment for every standard-derived word
3. Include a stack-effect comment on every DEFCODE/DEFWORD line
4. Use `THROW` (not `ABORT`) for new error sites, and migrate existing ABORT sites per Epic 11's migration list
5. Write REPL-piped Forth tests for every new word before marking a task complete
6. Preserve BC-as-TOS discipline and DEPTH-based validity check
7. Preserve Zilog dst-src operand order
8. Cite any behaviour divergence from the standard as an explicit antforth extension with rationale

**Pattern enforcement:**

- Epic-level benchmark gate (CCD-4) catches performance regressions
- Epic 1–8 regression test suite (NFR10) catches behavioural regressions
- Adversarial review on every epic (per `feedback_adversarial_review.md`) catches pattern drift
- Source-file layout is enforced by code review; pattern violations are rejected during adversarial review, not merged

### Concrete Examples

**Good — new CATCH word:**

```
; Forth 2014 §9.6.1.0875   CATCH          — execute xt with exception frame
DEFCODE "CATCH", 5, 0, w_catch    ; ( xt -- exception-code | 0 )
w_catch:
    ; push 8-byte exception frame per CCD-1 / E11-D1
    ; (post-Story-11.4.1: +0 saved-SP_safe, +2 saved-BC, +4 catching-IP, +6 prev-CATCH-TOP)
    ...
    JP NEXT
```

**Bad — same word, violating conventions:**

```
; handle exceptions for user code
defcode "Catch", 5, 0, catch_impl   ; no stack effect comment, mixed case, no spec cite
catch_impl:
    ; old-style ABORT path as fallback    ← forbidden in phase 2
    ...
    JP ABORT
    JP NEXT
```

**Good — new THROW code allocation:**

```
; antforth extension — see docs/throw-codes.md
THROW_ASM_LOAD_FAIL    EQU -257
```

**Bad — THROW code collision:**

```
THROW_ASM_LOAD_FAIL    EQU -13    ; ← collides with ANS undefined-word!
```

## Project Structure & Boundaries

### Complete Project Directory Structure

Existing layout preserved; phase-2 additions annotated with **[new]** or **[edit]**.

```
antforth/
├── README.md
├── LICENSE
├── Makefile                          # build entry points (cross-assemble, emulate, real-hw copy)
├── Dockerfile                        # reproducible build environment (optional)
├── yarn.lock                         # for BMAD node tooling only
├── _bmad/                            # BMAD agent framework (don't modify)
├── _bmad-output/
│   └── planning-artifacts/
│       ├── prd.md                    # current-phase PRD (2026-04-14)
│       ├── prd-phase1-epics-1-8.md   # archived
│       ├── architecture.md           # THIS DOCUMENT
│       ├── architecture-phase1-epics-1-8.md  # archived
│       ├── epics.md                  # [edit] adds Epics 9-13
│       ├── product-brief-antforth-2026-04-14.md
│       ├── product-brief-antforth-2026-03-11.md  # archived
│       ├── epic6-code-size-optimization.md
│       ├── epic7-shadow-register-optimization.md
│       ├── epic8-shadow-register-followup.md
│       ├── sprint-change-proposal-2026-04-12.md
│       └── implementation-readiness-report-2026-03-12.md
│                                       # [new] future: implementation-readiness-2026-04-xx.md
│                                       # [new] future: epic9/10/11/12/13 detail docs (as needed)
├── _bmad-output/
│   └── implementation-artifacts/
│       ├── sprint-status.yaml         # [edit] adds 9-0, 9-1, ... 13-N entries
│       └── {epic-number}-{story-slug}.md  # [new] one per story as they are authored
├── docs/
│   ├── ans-forth-core-compliance.md   # [edit] revise toward 100% as Epic 10 progresses
│   ├── z80_forth_assemblers.md
│   ├── z80-instruction-coverage.md
│   ├── z80-instruction-coverage-reaudit.md
│   ├── register-conventions.md        # [edit] document Epic 11 exception-frame usage
│   ├── shadow-register-survey.md
│   ├── shadow-register-followup-survey.md
│   ├── WISHLIST.md                    # [edit] add deferred phase-2 discoveries
│   └── throw-codes.md                 # [new] Epic 11 — ANS + antforth THROW code table
├── src/                               # kernel source (Z80 assembly)
│   ├── antforth.asm                   # top-level kernel entry / banner
│   ├── arithmetic.asm                 # [edit] Epic 10 — migrate error paths to THROW
│   ├── assembler.asm                  # unchanged in Phase 2 (no ASSEMBLER wordlist, no auto-activation; hard-coded as-is per 2026-04-27)
│   ├── bootstrap.asm                  # kernel init, initial dictionary setup
│   ├── compiler.asm                   # [edit] Epic 11 — migrate compile-error ABORT to THROW
│   ├── constants.asm                  # [edit] Epic 11 — add ANS THROW code EQUs
│   ├── control_flow.asm
│   ├── dictionary.asm                 # [edit] Epic 12 — generalise to multi-vocabulary
│   ├── formatting.asm                 # [edit] Epic 10 — pictured output words moved out (see pictured.asm)
│   ├── hash.asm                       # [edit] Epic 12 — parameterise on wordlist-struct address
│   ├── inner_interpreter.asm
│   ├── io.asm                         # [edit] Epic 13 — factor BDOS helpers; separate file I/O wrapper
│   ├── logic.asm
│   ├── macros.asm                     # [edit] add macros for standards-citation, exception frame
│   ├── memory.asm
│   ├── outer_interpreter.asm          # [edit] Epic 9 — wire numeric-prefix recogniser; Epic 11 — REPL-level THROW handler
│   ├── stack_ops.asm                  # [edit] Epic 10 — 2DUP/2DROP/2SWAP/2OVER added; Epic 11 — underflow paths to THROW
│   ├── strings.asm
│   ├── structures.asm
│   ├── system.asm                     # [edit] Epic 11 — retarget ABORT, ABORT" to THROW wrappers
│   ├── test_key.asm                   # existing test harness plumbing (no change)
│   │
│   │   # --- [new] phase-2 additions ---
│   ├── number_prefixes.asm            # [new] Epic 9 — numeric literal recogniser (# $ % 0x 'c')
│   ├── double.asm                     # [new] Epic 10 — double-precision primitives
│   ├── pictured.asm                   # [new] Epic 10 — <# # #S #> HOLD SIGN HOLDS
│   ├── exception.asm                  # [new] Epic 11 — CATCH, THROW, exception-frame mgmt
│   ├── wordlists.asm                  # [new] Epic 12 — WORDLIST, SET-ORDER, DEFINITIONS, etc.
│   ├── file_access.asm                # [new] Epic 13 — OPEN-FILE, READ-FILE, INCLUDE, FCB pool, BDOS file wrapper
│   │
│   └── tests/                         # legacy assembly test threads (pre-Epic 3)
│       ├── test_arithmetic.asm
│       ├── test_dictionary.asm
│       ├── test_inner.asm
│       ├── test_io.asm
│       ├── test_outer.asm
│       └── test_stack.asm
│                                       # NO new assembly tests in phase 2 (per memory rule)
├── tests/                             # REPL-piped Forth test scripts (Epic 3+ convention)
│   ├── core_tests.fth                 # existing core-word tests
│   │                                   # [new] phase-2 tests:
│   ├── number_prefixes_tests.fth      # [new] Epic 9
│   ├── double_tests.fth               # [new] Epic 10
│   ├── pictured_tests.fth             # [new] Epic 10
│   ├── core_gap_tests.fth             # [new] Epic 10 (covers remaining Core words driven to 100%)
│   ├── exception_tests.fth            # [new] Epic 11
│   ├── throw_migration_tests.fth      # [new] Epic 11 (per-migrated-primitive REPL tests)
│   ├── wordlist_tests.fth             # [new] Epic 12
│   # (assembler_wordlist_tests.fth — withdrawn 2026-04-27; no ASSEMBLER wordlist to test)
│   └── file_access_tests.fth          # [new] Epic 13
├── examples/                          # demo source files, user-facing
│   ├── extended-asm-demo.fth          # existing
│   └── extended-asm-demo-annotated.fth
├── disk/                              # CP/M disk images for emulation/release
├── build/                             # build artefacts (gitignored)
├── blog/                              # project blog / devlog
├── images/                            # design docs images
└── node_modules/                      # BMAD tooling only
```

### Architectural Boundaries

antforth has no network, no API, no frontend/backend split, no database. The meaningful boundaries are **memory regions** and **source-file responsibilities** within a single Z80 `.COM` binary.

#### Memory-region boundaries (runtime)

```
0000h ──────────── CP/M zero page (BDOS call area)
0100h ──────────── [ANTFORTH.COM load point]
                   Kernel code (Z80 assembly)
                     inner interpreter, primitives, outer interpreter,
                     exception subsystem, file-access subsystem, etc.
                   ↓ grows upward
<kernel-end>
                   Dictionary header area (built at boot from kernel symbols)
                   Compiled Forth portion (e.g. `D.R` colon defs)
                   ↓ continues upward
HERE  ──────────── User definitions grow upward from here
                   ↓
                   Parameter stack grows downward
                   ↑
SP  ─────────────
                   Return stack grows downward (at IX)
                   ↑
IX  ─────────────
                   User area (USER variables including HLD, SEARCH-ORDER, CATCH-TOP, INCLUDE-TOP)
FFFFh ──────────── Top of memory minus BDOS
```

**Boundary rules:**

- Kernel code is read-only at runtime (no self-modifying code; a rule since Epic 1)
- Dictionary grows **only upward** via `HERE` / `ALLOT` / `,` / `C,` — no gap reuse
- Parameter stack and return stack grow **downward** toward each other (collision = stack overflow, detected lazily as an invariant violation → THROW)
- User area is fixed-size and fixed-location; additions this phase (HLD, SEARCH-ORDER array, CATCH-TOP, INCLUDE-TOP) require recompile but don't move existing offsets. (FCB pool sits in early TPA above the kernel, not in USER area — see E13-D1.)

#### Source-file responsibility boundaries

Each `src/*.asm` file owns a coherent subsystem. Boundary rules:

- **A new word's implementation lives in exactly one source file** (the one matching its capability area per the table in Implementation Patterns)
- **Cross-file references are one-way where possible** — e.g., `exception.asm` is referenced by everyone (because everyone throws), but `exception.asm` only references `inner_interpreter.asm` primitives (`NEXT`, register conventions)
- **No circular references** — if A needs B and B needs A, one of them needs a new helper in a shared lower layer (usually `macros.asm` or `bootstrap.asm`)
- **`macros.asm` is the only file that may be `INCLUDE`d** by others — it defines assembler macros (`DEFCODE`, `DEFWORD`, `;WORD`, etc.)

### Requirements-to-Structure Mapping

**Epic-to-file mapping (phase-2 additions):**

| Epic | New files | Modified files |
|---|---|---|
| Epic 9 | `src/number_prefixes.asm`; `tests/number_prefixes_tests.fth` | `src/outer_interpreter.asm` (wire recogniser) |
| Epic 10 | `src/double.asm`, `src/pictured.asm`; `tests/{double,pictured,core_gap}_tests.fth` | `src/stack_ops.asm` (2DUP etc.); `src/formatting.asm` (migrate `.`/`U.` onto pictured); `src/arithmetic.asm` (possible M*/UM* shared code); `docs/ans-forth-core-compliance.md` |
| Epic 11 | `src/exception.asm`; `docs/throw-codes.md`; `tests/{exception,throw_migration}_tests.fth` | `src/constants.asm` (THROW code EQUs); `src/system.asm` (ABORT retarget); **every other `*.asm` with ABORT paths** (phased migration per E11-D3) |
| Epic 12 | `src/wordlists.asm`; `tests/wordlist_tests.fth` | `src/dictionary.asm` (multi-vocab); `src/hash.asm` (per-wordlist bucket array). `src/assembler.asm` is **unchanged** in Phase 2 per 2026-04-27 — no ASSEMBLER wordlist, no auto-activation hooks, no opcode migration. |
| Epic 13 | `src/file_access.asm`; `tests/file_access_tests.fth` | `src/io.asm` (factor BDOS helpers) |

**Cross-cutting concerns (not epic-specific):**

- **Standards-citation comments:** every file gains citations on words it owns (NFR18); no single point of change
- **Benchmark gates:** each epic's final story consults `src/tests/` benchmark thread outputs (test harness unchanged — still assembly-level for benchmarks specifically)
- **`_bmad-output/implementation-artifacts/sprint-status.yaml`:** single source of truth for which stories are in flight / done; edited by Bob (SM) at story transitions

### Integration Points

#### Internal communication (between subsystems)

- **Word-to-word calls** use the standard Forth threading mechanism (`NEXT`, register conventions); no function-call ABI between subsystems beyond this
- **Exception propagation** uses `THROW` — crosses every subsystem boundary naturally; THROW unwind walks the IX return stack, blind to subsystem origin
- **Dictionary lookup** is parameterised on a wordlist-struct address (Epic 12); callers pass the struct, `dictionary.asm` does the hash and linked-list walk

#### External integrations

- **CP/M 2.2 BDOS** is the only external integration. `src/io.asm` (console I/O) and `src/file_access.asm` (file I/O) are the gatekeepers; no other file calls BDOS directly
- **MicroBeast hardware** (14-segment displays, I/O ports) — **no direct integration in phase 2**; reserved for post-2.0 hardware-vocabulary epic
- **Cross-assembler toolchain** — invoked by `Makefile`; out of architectural scope for this phase

### File Organisation Patterns

(Already specified in Implementation Patterns section; not repeated here. See "Source file organisation" subsection.)

### Development Workflow Integration

- **Build:** `make` — cross-assembles `src/*.asm` into `build/ANTFORTH.COM` plus an emulation-ready disk image containing `ANTFORTH.COM`
- **Test (REPL):** `make test` — pipes `tests/*.fth` into the emulated antforth, captures output, compares against expected
- **Test (bench, legacy):** `make bench` — runs assembly test threads (Epic 7/8 benchmark suite); phase 2 adds no new assembly tests but consumes the outputs for CCD-4 size/cycle gates
- **Real-hardware validation:** each epic's final story copies `build/ANTFORTH.COM` to the MicroBeast via the project's usual transfer mechanism and runs a smoke test. No release tag without this pass (per MVP rule in PRD)
- **Development:** Ant edits `src/*.asm` and `tests/*.fth` files; `make` rebuilds; `make test` runs REPL tests; iteration is fast on the emulator, final validation happens on real hardware

## Architecture Validation Results

### Coherence Validation

**Decisions internally consistent:** All cross-decision dependencies identified in "Decision Impact Analysis" (§ Core Architectural Decisions) sequence cleanly — CCD-1 before Epic 11, E11-D1 before E13-D2, etc. No contradictions found between decisions themselves.

**Patterns support decisions:** The Implementation Patterns section's source-file layout matches the Epic-to-file mapping in Project Structure. Naming conventions (w_ prefix for word implementations, UPPER-CASE-HYPHEN for USER variables) consistent across every decision that named a concrete artefact. Standards-citation discipline is specified at both the pattern level (format template) and enforced at the decision level (CCD-3, NFR18).

**Structure supports architecture:** The six new source files (number_prefixes / double / pictured / exception / wordlists / file_access) each correspond exactly to one or two decisions; no decision lacks a home, no file is orphaned.

### Requirements Coverage Validation

**All 47 FRs traced to architectural support:** spot-checked the critical cases:

- FR9 (BASE unchanged by parsing) → E9-D2 explicitly forbids BASE mutation
- FR22 (REPL survives THROW) → E11-D2 + NFR6
- FR31 (pre-phase CODE files assemble unchanged) → E12-D4 save/restore; Implementation Patterns #8
- FR43 (file-I/O errors raise THROW not ABORT) → E13-D3 + error-raising process pattern
- FR45–47 (backward compat) → NFR9 gate + E9-D1 preserving unprefixed path

**All 21 NFRs addressed.** NFR1/2/3/5 performance envelopes → CCD-4 benchmark gate. NFR4 ROM size → CCD-4 per-epic delta tracking (no net-negative gate). NFR6–9 reliability → E11-D1/D2 + regression gate. NFR10–14 standards → CCD-3 + E10-D1 + NFR13 BDOS allow-list. NFR15–18 maintainability → Implementation Patterns. NFR19–21 integration → Project Structure memory-region boundaries + BDOS gatekeepers.

### Findings (genuine issues requiring resolution)

#### Finding 1 — Frame-type disambiguation is under-specified (CCD-1, E11-D2, E13-D2)

**Issue:** CCD-1 claims exception and INCLUDE source frames are disambiguable via "the saved SP field of an exception frame is always non-zero and points into the parameter stack region." This is true for exception frames, but the THROW unwinder also needs to recognise and correctly handle (i.e., pop and close associated FIDs) any INCLUDE source frames it encounters during unwind. The current text says INCLUDE frames are "variable size"; without a known size or tag, the unwinder can't know where one frame ends and the next begins.

**Impact:** Epic 13's E13-D2 (INCLUDE nesting + THROW cleanup) is blocked by this ambiguity. A dev agent implementing `THROW` unwind would either (a) get it wrong, or (b) have to invent a tagging scheme on the fly — drift from the architecture.

**Resolution:** Specify the INCLUDE source frame as a fixed-layout 8-byte frame: `[saved source-id : 2 bytes][saved >IN : 2 bytes][saved input-buffer-addr : 2 bytes][saved input-buffer-length : 2 bytes]`. The frame size is constant, so THROW unwind can walk by fixed offsets. Discrimination: saved SP (exception frame, offset 0) ≠ saved source-id of any active INCLUDE (those are FIDs = FCB-pool addresses, a disjoint value range). **Action: revise CCD-1 / E13-D2 with these specifics when this architecture is next edited.**

#### Finding 2 — FCB-pool location is TBD (E13-D1)

**Issue:** E13-D1 says "8 FCBs (fixed, in user area or early TPA)." Either choice has implications:
- **User area** — fits naturally with existing USER variable placement; ~288 bytes of USER area consumed; IY-relative addressing already available
- **Early TPA** — outside USER area, reachable via absolute addressing; frees USER area for post-2.0 multitasker (each task needs its own USER area, but shared FCB pool makes sense as a system resource)

**Impact:** Epic 13 dev work starts by picking one; without architectural decision, picked arbitrarily.

**Resolution:** Locate the FCB pool in **early TPA, just above the kernel**, accessed by absolute address. Rationale: FCB pool is system-wide (open files survive task switches in a future multitasker); it belongs with system state, not per-task USER area. Small concrete cost: one additional fixed-address symbol in `constants.asm`. **Action: lock this in when revising the architecture.**

#### Finding 4 — Phase-1 architecture reference is implicit, not explicit

**Issue:** This architecture document describes phase-2 additions and changes, but **does not duplicate the foundational design from phase 1** (inner interpreter details, DOCOL/EXIT semantics, hash algorithm specifics, CREATE/DOES> machinery, MARKER implementation). A dev agent reading only this document would be missing canonical descriptions of the layers their code must integrate with.

**Impact:** Dev-agent invocations during Epic 10 or Epic 11 might reinvent or misinterpret existing semantics.

**Resolution:** Add an explicit cross-reference at the top of the Core Architectural Decisions section: **"The phase-1 architecture document (`architecture-phase1-epics-1-8.md`) is the canonical reference for all inherited subsystems (inner interpreter, existing dictionary, CREATE/DOES>, MARKER, optimisation framework, existing assembler opcode implementation). This document specifies only the additions and changes for phase 2."** **Action: add this note when revising the architecture.**

### Gap Analysis

**Critical gaps (must resolve before Epic 11 / 13 implementation starts):**
- Finding 1: INCLUDE source frame layout — must be locked before Epic 11 THROW unwind or Epic 13 INCLUDE nesting is implemented

**Important gaps (resolve before or during Epic 13):**
- Finding 2: FCB pool location — lockable now, preferably before Epic 13 starts

**Nice-to-have (improves dev-agent experience):**
- Finding 4: Explicit phase-1 architecture cross-reference

### Architecture Completeness Checklist

**Requirements Analysis**

- [x] Project context thoroughly analysed
- [x] Scale and complexity assessed (5 new subsystems, brownfield additive)
- [x] Technical constraints identified (inherited + new BDOS 25 + file-access BDOS set)
- [x] Cross-cutting concerns mapped (6 cross-cutting concerns; 4 resolved to CCDs)

**Architectural Decisions**

- [x] Critical decisions documented with rationale — **pending Findings 1 and 2 resolution**
- [x] Phase-2 new-subsystem decisions specified (CCDs 1–4; E9 through E13 decision sets)
- [x] Performance considerations addressed (CCD-4 benchmark gate; NFR1/2/3/4/5 mapped to decisions)
- [x] Standards citations specified (CCD-3 format; NFR18 coverage)

**Implementation Patterns**

- [x] Naming conventions established (Forth words, assembly labels, USER variables, constants)
- [x] Structure patterns defined (epic-to-file mapping)
- [x] Communication patterns specified (THROW propagation, dictionary parameterisation on wordlist)
- [x] Process patterns documented (error raising, test placement, adversarial review)

**Project Structure**

- [x] Complete directory structure defined with [new]/[edit] annotations
- [x] Component boundaries established (memory-region boundaries; source-file responsibility boundaries)
- [x] Integration points mapped (BDOS gatekeepers)
- [x] Requirements-to-structure mapping complete (Epic-to-file table)

**Findings**

- [x] **Finding 1 resolved** — CCD-1 rewritten with dual LIFO chains (`CATCH-TOP`, `INCLUDE-TOP`); E11-D1 exception frame expanded to 8 bytes with prev-link; E11-D2 CATCH/THROW mechanism rewritten as O(1) `CATCH-TOP` access + `INCLUDE-TOP` chain walk for cleanup; E13-D2 INCLUDE source frame specified as fixed-layout 10 bytes with prev-link (see updated decisions above).
- [x] **Finding 2 resolved** — E13-D1 FCB pool placed as kernel-resident static array (`fcb_pool:` in `src/file_access.asm`, absolute addressing, 288 bytes linked into `.COM`).
- [x] **Finding 3 superseded** — The ASSEMBLER.FTH lazy-load was removed from scope on 2026-04-20 (see `sprint-change-proposal-2026-04-20.md`); the built-in assembler is retained in kernel. The size-budget concern no longer applies.
- [x] **Finding 4 resolved** — Explicit cross-reference to `architecture-phase1-epics-1-8.md` added at top of Core Architectural Decisions.

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION — all four findings resolved or superseded.

**Confidence level:** **High.** The four findings surfaced by adversarial review have been resolved inline (see decisions CCD-1, E11-D1, E11-D2, E13-D1, E13-D2 for Findings 1 and 2; the cross-reference note at the top of Core Architectural Decisions for Finding 4; Finding 3 superseded by the 2026-04-20 removal of the lazy-load capstone). Architecture is now self-consistent and ready to drive epic breakdown.

**Key strengths:**

- Every FR and NFR traces to a named architectural decision
- Epic sequencing is locked by concrete dependencies, not just preference
- Conventions are grounded in existing project memory, not invented
- Standards-citation discipline enables future ANS re-audits without archaeology
- Adversarial review caught four real issues (consistent with the memory rule that reviews must find things)

**Areas for future enhancement:**

- The FCB pool size (8) has no empirical basis — post-2.0 usage will either validate or force a revisit
- Dictionary layout change (Epic 12) has implications for any future on-device image-save mechanism; specifying a saved-image format is post-2.0 work
- Second-platform portability (e.g., a generic Z80-CP/M build rather than MicroBeast-specific) would benefit from explicit platform-abstraction layer; currently implicit in BDOS gatekeeper discipline

### Implementation Handoff

**AI agent (and human author) guidelines:**

- Treat `architecture-phase1-epics-1-8.md` as canonical for all inherited subsystems (Finding 4)
- Treat this document as canonical for all phase-2 additions and changes
- Start every story by citing which architectural decisions it implements (by CCD-* or En-Dn identifier)
- Before coding, resolve the four Findings above if they haven't been resolved in a follow-up architecture pass
- Follow Implementation Patterns exactly — variance is rejected in adversarial review, not merged

**First implementation priority:**

1. **Findings 1–4 resolved** (inline in the decisions above, 2026-04-14 revision pass) — no further architecture work needed before Epic 9 can start.
2. **Epic 9** — first story: wire the numeric-prefix recogniser helper into `src/outer_interpreter.asm` per E9-D1/D2.
3. Continue through Epics 10, 11, 12, 13 in the locked sequence from "Decision Impact Analysis".
