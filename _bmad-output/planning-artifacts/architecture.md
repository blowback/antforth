---
stepsCompleted: []
lastStep: 0
status: 'in-progress for Phase 4'
completedAt: null
lastEdited: '2026-05-10'
editHistory:
  - date: '2026-05-10'
    changes: 'Phase-4 refill — banking scope per docs/antforth-banking-redesign.md'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - _bmad-output/planning-artifacts/architecture-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/prd-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md
  - _bmad-output/planning-artifacts/prd-phase3-epics-14-15.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md
  - docs/PHASE-3-CARRY-FORWARD.md
  - docs/antforth-banking-redesign.md
  - docs/WISHLIST.md
  - docs/ans-forth-core-compliance.md
  - docs/register-conventions.md
  - docs/throw-codes.md
workflowType: 'architecture'
project_name: 'antforth'
user_name: 'Ant'
date: '2026-05-10'
phase: 4
phaseScope: 'Phase 4 — banked-RAM enablement (per docs/antforth-banking-redesign.md)'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The 2026-05-10 Phase-4 PRD specifies **43 Phase-4 FRs** (FR-P4-1..43), plus full carry-forward of Phase-1 + Phase-2 + Phase-3 closed FRs via FR-P4-40. All Phase-4 FRs derive from `docs/antforth-banking-redesign.md` (locked 2026-05-09). They cluster into seven architectural-impact groups:

- **FR-P4-1..12 (Banking Wordset).** The 12 user-facing words (`BANK@ BANK! BANKS IN-BANK BANK-OF .BANKS +BANK -BANK BANKS-CLEAR SET-BANK BANK-MAPPING-ON BANK-MAPPING-OFF`). Architectural impact: new file `src/banking.asm` carrying the descriptor-stub allocator, MMU port wrappers, the `cross_bank_return` trampoline, and the kernel-blessed `IN-BANK`. `BANK@` / `BANK!` mirror `BASE @ / BASE !`; `BANK!` precondition is checked on every call (ABORT" bank?" if `n` not in active list); `IN-BANK` is CATCH-safe and kernel-blessed (not a user library word).
- **FR-P4-13..17 (Cross-Bank Dispatch — descriptor-stub mechanism (γ)).** Per-word stub layout (3–5 bytes carrying `(target_bank, target_addr_in_bank)`); compiler always emits stub address as the word's xt; intra-bank dispatch one extra `JP` overhead vs flat; cross-bank dispatch ≤60 T-states + bank-switch. Architectural impact: the (γ) decision collapses S1 + S6 + S7 into one artifact — single biggest design call in the phase.
- **FR-P4-18..21 (Cross-Bank EXIT — sentinel-trampoline (S1 b)).** Sentinel-tagged 3-cell return frame `(sentinel_addr, caller_bank, target_addr)` replaces the broken `BIT 7,H` heuristic from the 2026-05-07 sketch; intra-bank zero-overhead 1-cell return path; cross-bank trampoline lives in fixed memory; recursive cross-bank R-stack overflow falls back to the standard `-5 RETURN-STACK-OVERFLOW` THROW (per-bank guard is open question §9.6).
- **FR-P4-22..26 (Bank-Aware Compiler).** Per-bank `(here, latest, wordlist-heads)` triple in fixed-memory `bank-table[]`; `,` and `COMPILE,` write into the current bank; `:` body lands in current bank with a stub auto-emitted; `CREATE` / `DOES>` cross-bank explicit (PFA stores doer-stub address paired with data cell); `HERE` / `LATEST` per-bank with cross-bank pointer hazards documented as "doc-and-pray".
- **FR-P4-27..30 (Bank-Aware FIND).** Per-wordlist `bank` field; `FIND` saves / switches / walks / restores; system wordlists (FORTH, ASSEMBLER) tagged `bank=fixed` so the common case is zero MMU-switch overhead; `WORDS` traverses banks; lookup-failure error messages name the source bank.
- **FR-P4-31..33 (ABORT/QUIT Bank-State Restore (S5)).** Outermost interactive `BANK!` updates a kernel-internal saved-bank cell; `QUIT` re-asserts on `ABORT` so the user is never stranded in a wrong bank mid-execution. `IN-BANK`'s nested save/restore (FR-P4-4) is independent of this outermost mechanism.
- **FR-P4-34..39 (Boot Configuration).** CL parser in `src/antforth.asm` accepts `antforth <portal-page> <bank-list>` (e.g. `antforth 24 35-3f`); defaults `22 35-3F` (12 banks); probe-on-add via `+BANK`; banner shows the active-bank count; `STARTUP.FTH` rejected as the configuration mechanism (bank availability needed at banner-print time).
- **FR-P4-40..43 (Backward Compatibility & Regression — phase-wide constraint).** Full Phase-1+2+3 user-visible behaviour preserved; the 974 PASS / 0 FAIL Phase-3 close-out baseline (with 2 SKIP-on-iz-cpm-PASS-on-hardware) maintained; CODE-source byte-identical; the `BANK*` wordset is additive and pre-Phase-4 `.FTH` source runs unchanged in bank 0.

**Non-Functional Requirements:**

The PRD specifies **39 Phase-4 NFRs** (NFR-P4-1..39) across six categories, with the **Process Discipline** category continuing to codify the S1–S12 standing commitments as quality attributes:

- **Performance (NFR-P4-1..6)** — Phase-2 NFR1–5 envelopes hold; cross-bank call ≤60 T-states + bank-switch; per-banked-word descriptor stub ≤5 bytes; banking infrastructure ≤8 KB fixed memory worst case (~6 KB at default 12 banks); FIND batch-loading regression envelope ≤5–15%.
- **Reliability (NFR-P4-7..11)** — REPL survives any THROW including across a bank boundary (the trampoline restores caller's bank on the unwind path); bank-table[] entries not corrupted by mid-execution THROW; full Phase-3 974-test baseline regression-clean on every Phase-4 antforth 3.x point-release; mid-epic hardware-smoke cadence per binary-delta story (NFR-P4-11 codifies S9).
- **Compatibility & Standards Conformance (NFR-P4-12..17)** — 100% §6.1 Core compliance via §-level rows continues; Forth-2014 §3.4.1.3 continues; banking words flagged as `; antforth extension` per CCD-3 with a redesign-doc §-reference; CP/M 2.2 BDOS allow-list does not grow in Phase 4; CODE-word source byte-identical regression (cross-bank CODE-word policy is an open question, see §9.1); §-level audit-doc checkability under 10 minutes per row.
- **Maintainability (NFR-P4-18..22)** — Z80 source readability over micro-optimisation; banking infrastructure inline-comments cite redesign-doc §-numbers; REPL-piped Forth tests as canonical regression surface (Phase-4-specifically dual-tracked across banking-capable emulator + iz-cpm); per-epic point-release decoupling; story-template lints (carried from B.1–B.5) fire automatically.
- **Integration (NFR-P4-23..27)** — Terminal I/O, file path conventions, MicroBeast hardware isolation all unchanged; the 12-word `BANK*` wordset is the explicit kernel-resident exception (banking is a memory-model primitive, not a peripheral); **ISR-from-fixed-memory-only invariant** maintained (no banked code reachable from any interrupt vector); BDOS calls (`CALL 0005h`) work unchanged from banked code.
- **Process Discipline (NFR-P4-28..39)** — codifies S1–S12: adversarial CR fresh-context (S1), REPL-piped tests (S2), real byte-count estimation (S3), AC-composition validation (S4), PARTIAL→HALT (S5), inventory-grep covers helpers (S6), EXX-hygiene per raise site (S7) **with the `cross_bank_return` trampoline re-walking the rule**, no "pre-existing" discharge for correctness defects (S8), per-story hardware smoke (S9), workflow > memory > prompt (S10), version-surface audit at tag close-out (S11), hardware-typed probe discipline (S12). All 12 carry forward unchanged from Phase-3 close-out — no S13+ proposals (per project-lead direction 2026-05-10).

**Scale & Complexity:**

- Primary domain: `developer_tool_embedded` (Z80 Forth interpreter on CP/M 2.2)
- Complexity level: **low** (per PRD classification; Phase 4 introduces one new subsystem — banked-RAM enablement — with locked design)
- Estimated architectural components touched: 1 new subsystem (banking) housed in a new `src/banking.asm` plus extensions to existing components: per-bank state in `src/dictionary.asm` (HERE/LATEST), bank-saving in `src/wordlists.asm` (FIND), CL parsing in `src/antforth.asm` (boot), QUIT bank-restore in `src/exception.asm` (ABORT/QUIT), MARKER/FORGET per-bank tracking in `src/dictionary.asm`. Also a new `tests/banking_tests.fth` REPL-probe harness; documentation rows for the 12 banking words in `docs/ans-forth-core-compliance.md` flagged as antforth extensions.

### Technical Constraints & Dependencies

**Inherited from v2.0 + Phase-3 close-out baseline (carry forward unchanged):**

- **Hardware:** Zilog Z80 @ 8 MHz; 512 KB banked RAM/ROM; MicroBeast platform. **Phase 4 lifts banking** — the portal page (default 0x22, configurable on the command line) carries the active user bank; 12 banks of 16 KB each (default 0x35–0x3F) are available to user code; theoretical max 29 banks by trading the virtual-console buffer (0x24) and RAM disk (0x25–0x34).
- **Host OS:** CP/M 2.2 only. BDOS function allow-list per NFR-P4-15 — Phase 4 does not grow the allow-list. **CCP eviction** ($D400–$DBFF marked DISPOSABLE for +2 KB Page-3 headroom); BDOS ($DC00–$E9FF) and BIOS ($EA00+) stay resident.
- **Threading model:** direct threading (JP-based), DEFWORD `cf` label via `EQU body-3` pointing to `JP DOCOL`. Unchanged.
- **Register contract (`docs/register-conventions.md`):** BC = TOS; SP = parameter stack pointer; IX = return stack pointer; IY = user area pointer; DE = IP; HL = working register / scratch. EXX leaf-level rule + "A survives EXX" idiom + shadow BC' as TOS-preservation slot — all carried forward. The `cross_bank_return` trampoline re-walks the EXX-hygiene rule (NFR-P4-34 / S7).
- **Phase-2 cross-cutting decisions (CCD-1..CCD-4) carry forward unchanged:**
  - **CCD-1** dual-chain return-stack frame discipline (`CATCH-TOP` 8-byte exception frames + `INCLUDE-TOP` 10-byte source frames).
  - **CCD-2** THROW code allocation: `-1..-58` ANS standard / `-59..-255` reserved for ANS extensions (with `-69`, `-70` re-purposed for FCB / FID-invalid) / `-256..-32767` antforth extensions (with `-257` reserved for `THROW_ASM_LOAD_FAIL` and `-258..-272` allocated for asm-errors). Phase 4 does not allocate new THROW codes.
  - **CCD-3** standards-citation discipline — every standard-derived word's source carries `; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`. Banking-extension words cite `docs/antforth-banking-redesign.md` §-numbers.
  - **CCD-4** per-epic benchmark gate — close-out story validates NFR envelopes; Phase 4 also tracks banked-word stub-count metric per epic alongside binary size.
- **Source-of-truth boundary stable for Phase 4 except where banking infrastructure requires kernel surgery:** kernel in Z80 assembly; `src/assembler.asm` stays kernel-resident hard-coded (per `project_assembler_keep_assembly.md`); the new `src/banking.asm`, the per-bank dictionary state additions, the per-wordlist `bank` field, the CL parser, and the `cross_bank_return` trampoline live in fixed-memory kernel space.

**Phase-4 specific:**

- **Fixed-memory budget:** ≤8 KB total banking infrastructure at the 28-bank cap (~6 KB at default 12 banks); CCP eviction yields +2 KB Page-3 headroom that absorbs most projected growth (NFR-P4-5).
- **Test baseline:** 974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware on real CP/M 2.2 / MicroBeast (Phase-3 close-out). A single regression is a release blocker (NFR-P4-10).
- **Hardware smoke per binary-delta story (S9 / NFR-P4-11):** every binary-delta story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast; zero-binary-delta stories document S9 exemption explicitly.
- **Tag discipline (S11 / NFR-P4-38):** every Phase-4 antforth 3.x point-release tag passes the user-visible version surface audit (banner / README / memory-file `description` fields).
- **Dual-track emulator strategy:** iz-cpm continues to carry the non-banking regression baseline; a banking-capable emulator (vendor pick is Epic 16.3) carries cross-bank assertions; real MicroBeast is the load-bearing final word for any binary-delta story.

### Cross-Cutting Concerns Identified

1. **Cross-bank dispatch transparency (FR-P4-13..17 / NFR-P4-3).** The (γ) descriptor-stub mechanism collapses S1 (cross-bank EXIT), S6 (`EXECUTE`), and S7 (`COMPILE,`) into one artifact. Cross-cuts the compiler, dictionary, FIND, EXECUTE, and the `cross_bank_return` trampoline. The architecture must pin the stub layout (3 vs 4–5 bytes — open question §9.5), the xt-as-stub-address contract, and the intra-bank zero-overhead path separately from the cross-bank path.
2. **Sentinel-trampoline cross-bank EXIT (FR-P4-18..21 / S1 b).** Replaces the broken `BIT 7,H` heuristic from the 2026-05-07 sketch. Cross-cuts every `EXIT`, every CATCH frame unwind, and every ABORT/QUIT path. The architecture must specify the sentinel address contract (fixed-memory address recognised by `EXIT`) and the 3-cell return-frame layout `(sentinel_addr, caller_bank, target_addr)`.
3. **Per-bank dictionary state (FR-P4-22..26).** Cross-cuts `,` / `COMPILE,` / `:` / `CREATE` / `DOES>` / `HERE` / `LATEST` / `MARKER` / `FORGET`. The architecture must define the `bank-table[]` layout, the swap-on-`BANK!` semantics, and the documented "doc-and-pray" disposition for cross-bank pointer hazards.
4. **Bank-aware FIND (FR-P4-27..30).** Cross-cuts every dictionary lookup, every `WORDS`, every error-message path. System wordlists (FORTH, ASSEMBLER) must be tagged `bank=fixed` so the common case incurs no MMU switch.
5. **ABORT/QUIT bank-state restore (FR-P4-31..33 / S5).** Cross-cuts the outermost interpret loop, every `ABORT` / `ABORT"`, and every uncaught THROW recovery path. The saved-bank cell is updated only by interactive `BANK!` from the outermost loop; nested `IN-BANK` is independent.
6. **ISR-from-fixed-memory-only invariant (NFR-P4-26).** Cross-cuts every interrupt vector, every kernel ISR body, and any future Phase-5+ peripheral ISRs. Architectural rule, not a runtime conflict.
7. **Backward-compatibility / regression invariants (FR-P4-40..43 / NFR-P4-7..10).** Cross-cuts every binary-delta story. The 974 PASS / 0 FAIL Phase-3 close-out baseline + CODE-source byte-identical assembly + no new BDOS functions + the `BANK*` wordset is additive (pre-Phase-4 `.FTH` runs in bank 0 unchanged) — all are absolute, not negotiable.
8. **Fixed-memory budget discipline (NFR-P4-5).** Cross-cuts every binary-delta story. Per-story envelope checked against the ≤8 KB banking infrastructure cap; HALT signal if any single story would push cumulative over. CCP eviction yields +2 KB Page-3 headroom available as buffer.
9. **Standing-commitment hold (S1–S12 / NFR-P4-28..39).** Cross-cuts every Phase-4 retro and every story's verdict criteria. Architectural impact is process-shaped: each Phase-4 story re-validates the relevant subset of S1–S12 in its dev-pass.
10. **Dual-track emulator workflow.** Banking-capable emulator pick (Epic 16.3) is the prework gate; iz-cpm continues to carry the non-banking baseline; real MicroBeast is the load-bearing final word. Cross-cuts every test plan in Epic 17+.

## Starter Template Evaluation

**Not applicable.** antforth is a brownfield Z80 assembly project (`developer_tool_embedded`) with no relevant starter-template ecosystem. Phase 4 is the first feature phase since v2.0 (Phase 3 was a debt-cleanup interlude); there is no scaffolding decision to make — the "starter" is the Phase-3-close-out codebase.

**Phase-4 foundation: antforth Phase-3 close-out** (24,995 bytes `build/antforth.com`, 974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware on real CP/M 2.2 / MicroBeast; Epic 14 + Epic 15 closed 2026-05-09). Inherited without replacement:

- **Inner interpreter:** direct-threaded (JP-based); DEFWORD `cf` label via `EQU body-3` pointing to `JP DOCOL`.
- **Register contract** (`docs/register-conventions.md`): BC=TOS, SP=pstack, IX=rstack, IY=user-area, DE=IP, HL=W. EXX leaf-level rule + "A survives EXX" idiom + shadow BC' as TOS-preservation slot.
- **Outer interpreter / REPL:** text parser, interpret/compile state machine, exception-frame-aware error reporting (post-Epic-11 — uncaught THROWs route to the inlined `.throw_uncaught` recovery chain in `src/exception.asm`).
- **Dictionary:** multi-vocabulary Search-Order (post-Epic-12) — XOR-rotate 64-bucket hash per wordlist, search-order LIFO with bounds check.
- **Language extension layer:** colon definitions, CREATE/DOES>, control flow, MARKER, immediate words, POSTPONE; numeric-literal prefixes (Forth 2014 §3.4.1.3 + `0x` extension; base-aware unprefixed parsing post-A.3).
- **Exception subsystem (Epic 11):** CCD-1 dual-chain frame discipline; CATCH-TOP and INCLUDE-TOP USER variables; 8-byte exception frames + 10-byte INCLUDE source frames; ABORT/ABORT" retargeted to -1/-2 THROW.
- **File-Access wordset (Epic 13):** real CP/M 2.2 BDOS integration (function allow-list per NFR-P4-15); FCB pool with use-after-free detection (-70 re-purposed); INCLUDE source-frame chain walk integrated with THROW; disk-full / dir-full / zero-byte READ-FILE coverage closed by Story 15.5 (Phase 3 close-out).
- **Built-in Z80 assembler:** 113 DEFCODEs, ~4,100 lines of `src/assembler.asm`, 158/158 instruction-form coverage, asm-error THROW codes -258..-272 with caught-form coverage closed by Phase 3 Story A.2.
- **Pictured numeric output (Epic 10) + double-cell arithmetic** with high-on-TOS layout (post-Story-13.0.1, ANS §3.1.4.1).
- **§-level Core compliance baseline:** 100% §6.1 word coverage + §3.1.4.1 / §3.4.1.3 structural rules + per-rule §-level rows in `docs/ans-forth-core-compliance.md` (Phase 3 A.1 audit; Story 15.1 close-out).
- **Test harness:** REPL-piped Forth test scripts (convention since Epic 3, codified by S2); 974 PASS / 0 FAIL on real hardware; `make test-repl` baseline.
- **Process discipline foundation:** standing commitments S1–S12 holding through Phase-3 close-out (Epic 14 + Epic 15 retros); BMAD workflow files (story-template lints from B.1–B.5); `feedback_*.md` discipline files; `docs/PHASE-3-CARRY-FORWARD.md` as the prioritised catalogue (now closed).

**Toolchain (largely unchanged for Phase 4):** project's existing Z80 cross-assembler invoked by build scripts; iz-cpm emulator for `make test-repl` non-banking baseline; real MicroBeast hardware for S9 mid-epic hardware-smoke per binary-delta story. **Phase 4 adds:** a banking-capable emulator (vendor pick = Epic 16.3 prework gate) running dual-track with iz-cpm so cross-bank assertions can run under emulation before the hardware load-bearing pass.

**Phase-1 / Phase-2 / Phase-3 cross-reference:** The phase-1 architecture document (`architecture-phase1-epics-1-8.md`), phase-2 architecture document (`architecture-phase2-epics-9-13.5.md`), and phase-3 architecture document (`architecture-phase3-epics-14-15.md`) are the canonical references for all inherited subsystems. **This document specifies only the additions and changes for phase 4.** Dev-agent invocations consult phase-1 + phase-2 + phase-3 for the foundation, phase-4 for what is changing or being added. Where documents disagree, phase-4 wins (it describes the target state); where phase-4 is silent, phase-3 governs; where phase-3 is silent, phase-2 governs; where phase-2 is silent, phase-1 governs. Phase 4 is concentrated in the new banking subsystem (`src/banking.asm`), the per-bank dictionary state additions (`src/dictionary.asm`), bank-aware FIND (`src/wordlists.asm`), the CL parser (`src/antforth.asm`), and the QUIT bank-restore (`src/exception.asm`).

**Note:** No project-initialization story is needed — Phase 4 starts from the Phase-3 close-out working tree.

## Core Architectural Decisions

> **Phase-1 / Phase-2 / Phase-3 cross-reference:** The phase-1, phase-2, and phase-3 architecture documents are the canonical references for all inherited subsystems. **This document specifies only the additions and changes for phase 4.** Where documents disagree, phase-4 wins; where phase-4 is silent, phase-3 governs; where phase-3 is silent, phase-2 governs; where phase-2 is silent, phase-1 governs. Phase 4 changes concentrate in the new banking subsystem (`src/banking.asm`), the per-bank dictionary state additions (`src/dictionary.asm`), the per-wordlist `bank` field on FIND (`src/wordlists.asm`), the CL parser (`src/antforth.asm`), and the QUIT bank-restore (`src/exception.asm`).

### Decision Priority Analysis

**Critical Decisions (block specific FR groups):**
- (γ) Per-word descriptor stub mechanism (blocks FR-P4-13..17, the entire cross-bank dispatch surface)
- (S1 b) Sentinel-trampoline cross-bank EXIT (blocks FR-P4-18..21, the cross-bank EXIT surface)
- Per-bank `(here, latest, wordlist-heads)` triple in `bank-table[]` (blocks FR-P4-22..26, the bank-aware compiler)
- Per-wordlist `bank` field + system-wordlist `bank=fixed` tagging (blocks FR-P4-27..30, bank-aware FIND)
- ABORT/QUIT bank-state restore mechanism (blocks FR-P4-31..33, S5 carry)
- CCP eviction (+2 KB Page-3 headroom; blocks the fixed-memory budget envelope NFR-P4-5)
- ISR-from-fixed-memory-only invariant (blocks NFR-P4-26 — the architectural rule that lets MMU port writes be non-atomic)
- Boot-config CL parser (blocks FR-P4-34..39)
- Banking-capable emulator vendor pick (Epic 16.3 prework gate; blocks Epic 17+ story-writing)

**Important Decisions (shape Phase-4 dev-passes):**
- Stub size pinning: 3 vs 4–5 bytes (open question §9.5; affects per-1000-words cost calculations)
- CL parser edge-case policy (open question §9.3: no args, bad token, reverse range, dup, probe-fail, empty surviving list)
- Bank-state-table cap policy (open question §9.4: ABORT-on-`+BANK`-past-cap)
- Cross-bank R-stack overflow disposition (open question §9.6: documented gotcha vs runtime guard)
- CODE-words-in-banks decision (open question §9.1: affects S7 dispatch in Epic 22)
- `BANK-OF` implementation as one-byte read from descriptor stub (free under (γ))

**Carry-forward (no re-decision):**
- CCD-1 dual-chain frame discipline (Phase-2)
- CCD-2 THROW code allocation; Phase 4 does not allocate new THROW codes
- CCD-3 standards-citation discipline; banking words flagged `; antforth extension` with redesign-doc §-reference
- CCD-4 per-epic benchmark gate; Phase 4 also tracks banked-word stub-count metric
- CCD-P3-1 §-level compliance-doc row schema (Phase 3)
- CCD-P3-2 process discipline lives in workflow files (Phase 3)
- Register contract, EXX leaf-level rule, DTC threading, source-of-truth boundary
- S1–S12 standing commitments unchanged (no S13+ proposals per project-lead direction 2026-05-10)

**Deferred (post-Phase-4):**
- Multitasking / TCB-as-1-byte-bank (Phase 5)
- Semaphores (Phase 6, depends on multitasking)
- Locals wordset (Phase 5+; all three styles confirmed compatible with banking)
- ALLOCATE / per-bank heap (Phase 5+; recommended (β) per redesign §2.3)
- MicroBeast hardware vocabulary epic (Phase 5+; E.1)
- `SEE` decompiler / `TRAVERSE-WORDLIST` (Phase 5+; E.4 / E.5)
- Z80 IN / OUT primitives (Phase 5+; E.7)
- Compilation to standalone `.com` binary (Phase 5+; E.8)
- Flat-build retention (Phase 5+; deferred from Phase 4 MVP per redesign §4)

---

### Cross-Cutting Architectural Decisions

#### CCD-1, CCD-2, CCD-3, CCD-4 (Phase-2 carry-forward)

CCD-1 (return-stack frame taxonomy with dual chain discipline — `CATCH-TOP` 8-byte exception frames + `INCLUDE-TOP` 10-byte source frames), CCD-2 (THROW code allocation across the three ranges -1..-58 / -59..-255 / -256..-32767), CCD-3 (standards-citation discipline per word), and CCD-4 (per-epic benchmark/close-out gate) all carry forward unchanged from `architecture-phase2-epics-9-13.5.md`.

**Phase-4 reaffirmation of CCD-1:** the cross-bank 3-cell return frame `(sentinel_addr, caller_bank, target_addr)` is a NEW frame type added to the dual-chain discipline. The intra-bank 1-cell return frame is the standard ANS return frame; the cross-bank 3-cell frame is recognised by `EXIT` via the sentinel-address comparison. Both frames coexist on the same return stack chain; `CATCH-TOP` and `INCLUDE-TOP` chains are unaffected by the cross-bank frame addition (cross-bank-EXIT trampoline does not interact with exception or include frames).

**Phase-4 reaffirmation of CCD-2:** Phase 4 allocates **no** new THROW codes. The 12-word `BANK*` wordset uses standard ANS THROW codes (`-9 invalid memory address`, `-13 undefined word`) plus the existing antforth-extension block. `BANK!` precondition violation raises ABORT" bank?" (which decodes to -2 ABORT" per CCD-2's existing allocation). Probe-on-add failure raises ABORT" probe?" similarly. The reservation discipline holds unchanged.

**Phase-4 reaffirmation of CCD-3:** every `BANK*` word's source carries `; antforth extension <word> — see docs/antforth-banking-redesign.md §<n>`. The `cross_bank_return` trampoline carries an inline pointer to redesign §2.2.

#### CCD-P3-1, CCD-P3-2 (Phase-3 carry-forward)

The §-level compliance-doc row schema (CCD-P3-1) and the process-discipline-in-workflow-files convention (CCD-P3-2) both carry forward unchanged. Phase 4 adds rows for the 12 banking words to `docs/ans-forth-core-compliance.md` flagged as `Source: docs/antforth-banking-redesign.md` / `Verdict: Implemented (antforth extension)` / `Closure: Story 17.x..22.x`. The row format is unchanged.

---

### Per-Item Decisions (Phase-4 — Decision Records)

#### PD-P4-1: (γ) Per-word descriptor stubs for cross-bank dispatch

**Question:** How does an `xt` carry bank information so cross-bank `EXECUTE`, `EXIT`, and `COMPILE,` dispatch transparently?

**Options considered:**
- (α) Side-table mapping `xt → bank`. **REJECTED** — awkward to maintain on `FORGET`; introduces a second lookup on every dispatch.
- (β) 24-bit `xt`. **REJECTED** — breaks the Forth-standard cell-as-address invariant; cascades into compiler / FIND / data-stack-passing assumptions.
- (γ) Fixed-memory descriptor stubs. ★ **CHOSEN** ★ — every banked word, when defined, also gets a 3–5-byte stub in fixed memory containing `(target_bank, target_addr_in_bank)`. **The stub's address is the word's xt.**

**Rationale:** (γ) collapses S1 (cross-bank EXIT) + S6 (`EXECUTE`) + S7 (`COMPILE,`) into one artifact. xts remain cell-sized and stable across `BANK!`. `BANK-OF` becomes a one-byte read from the stub — essentially free.

**Architectural impact:** `src/banking.asm` carries the stub allocator; `src/dictionary.asm` extends `:` to allocate-stub-on-define; `src/compiler.asm`'s `COMPILE,` always emits the stub address. Serves FR-P4-13..17.

**Source:** `docs/antforth-banking-redesign.md` §2.1.

#### PD-P4-2: (S1 b) Sentinel-tagged cross-bank returns

**Question:** How does `EXIT` distinguish an intra-bank return from a cross-bank return so it can restore the caller's bank only when needed?

**Options considered:**
- (a) `BIT 7,H` heuristic on the return-address high byte. **REJECTED** — broken because user code lives at $8000–$BFFF, so bit 7 is always set on every user-code return-address; the heuristic detects nothing.
- (b) Sentinel-tagged returns. ★ **CHOSEN** ★ — intra-bank returns push 1 cell (zero overhead, standard ANS frame). Cross-bank returns push three cells: `(sentinel_addr, caller_bank, target_addr)`. The sentinel is a fixed-memory address recognised by `EXIT`; on match, `EXIT` jumps to the `cross_bank_return` trampoline which restores the caller's bank then jumps to the target.

**Rationale:** Preserves the intra-bank zero-overhead path (the common case). The sentinel comparison is a single CP against a fixed address; the cross-bank path adds one MMU port write + one JP to the standard return-address pop.

**Architectural impact:** `src/banking.asm` carries the `cross_bank_return` trampoline at a fixed address; `src/inner_interpreter.asm`'s `EXIT` adds the sentinel comparison; descriptor-stub dispatch (PD-P4-1) pushes the 3-cell frame on cross-bank entry. Serves FR-P4-18..21.

**Source:** `docs/antforth-banking-redesign.md` §2.2.

#### PD-P4-3: Per-bank state triple swapped on `BANK!`

**Question:** How does the compiler track per-bank dictionary state (HERE, LATEST, wordlist heads) so `:` defines into the current bank correctly?

**Options considered:**
- (a) Single global state with explicit-target-bank arguments to `,` / `COMPILE,`. **REJECTED** — invasive to every compiler word; user-visible API change.
- (b) Per-bank `(here, latest, wordlist-heads)` triple swapped on `BANK!`. ★ **CHOSEN** ★ — `bank-table[]` in fixed memory holds one triple per bank; `BANK!` swaps the active triple atomically.

**Rationale:** The user types `5 BANK!` then defines like always — the compiler sees the per-bank triple it's been writing to all along. Cross-bank pointer hazards (capturing HERE in bank A, then `BANK!`-ing to B and writing) are accepted as "doc-and-pray" — documented gotcha, no runtime guard, consistent with Forth tradition of trusting the programmer.

**Architectural impact:** `src/dictionary.asm` extends HERE / LATEST to read from the active bank-table[] entry; `src/banking.asm` carries the `bank-table[]` allocator and the `BANK!` swap routine. Serves FR-P4-22..26.

**Source:** `docs/antforth-banking-redesign.md` §5.4.

#### PD-P4-4: Bank-aware FIND with system-wordlist fast path

**Question:** How does FIND walk wordlist chains that may live in different banks without paying MMU-switch cost on every lookup?

**Options considered:**
- (a) Always switch to wordlist's bank, walk chain, switch back. **REJECTED** in its naive form — system wordlists (FORTH, ASSEMBLER) live in fixed memory; switching is wasted.
- (b) Per-wordlist `bank` field; FIND saves current bank, switches only if wordlist is non-fixed, walks, restores. ★ **CHOSEN** ★ — system wordlists tagged `bank=fixed` (-1); the common case (FORTH lookup) incurs no MMU switch.

**Rationale:** Interactive FIND latency is invisible to the user (sub-frame at 8 MHz) regardless. Batch loading with many user-bank-resident wordlists costs the documented 5–15% (NFR-P4-6); system-wordlist fast path keeps the everyday case zero-overhead.

**Architectural impact:** `src/wordlists.asm` extends the wordlist header with a `bank` field; `src/dictionary.asm`'s FIND walks the search order, switching banks per wordlist. Serves FR-P4-27..30.

**Source:** `docs/antforth-banking-redesign.md` §5.5.

#### PD-P4-5: ABORT/QUIT bank-state restore (S5)

**Question:** How does the user avoid being stranded in the wrong bank after an `ABORT` mid-execution?

**Options considered:**
- (a) Snapshot bank on every word entry, restore on uncaught THROW. **REJECTED** — invasive to every word; cost not justified for non-cross-bank common case.
- (b) Saved-bank cell updated only by interactive `BANK!` from the outermost interpret loop; `QUIT` re-asserts on re-entry. ★ **CHOSEN** ★ — minimal kernel surgery; nested `IN-BANK` is independent (its own save/restore via `>R / R>`).

**Rationale:** The user's "current bank" is whatever they last typed at the REPL. `ABORT` unwinds + re-enters QUIT; QUIT re-asserts the saved bank. Mid-execution-bank-switching code (which uses `IN-BANK`) is responsible for its own restore via the kernel-blessed `IN-BANK` body.

**Architectural impact:** `src/exception.asm`'s QUIT entry-point reads the saved-bank cell and writes it through the MMU; `src/outer_interpreter.asm`'s top-level `BANK!` recogniser updates the saved-bank cell. Serves FR-P4-31..33.

**Source:** `docs/antforth-banking-redesign.md` §5.6.

#### PD-P4-6: CCP eviction (Page 3 +2 KB)

**Question:** How does Phase 4 absorb the projected ~6 KB banking-infrastructure growth into the existing fixed-memory layout?

**Options considered:**
- (a) Compress existing kernel code. **REJECTED** — kernel is already dense; readability/maintainability cost too high.
- (b) Move kernel words to a bank. **REJECTED** — defeats the purpose; cross-bank dispatch overhead on every kernel call.
- (c) Evict CCP from $D400–$DBFF (+2 KB). ★ **CHOSEN** ★ — CCP is reloadable from disk on warm-boot; antforth replaces CCP at process load time anyway; the +2 KB fits the descriptor-stub allocator + bank-table[] worst case.

**Rationale:** BDOS at $DC00–$E9FF stays resident; `CALL 0005h` from banked code works unchanged. CCP eviction is a one-line change to the kernel's load-time memory map. CP/M warm-boot reloads CCP from disk on the user's next `^C` (verification needed in Epic 16 — see F3 in Findings).

**Architectural impact:** `src/antforth.asm`'s memory-map declaration moves the kernel-end up by 2 KB; the descriptor-stub allocator owns the new $D400–$DBFF region. Serves NFR-P4-5.

**Source:** `docs/antforth-banking-redesign.md` §5.2.

#### PD-P4-7: ISR-from-fixed-memory-only invariant

**Question:** How does the kernel handle interrupts when user banks may be mapped in MMU slot 2?

**Decision:** Architectural invariant — no banked code is reachable from any interrupt vector. ISR bodies live in fixed memory only. Any kernel code that runs in interrupt context (timer ISR, peripheral ISR if added in a future phase) executes against fixed memory regardless of which user bank is currently active.

**Rationale:** MMU port writes are non-atomic from the ISR vantage; an ISR firing mid-`BANK!` is safe only if the ISR body does not depend on which user bank is mapped. This is also a Phase-5+ multitasking enabler (preemption is safe because the TCB-bank-restore happens in fixed-memory ISR code).

**Architectural impact:** Documented as architectural rule; no new code surface. Any Phase-4 or Phase-5+ story touching the timer-ISR / interrupt-vector path re-walks this invariant. Serves NFR-P4-26.

**Source:** `docs/antforth-banking-redesign.md` §5.3.

#### PD-P4-8: Boot configuration via CL parser (not STARTUP.FTH)

**Question:** How does the user configure which physical pages are available as banks?

**Options considered:**
- (a) `STARTUP.FTH` — boot-time configuration via Forth source. **REJECTED** — `.FTH` files cannot run before the boot banner; bank availability needs to be known at banner-print time.
- (b) Command-line tail. ★ **CHOSEN** ★ — `antforth <portal-page> <bank-list>` (e.g. `antforth 24 35-3f`); defaults to `22 35-3F` (12 banks); probe-on-add via `+BANK`; banner shows the active-bank count.

**Rationale:** CP/M's command-tail mechanism is well-defined (BDOS function 0x80h-area); the parser is small (~200 B per redesign §7); the user can over-ride defaults without touching disk files.

**Architectural impact:** `src/antforth.asm` adds a CL-tail parser invoked early in boot; the `+BANK` word is reused for runtime addition (consistency).

**Open question (§9.3):** edge-case policy for no args / bad token / reverse range / dup / probe-fail / empty surviving list. Owned by Epic 16 spike. Serves FR-P4-34..39.

**Source:** `docs/antforth-banking-redesign.md` §6.

#### PD-P4-9: Banking-capable emulator dual-track

**Question:** How does the project run cross-bank assertions under emulation when iz-cpm doesn't support banking?

**Decision:** Run a banking-capable emulator alongside iz-cpm. iz-cpm continues carrying the non-banking regression baseline (so the existing 974-test suite continues passing); the banking-capable emulator carries cross-bank assertions added in Phase 4. Real MicroBeast is the load-bearing final word for any binary-delta story (S9).

**Rationale:** Replacing iz-cpm risks regression on the existing baseline. Adding a second emulator preserves the existing safety net while enabling cross-bank emulation. Vendor pick is the explicit Epic 16.3 prework gate.

**Three eval criteria pinned for vendor selection:**
1. Models the 32-page MMU at ports 0x70+slot / 0x74 (matches MicroBeast hardware)
2. Pipe-able for `make test-repl`-style automation
3. Bank-visibility for tests (test scripts can assert which bank is currently active)

**Architectural impact:** new `make test-repl-banking` (or equivalent) target; per-probe annotation of which emulator surface the probe targets. Serves NFR-P4-19.

**Source:** `docs/antforth-banking-redesign.md` §8.1.

#### PD-P4-10: Phase-5+ future-proofing (no painted corners)

**Question:** Does the Phase-4 banking design close off Phase-5+ candidates (multitasking, locals, ALLOCATE)?

**Decision:** No. The 2026-05-09 design session walked the implications; all three remain compatible.

- **Multitasking (Phase 5):** bank = 1 byte of TCB; stubs/sentinels ride preemption cleanly because the trampoline is in fixed memory and the cross-bank frame is on the standard return stack (which is per-task).
- **Locals (Phase 5+):** all three styles (`{: a b -- c :}`, `VALUE` / `TO`, return-stack-based) compatible with banking — locals live on the return stack or in a per-task user-area, neither of which is bank-sensitive.
- **ALLOCATE (Phase 5+):** recommended direction is (β) per-bank heap with a `BANK-OF-ALLOC` helper. Greek labels (α′)/(β′)/(γ′) reused for ALLOCATE design — explicitly distinct from S6's (α)/(β)/(γ).

**Rationale:** Capturing this as a decision record so future-Phase architects don't re-litigate the "did banking close X off?" question.

**Source:** `docs/antforth-banking-redesign.md` §8.2.

---

### Decision Impact Analysis

**Implementation sequence (locked by redesign-doc §8 epic structure):**

1. **Epic 16 (prework gate, must close first):** memory map + emulator pick + doc lock. Story 16.3 (banking-capable emulator vendor selection) blocks Epic 17+ story-writing.
2. **Epic 17 (bank primitives + CL config):** all 12 wordset words in first usable form; `+BANK` / `-BANK` / `BANKS-CLEAR`; CL parser; probe-on-add; banner update; first iron spike for cross-bank call.
3. **Epic 18 (stub mechanism (γ) + cross-bank EXIT (S1 b)):** per-word descriptor stubs; sentinel-trampoline return; kernel `EXECUTE` switches through stub; `BANK-OF`; kernel-blessed `IN-BANK`.
4. **Epic 19 (bank-aware compiler):** per-bank `(here, latest, wordlist-heads)`; `,` / `COMPILE,` / `:` write into current bank; descriptor stub auto-emitted on `:`; `CREATE` / `DOES>` cross-bank explicit.
5. **Epic 20 (bank-aware FIND + interpreter loop):** per-wordlist `bank` field; `FIND` saves/switches/walks/restores; `WORDS`; error messages name source bank.
6. **Epic 21 (MARKER/FORGET + ABORT/QUIT bank state (S5)):** per-bank dictionary tail tracking; `QUIT` re-asserts saved current bank.
7. **Epic 22 (polish):** `.BANKS`; REPL prompt indicator; CODE-words-in-banks decision (open question §9.1); test-harness sweep across all three test surfaces.

The Epic-16 prework gate is the load-bearing sequencing constraint. Without the banking-capable emulator pick, Epic 17 stories cannot specify their test plan (each banking-touching probe must specify which emulator surface it targets).

**Cross-component dependencies:**

- Epic 18 stubs (PD-P4-1) depend on Epic 17 bank primitives (`BANK!`, `BANK@`) being in place
- Epic 19 bank-aware compiler depends on Epic 18 stub auto-emission (`:` allocates a stub via the stub allocator from PD-P4-1)
- Epic 20 bank-aware FIND can proceed in parallel with Epic 19 once Epic 17 is in
- Epic 21 ABORT/QUIT bank-state restore depends on Epic 18 (sentinel-trampoline EXIT must be in place for cross-bank THROW unwind)
- Epic 22 polish depends on Epics 17–21 all being in (the test-harness sweep validates the integrated surface)

**Per-epic fixed-memory budget envelopes (against NFR-P4-5 ≤8 KB cap; ~6 KB at default 12 banks):**

| Epic | Component | Expected fixed-memory delta |
|---|---|---|
| 16 | Memory map / emulator pick / doc lock | 0 (planning only; CCP eviction is a one-line memory-map change) |
| 17 | Bank primitives + CL parser + probe loop | ~400 B (12 wordset words ~120 B; CL parser ~200 B; probe ~80 B) |
| 18 | Stub allocator + sentinel trampoline + EXECUTE switch | ~400 B (allocator ~150 B; trampoline ~80 B; EXECUTE-switch ~50 B; `IN-BANK` + `BANK-OF` ~120 B) |
| 19 | Bank-aware compiler (`,` / `COMPILE,` / `:` / `CREATE` / `DOES>`) | ~300 B (per-bank state plumbing) |
| 20 | Bank-aware FIND + per-wordlist `bank` field + `WORDS` | ~200 B (FIND extension + WORDS extension) |
| 21 | MARKER/FORGET per-bank + QUIT bank-restore | ~150 B (saved-bank cell + QUIT entry-point edit + MARKER/FORGET per-bank tracking) |
| 22 | Polish (`.BANKS`, prompt indicator, CODE-words-in-banks, test sweep) | ~100 B (`.BANKS` ~80 B; prompt indicator ~20 B; CODE-words-in-banks may add more depending on §9.1 disposition) |
| Per-banked-word descriptor stubs (allocated dynamically, not per-epic) | 3–5 B/word × 1000 words target | ~5 KB worst case (in the +2 KB Page-3 headroom + CL/banking-words allocation) |
| **Total banking infrastructure (worst case at 28-bank cap)** | | **~7–8 KB (within NFR-P4-5)** |

**Cumulative target:** ≤8 KB total banking infrastructure (NFR-P4-5). +2 KB Page-3 headroom from CCP eviction (PD-P4-6) absorbs most projected growth. HALT signal if any single epic would push cumulative over.

**Tag-applicable close-out gates (S11 / NFR-P4-38):**

Every Phase-4 antforth 3.x point-release tag passes the user-visible version surface audit:

- Banner string in binary: `make` produces a binary whose banner reads the new 3.x version
- README version reference: aligned to the tag being applied
- Memory-file `description` fields: any memory entry citing the antforth version (e.g., the Phase-4 successor to `project_phase3_scope.md`) reads the new 3.x version

S11 + B.5 (`make check-doc-sync`) together form the close-out gate's documentation arm; S9 (per-story hardware smoke) forms the hardware arm; the verdict-table walk (per Story 13.5.6 precedent) consolidates both at the close-out story.

## Implementation Patterns & Consistency Rules

> **Phase-2 / Phase-3 carry-forward.** All naming, format, and inter-word communication patterns from the phase-2 + phase-3 architecture documents continue to apply unchanged in Phase 4. This section covers only the Phase-4-specific additions: banking-word naming (BANK@/BANK!/+BANK/-BANK/etc.), descriptor-stub layout, sentinel-trampoline contract, per-bank state-swap idiom, and ISR-from-fixed-only invariant.

### Conflict Points Identified (Phase-4-specific)

Phase-4-shaped points where multiple AI agents could make different choices:

- **Bank-switch latency vs ISR timing** — resolved as architectural constraint (PD-P4-7 ISR-from-fixed-only invariant); not a runtime conflict but documented so any Phase-4 story touching the timer-ISR path re-walks the rule
- **Descriptor-stub fixed-mem cost vs ~8 KB headroom** — stubs at 4–5 B/word × 1000 words = 4–5 KB; total banking infra ~6 KB worst case at default 12 banks, ~7–8 KB at 28-bank cap; "fits, not by miles, fits"; per-epic stub-count metric tracked alongside binary size
- **Per-bank `HERE` cross-bank pointer hazard** — accepted as "doc-and-pray" gotcha (user holds HERE in bank A then `BANK!`s to B and writes — undefined); no runtime guard; documented in user docs
- **CL parser failure modes** — open question §9.3 (Epic-16 spike): no args, bad token, reverse range, dup, probe-fail, empty surviving list — final policy for each not yet signed off
- **ABORT-on-`+BANK`-past-cap policy** — open question §9.4 (Epic-16 spike): `bank-table[]` is 29 entries; `+BANK` beyond cap behaviour unspecified
- **Banking-capable emulator availability gating Phase-4 work** — Epic 17+ blocked on Epic 16.3 vendor pick; iz-cpm continues carrying the non-banking baseline
- **Stub size pinning (3 vs 4–5 bytes)** — open question §9.5 (Epic-16 spike): final size affects per-1000-words cost calculations; agents could draft against an unpinned figure
- **Cross-bank R-stack overflow disposition** — open question §9.6: documented gotcha vs runtime guard; default policy is documented-gotcha (cheaper); upgrade if hardware repro surfaces a real failure

### Naming & Structure Patterns (Phase-4-specific)

**Banking-word naming idioms:**

- **`BANK@ / BANK!` mirrors `BASE @ / BASE !`** — the established Forth idiom for ambient state with getter/setter. Reads naturally inside colon definitions (`BANK@ >R 5 BANK! ... R> BANK!`).
- **`USER-` prefix dropped** — only one kind of user-controllable bank exists; the prefix from the obsolete `docs/antforth-banking-design.md` was noise. (`USER-BANK / USER-BANK@ / SET-USER-BANK` from the obsolete doc are not in the wordset.)
- **System wordlists tagged `bank=fixed`** — FORTH, ASSEMBLER never need MMU switch on lookup; the field is the discriminator FIND uses to skip the switch.
- **`+BANK / -BANK / BANKS-CLEAR` follow Forth list-mutation idiom** — "+/-WORDLIST"-shaped; the `+` / `-` prefix signals mutation of an ambient set.
- **Greek-letter decision shorthand** — (α) / (β) / (γ) used in design discussions for option labels under specific architecture-question subheads (S1, S6, etc.); REJECTED / ★ CHOSEN ★ markers in plain text. Reused for future ALLOCATE design as (α′) / (β′) / (γ′) per redesign §2.3 — explicitly distinct from S6's letters.
- **`SET-BANK` retained for diagnostics** — raw MMU port write; not a user-facing common path; lives in the wordset because `+BANK` can't bypass the bank-table[] machinery.
- **`BANK-MAPPING-ON` / `BANK-MAPPING-OFF`** — explicit kernel control; auto-`ON` in COLD; `OFF` exists for the CP/M warm-boot escape (returning to a flat-memory CP/M context).

**Descriptor-stub layout label conventions:**

- Stub address IS the xt — name stub-allocator output `xt_<word>` consistently in source; never `stub_<word>` (the stub IS the xt; the names should not encode internal structure)
- `target_bank` field convention: signed byte; `-1` for fixed-memory marker; `0..28` for active bank indices
- `target_addr_in_bank` field convention: 16-bit address inside the target bank's body region

**Sentinel-trampoline labels:**

- `cross_bank_return:` — the trampoline label in `src/banking.asm`; sentinel address is `cross_bank_return` itself (one symbol does both jobs)
- 3-cell return frame field order on the return stack (top-to-bottom): `(sentinel_addr, caller_bank, target_addr)` — names in source comments must match this order

**Per-bank state field naming:**

- `bank-table[]` — fixed-memory array, one entry per bank
- Each entry holds `(here, latest, wordlist-heads)` — the names match the global Forth idiom; the per-bank version is the same name with the bank context implicit

**Carry-forward Phase-2/3 naming patterns** (compliance-doc row labels per CCD-P3-1, back-fill story file naming, workflow-file edit identity per CCD-P3-2) — preserved unchanged.

### Format Patterns (Phase-4-specific)

**Greek-letter decision shorthand format.** Used in `docs/antforth-banking-redesign.md` §2 to label options under specific architecture-question subheads (S1, S6, etc.):

```markdown
### S6 — `EXECUTE` across banks (the (γ) decision)

- **(α) Side-table mapping `xt → bank`.** REJECTED — awkward to maintain on `FORGET`.
- **(β) 24-bit `xt`.** REJECTED — breaks the Forth-standard cell-as-address invariant.
- **(γ) Fixed-memory descriptor stubs.** ★ CHOSEN ★ — every banked word, when defined, also gets a 3–5-byte stub in fixed memory containing `(target_bank, target_addr_in_bank)`. The stub's address is the word's xt.
```

Options are labelled (α) / (β) / (γ) with **REJECTED** / ★ **CHOSEN** ★ markers in plain text; rationale paragraph follows. The (α′) / (β′) / (γ′) variant is reserved for the future ALLOCATE design (Phase 5+) and is explicitly distinct from S6's letters.

**S-numbered architecture-question shorthand format.** Used as section labels in design discussions:

```markdown
### S1 — Cross-bank EXIT (the (b) sentinel decision)
### S6 — `EXECUTE` across banks (the (γ) decision)
```

S1 (cross-bank EXIT), S2 (per-bank state), S3 (bank-aware FIND), S5 (ABORT/QUIT), S6 (EXECUTE), S7 (COMPILE,) — used as shorthand in design discussions; **NOT** a numbered-question-list anyone needs to memorise; surfaces in commit messages and retro notes for traceability ("Story 18.2: closes S1 b").

**Banking-extension citation comment format (per CCD-3):**

```asm
; antforth extension BANK! — see docs/antforth-banking-redesign.md §1
w_BANK_STORE_cf:
    ...
```

The comment carries (a) the `; antforth extension <word>` flag and (b) the redesign-doc §-reference. No external standard is cited (banking is not in any ANS / Forth-2014 wordset).

**Carry-forward Phase-2/3 format patterns** (one-line standards-citation comments per CCD-3, compliance-doc row format per CCD-P3-1, `<critical>` block format from B.2 / B.4, pre-edit baseline task format from B.3) — preserved unchanged.

### Communication Patterns — Phase-4-specific (banking inter-word contracts)

Phase 4 adds the following inter-word contracts on top of the Phase-2/3 contracts (BC=TOS, EXX leaf-level rule, exception-frame layout, INCLUDE source-frame layout, IY-relative user-area access, FCB-pool acquire/release semantics, the `file_byte_read` tri-state contract from Story 13.5.2 — all unchanged):

- **`IN-BANK` is CATCH-safe and kernel-blessed** — not a user library word. Reference body: `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;`. Restore-on-throw must be guaranteed; the kernel implements it directly so the contract holds even if the EXECUTEd word raises an exception.
- **`BANK!` precondition: `n` in active list, else `ABORT" bank?"`** — checked on every call, not just first. Callers must not assume "I just called `BANK!` with this `n`, so it's still valid"; another word may have called `-BANK` in between.
- **Cross-bank-call ABI is descriptor-stub-mediated** — the callee never sees the caller's bank explicitly; the sentinel-trampoline EXIT restores the caller's bank automatically. Callees never write to the caller's bank-table[] entry directly.
- **Per-bank state swap on `BANK!` is atomic from user's view** — the `(here, latest, wordlist-heads)` triple swaps in one go; user cannot observe a partial swap (e.g., new HERE with old LATEST). Implementation is an indexed load of three cells from `bank-table[n]` into the active-state cells.
- **System wordlists never trigger MMU switch on FIND** — FORTH and ASSEMBLER tagged `bank=fixed` (-1); FIND's per-wordlist loop checks the field and skips the switch. New wordlists default to whatever bank they're created in; user must explicitly tag a new wordlist `bank=fixed` if they want zero-switch lookups (rare, only for kernel-extension wordlists).
- **BDOS calls work unchanged from banked code** — `CALL 0005h` lands in fixed memory ($DC00–$E9FF); the caller's bank stays mapped throughout the BDOS call; the `RET` returns to the caller's bank context. No bank-switching glue needed around BDOS calls. (Verification: this depends on the BDOS implementation not depending on slot-2 contents during its execution; verified for CP/M 2.2 standard BDOS.)
- **`cross_bank_return` trampoline preserves all user-visible registers** — when `EXIT` jumps to the trampoline, registers are in the standard NEXT-time state (BC=TOS, DE=IP, HL=W). The trampoline writes one MMU port, pops the caller's bank from the return stack, and continues NEXT. No EXX needed (the trampoline is a leaf with respect to the EXX rule).
- **Saved-bank cell (S5) is updated only by interactive `BANK!`** — `BANK!` from inside a colon definition does NOT update the saved-bank cell; only top-level interactive `BANK!` from the outermost interpret loop does. This is what makes `IN-BANK`'s nested save/restore work correctly under QUIT bank-restore (the saved-bank cell still reflects the user's last interactive choice).

### Process Patterns (Phase-4-specific)

**S1–S12 standing commitments carry forward unchanged** (per project-lead direction 2026-05-10: no S13+ proposals). Codified as NFR-P4-28..39. Each Phase-4 retro re-walks the relevant subset.

**Per-bank hardware-smoke discipline (NFR-P4-11 / S9).** Every binary-delta Phase-4 story runs on **three test surfaces**:
1. **iz-cpm** — non-banking regression baseline (the existing 974-test suite continues passing under the banked binary running flat-mode tests)
2. **Banking-capable emulator** (Epic 16.3 vendor pick) — cross-bank assertions
3. **Real MicroBeast** — load-bearing final word (S9 standing commitment)

All three surfaces must PASS for any binary-delta story. Zero-binary-delta stories document their S9 exemption explicitly.

**Per-epic prework-gate review.** Epic 16 prework (memory map + emulator pick + doc lock) blocks Epic 17 onward. Explicit gate-state check at Epic 17 kickoff: confirm Story 16.3 closed (vendor selected and integrated into `make test-repl-banking` or equivalent), confirm CCP-eviction policy verified on real CP/M 2.2 (see Finding F3), confirm doc lock (this document) signed off.

**Architecture-stage open questions captured as `TODO(P4-arch)` markers** in this document, not as PRD-blockers. Six open questions from `docs/antforth-banking-redesign.md` §9 are owned by Epic-16 spike stories:
- §9.1 CODE-words-in-banks (S7 dispatch implication)
- §9.2 banking-capable emulator vendor pick (Epic 16.3 — explicit prework gate)
- §9.3 CL parser edge cases
- §9.4 bank-state-table cap (29 entries) ABORT policy
- §9.5 stub size (3 vs 4–5 bytes)
- §9.6 recursive cross-bank R-stack overflow (documented gotcha vs runtime guard)
- §9.7 flat-build semantics — **CLOSED 2026-05-10** as non-MVP for Phase 4 (per project-lead direction)

**Carry-forward Phase-3 process additions** that survive into Phase 4:
- Probe-authoring discipline (S12 / word-existence pre-flight + TIB-128 line-length lint) — unchanged
- "Mirrors prior arm" HALT signal (B.2) — unchanged; fires on byte-budget rationale containing "mirrors", "same shape as", or any "Story Y" reference in a byte-budget paragraph
- PD-2 figure-drift discipline (B.4) — unchanged; figures, tables, code blocks validated against source-of-truth at draft time
- `wc -c` real-baseline capture (B.3) — unchanged; pre-edit baseline never inherited from prior story
- Story-template lints (B.2–B.5) fire automatically — unchanged
- Pre-fix negative-result confirmation (A.1-D3) — unchanged where Phase 4 ships a behavioural fix; banking-feature stories use the standard AC-positive-path-PASS pattern instead

### Enforcement Guidelines

**All Phase-4 dev-pass agents MUST:**

1. Author compliance-doc rows in CCD-P3-1's 6-column format — no shorthand, no row-format drift
2. Use the A.1-D3 back-fill story shape verbatim — six steps, including pre-fix negative-result confirmation
3. Land workflow-file edits in their designated files (CCD-P3-2 mapping) — never inline in transcripts, never in memory entries, never in `feedback_*.md` (those document *why*, not *enforcement*)
4. Pass the S12 probe-authoring pre-flight (word-existence + TIB-128) before committing any hardware-typed probe
5. Default to PAD for transient-buffer needs in REPL-piped probes; ALLOT for cross-parse buffers; never write near HERE
6. Run S9 hardware-smoke per binary-delta story; document exemption explicitly for zero-binary-delta stories
7. Honour S5 PARTIAL→HALT — any AC not fully PASS triggers HALT in-pass; root-cause is handled in-pass or the story spawns a sibling
8. Honour S8 — "pre-existing" cannot discharge correctness defects (clobbers, lost writes, silent error swallowing); surface, file, fix
9. Re-`wc -c` at the start of every dev-pass — never inherit the prior story's reported binary size

**Pattern enforcement mechanisms:**

- **Structural lints** in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (B.2/B.4 `<critical>` blocks) catch drafting-discipline gaps at draft time
- **Pre-edit baseline tasks** in the story template (B.3) catch binary-handoff drift at dev-pass start
- **`make check-doc-sync`** (B.5) catches PRD-vs-architecture drift at any time the maintainer runs it
- **`make check-tools`** (B.6) catches host-toolchain drift at any time the contributor runs it
- **S9 hardware smoke per binary-delta story** catches kernel-regression at dev-pass close
- **S11 user-visible version surface audit** (NFR-P4-38) catches version-banner drift at tag close-out
- **Adversarial code review (`/CR`)** post-PD-1 fresh-context — eleven-plus consecutive epic finding-rate held; catches whatever the structural lints don't

### Concrete Examples

**Good — compliance-doc row:**

```markdown
| §6.1.1561 | `FM/MOD: ( d1 n1 -- n2 n3 )` floored division: signed double / signed single → signed remainder, signed quotient | Implemented | src/double.asm:480 | Story 10.6 | quotient rounds toward -∞; remainder sign matches divisor |
```

**Bad — compliance-doc row (anti-pattern):**

```markdown
| 6.1.1561 | FM/MOD | yes | double.asm | E10 | works |
```

(Missing § prefix and standard cite, missing rule text, non-canonical verdict, relative path, ambiguous closure label, vacuous notes.)

**Good — Phase-4 banking-feature story shape (skeleton):**

```markdown
### Story 17.X: Implement BANK! with probe-and-ABORT semantics

**Wordset row** (banking-redesign §1):
| `BANK!` | `( n -- )` | Switch logical bank. `ABORT" bank?"` if `n` is not in the active list. |

**FRs served:** FR-P4-2 (BANK! switches logical bank), FR-P4-2 precondition (ABORT on `n` not in active list), FR-P4-7 (probe-on-add via +BANK validates list membership).

**Files touched:**
- `src/banking.asm` — `BANK!` colon-CFA + ABORT-on-bad-arg path
- `src/wordlists.asm` — bank-table[] lookup helper (callee of BANK! to validate `n`)
- `tests/banking_tests.fth` (NEW) — REPL probes: valid switch, invalid index, switch+restore round-trip

**Test shape:**
1. REPL probe: `: T1 BANK@ 5 BANK! BANK@ 5 = SWAP 0 = AND ;` (round-trip validity)
2. REPL probe: `: T2 ['] BAD-INDEX-BANK CATCH . CR ;` expects negative THROW code (-2 ABORT")
3. Hardware smoke: same probes on iz-cpm + banking-capable emulator + real MicroBeast (per S9)

**Standards citation comment (CCD-3):** `; antforth extension BANK! — see docs/antforth-banking-redesign.md §1`

**Verdict gate:** all three test surfaces PASS; binary-delta within fixed-memory NFR-P4-5 envelope; no regression on Phase-3 974-PASS baseline.
```

**Bad — Phase-4 story shape (anti-pattern):**

```markdown
### Story 17.X: Add BANK!

**AC:**
- AC1: Implement BANK!
- AC2: Tests pass
```

(Missing FR mapping, missing CCD-3 citation, missing test-surface enumeration, no S9 hardware-smoke task, no fixed-memory envelope, no Phase-3-baseline regression statement.)

**Good — `<critical>` workflow edit (file: `instructions.xml`):**

```xml
<critical>
B.2 / Lesson 13.5-C — "mirrors prior arm" HALT signal:

When drafting the byte-budget rationale for a new story, if the rationale text contains any of:
  - "mirrors arm X from Story Y"
  - "same shape as Story Z"
  - any equivalent comparison-to-prior-work shorthand
HALT and itemise the new arm's parts independently before accepting the estimate.

The mirror analogy is a red flag, not a justification. (TD-7 / Story 13.5.5 overshot pick (a) +50..+100 by 40 bytes via this exact shorthand.)
</critical>
```

**Bad — workflow edit (anti-pattern):**

In a memory entry `feedback_no_mirror_shorthand.md`:
> Don't use "mirrors prior arm" without itemising the parts.

(Lives in the *why* surface, not the *enforcement* surface. Drafter has to remember to invoke it. CCD-P3-2 / S10 violation.)

**Good — probe transient buffer:**

```forth
\ Test: PAD-based transient buffer (B.1 canonical idiom)
: T-PROBE-PAD
  PAD 64 ERASE
  S" hello" PAD SWAP CMOVE
  PAD C@ 'h' = ;
```

**Bad — probe transient buffer:**

```forth
\ Anti-pattern: HERE-based transient buffer (Story 13.5.1 collision)
: T-PROBE-HERE
  HERE 64 ERASE
  S" hello" HERE SWAP CMOVE   \ S" allocates near HERE — collision!
  HERE C@ 'h' = ;
```

## Project Structure & Boundaries

> **Phase-2 / Phase-3 carry-forward.** The full project directory structure from the phase-2 + phase-3 architecture documents carries forward unchanged. Phase 4 does not restructure the codebase — it adds one new kernel file (`src/banking.asm`) and extends a focused set of existing ones. This section enumerates only the **Phase-4 file-touch surface**.

### Phase-4 File-Touch Surface

#### New files created in Phase 4

| Path | Purpose | Epic |
|---|---|---|
| `src/banking.asm` | NEW kernel file — descriptor-stub allocator, sentinel-trampoline cross-bank EXIT, MMU port wrappers, `bank-table[]` allocator, `BANK!` swap routine, the 12 banking words' assembly bodies, `cross_bank_return` trampoline | Epic 17 / 18 |
| `tests/banking_tests.fth` | NEW REPL-probe harness — probes for the 12 wordset words + cross-bank dispatch round-trip + ABORT-bank-restore + boot-config edge cases; per-probe annotation of which emulator surface (banking-capable / iz-cpm / hardware) the probe targets | Epic 17–22 |
| `_bmad-output/implementation-artifacts/<epic>-retro-<date>.md` | Phase-4 retrospective(s) at each epic close-out (one per epic, 16–22) | per-epic |
| `_bmad-output/implementation-artifacts/<story>-<slug>.md` | Per-story dev-notes for any story that needs them | per-story |

`src/banking.asm` follows the existing per-subsystem-file convention (`src/exception.asm`, `src/file_access.asm`, etc.) — one file per subsystem, kernel-resident, hard-coded.

#### Existing files modified in Phase 4

| Path | Changes | Epic |
|---|---|---|
| `src/inner_interpreter.asm` | Extend `w_EXIT_cf:` with sentinel-comparison branch (intra-bank zero-overhead path preserved); extend `w_EXECUTE_cf:` to dispatch through descriptor stub | Epic 18 |
| `src/compiler.asm` | Extend `w_COMPILE_COMMA_cf:` to emit stub address (always); extend `w_COLON_cf:` to allocate descriptor stub on `:` and link the stub address as the new word's xt | Epic 18 / 19 |
| `src/dictionary.asm` | Extend `w_FIND_cf:` with per-wordlist `bank` field check; save current bank, switch to wordlist's bank only if non-fixed, walk chain, restore; extend wordlist-header layout with `bank` field; extend MARKER/FORGET to track per-bank dictionary tail | Epic 19 / 20 / 21 |
| `src/wordlists.asm` | Extend wordlist creation to default new wordlists' `bank` field to current bank; tag system wordlists (FORTH, ASSEMBLER) `bank=fixed` (-1) at kernel build time; extend `w_WORDS_cf` to traverse banks per wordlist's `bank` field | Epic 20 |
| `src/memory.asm` | Extend `w_HERE_cf:` and `w_LATEST_cf:` (and the `,` / `C,` family) to read/write per-bank state from `bank-table[]` instead of from a single global cell | Epic 19 |
| `src/system.asm` | Extend `w_ABORT_cf:` (and `w_ABORT_QUOTE_cf:`) so the unwind path leaves the saved-bank cell intact for QUIT to re-assert; update CCP-eviction memory-map declaration ($D400–$DBFF reclaimed for stub allocator) | Epic 18 / 21 |
| `src/outer_interpreter.asm` | Extend `w_QUIT_cf:` to re-assert the saved-bank cell on re-entry; extend the outermost interpret-loop `BANK!` recogniser to update the saved-bank cell | Epic 21 |
| `src/exception.asm` | Verify the `.throw_uncaught` recovery chain interacts correctly with cross-bank frames; no functional change expected (the trampoline restores caller's bank before EXIT, so uncaught THROW unwind is a recursive sentinel-trampoline walk) | Epic 21 (verification) |
| `src/antforth.asm` | Add CL-tail parser invoked early in boot (FR-P4-34..38); update banner string to include active-bank count (FR-P4-37); auto-`BANK-MAPPING-ON` in COLD; update banner for each Phase-4 antforth 3.x point-release (S11 / NFR-P4-38) | Epic 17 / every tag |
| `src/structures.asm` | Add UserArea cells: `saved-bank`, `current-bank`, `bank-table-base`, `bank-mapping-state` | Epic 17 |
| `docs/ans-forth-core-compliance.md` | Add 12 rows for the banking words flagged as antforth extensions per CCD-3 / CCD-P3-1; `Source` column points to `docs/antforth-banking-redesign.md`; `Verdict` is `Implemented (antforth extension)`; `Closure` per Phase-4 story | Epic 17–22 |
| `README.md` | Update version reference for each Phase-4 antforth 3.x point-release (S11 / NFR-P4-38) | every tag |
| `memory/project_phase2_scope.md` (or successor `project_phase3_scope.md` / `project_phase4_scope.md`) | Update `description` fields citing antforth version at each tag close-out (S11 / NFR-P4-38) | every tag |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | Story status updates per Phase-4 dev-pass close | every story |
| `Makefile` | Add `make test-repl-banking` target (or equivalent) per Epic 16.3 vendor pick; per-probe surface annotation supported | Epic 16 / 17 |

#### Files SUPERSEDED / not consumed in Phase 4

| Path | Reason |
|---|---|
| `docs/antforth-banking-design.md` | SUPERSEDED — the obsolete 2026-05-07 sketch with the broken `BIT 7,H` heuristic and `THUNK-TO-USER-BANKn` family; banner-marked SUPERSEDED; preserved only for design-evolution traceability |
| `docs/PHASE-3-CARRY-FORWARD.md` | CLOSED — the prioritised Phase-3 catalog; all 12 P1 items closed at Phase-3 close-out 2026-05-09 |

#### Files explicitly NOT touched in Phase 4

| Path | Reason |
|---|---|
| `src/assembler.asm` | Per `project_assembler_keep_assembly.md` — assembler stays kernel-resident hard-coded; CODE-words-in-banks decision (open question §9.1) does not require assembler changes — the question is about whether user CODE words can land in banks, not about restructuring the assembler kernel |
| `src/file_access.asm` | File-access subsystem complete post-Epic-13.5; banking doesn't change BDOS call semantics (BDOS lives in fixed memory; PD-P4-6) |
| `src/strings.asm` | Phase-3 close-out (post-A.3); no Phase-4 changes expected |
| `src/hash.asm`, `src/control_flow.asm`, `src/io.asm`, `src/arithmetic.asm`, `src/logic.asm`, `src/stack_ops.asm`, `src/double.asm`, `src/pictured.asm`, `src/formatting.asm`, `src/number_prefixes.asm`, `src/bootstrap.asm`, `src/macros.asm`, `src/constants.asm` | Phase-1/2 subsystems frozen for Phase 4 — the descriptor-stub mechanism (PD-P4-1) means these don't need internal-banking awareness; cross-bank dispatch is handled at the `EXIT` / `EXECUTE` / `COMPILE,` chokepoints |
| `disk/`, `build/`, `examples/`, `blog/`, `images/`, `reference_docs/`, `node_modules/` | No Phase-4 surface |

### Architectural Boundaries

**Kernel boundary (Phase 4 — banking subsystem additions):**

The Z80 assembly kernel surface adds `src/banking.asm` (NEW) for the descriptor-stub mechanism, sentinel-trampoline EXIT, MMU port wrappers, and the 12 banking-word bodies. Existing kernel files extended at narrow chokepoints: `src/dictionary.asm` / `src/memory.asm` (per-bank `(here, latest, wordlist-heads)` triple), `src/wordlists.asm` (per-wordlist `bank` field on FIND), `src/inner_interpreter.asm` (cross-bank EXIT + EXECUTE switch), `src/compiler.asm` (per-bank `COMPILE,`), `src/system.asm` / `src/exception.asm` (QUIT bank-restore), `src/antforth.asm` (CL parser, banner). The Phase-1/2/3 binary baseline is preserved as a starting point; Phase-4 binary growth is dominated by descriptor-stub allocation + the new banking subsystem (~6 KB worst case at default 12 banks per NFR-P4-5).

**Test-harness boundary:**

Tests are REPL-piped Forth scripts in `tests/*.fth` (per S2). Phase 4 adds a new test file:
- `tests/banking_tests.fth` (NEW) — REPL probes for the 12 banking words, cross-bank dispatch, ABORT-bank-restore, boot-config edge cases
- Hardware-smoke probes for the banking-capable emulator + real MicroBeast (per S9 + per Phase-4 three-test-surface discipline)
- Existing test files extended for any banked-mode regression coverage

Test surface expands from 1 (iz-cpm) to 3 (iz-cpm + banking-capable emulator + real MicroBeast) for binary-delta stories; Epic 16.3 emulator pick gates this expansion.

**Documentation boundary:**

- **Standards-compliance doc** (`docs/ans-forth-core-compliance.md`) — Phase 4 adds 12 rows for the banking words (flagged as antforth extensions per CCD-P3-1 row schema). Row format unchanged. NFR-P4-17 row-checkability holds.
- **Banking design doc** (`docs/antforth-banking-redesign.md`) — locked source of truth for Phase 4 architectural decisions; superseded `docs/antforth-banking-design.md` (banner-marked).
- **Phase-3 catalog** (`docs/PHASE-3-CARRY-FORWARD.md`) — closed; historical reference only.
- **Test-author guidance** (`tests/README.md`) — already exists from Phase 3 (B.1); Phase 4 may extend with banking-specific probe conventions.
- **`docs/dev_journal.md`** — engineering log; touched by author at his discretion, not architecturally pinned.

**Tooling boundary:**

- **Makefile** is the build and test orchestrator; Phase-4 adds a banking-build target (likely `make test-repl-banked` or extension to the existing `test-repl` target with EMULATOR variable selection); the iz-cpm-only path is preserved for the existing 974-PASS baseline.
- **`.tool-versions`** — Phase 4 adds an entry for the banking-capable emulator vendor (Epic 16.3 outcome).
- **`tools/check-doc-sync/`** — already exists from Phase 3 (B.5); Phase 4 may extend to cover the architecture-vs-banking-redesign-doc drift case.
- The Phase-3-specific `tools/` additions are complete; Phase 4 does not create new `tools/` directories unless emulator integration requires one.

**Workflow-file boundary (BMAD enforcement surface, per CCD-P3-2):**

- The four BMAD workflow files (`_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`, `_bmad/bmm/workflows/4-implementation/create-story/template.md`, `_bmad/bmm/workflows/4-implementation/create-story/checklist.md`, `_bmad/bmm/agents/dev.md`, `_bmad/bmm/agents/sm.md`) carry forward unchanged from Phase 3. Phase 4 may extend them only if a Phase-4-specific workflow gap surfaces (e.g., a banked-mode test-cadence task). No expected touches per the current epic outline.
- CCD-P3-2 (process discipline lives in workflow files) carries forward.

### Requirements-to-Structure Mapping

| Phase-4 epic | Touches |
|---|---|
| **Epic 16 — Memory map & doc lock** | `docs/antforth-banking-redesign.md` (already landed); `docs/antforth-banking-design.md` SUPERSEDED banner; emulator-vendor research notes (Epic 16.3); CCP-eviction verification on real hardware |
| **Epic 17 — Bank primitives + CL config** | `src/banking.asm` (NEW — 12 wordset words bodies + MMU port wrappers + probe-on-add); `src/antforth.asm` (CL parser, banner update); `tests/banking_tests.fth` (NEW — wordset probes); banking-capable emulator integration |
| **Epic 18 — Stub mechanism (γ) + cross-bank EXIT (S1 b)** | `src/banking.asm` (descriptor-stub layout + sentinel-trampoline `cross_bank_return`); `src/inner_interpreter.asm` (`EXIT` sentinel detection, `EXECUTE` switch); `BANK-OF` + `IN-BANK` wordset bodies in `src/banking.asm`; `tests/banking_tests.fth` (cross-bank dispatch probes) |
| **Epic 19 — Bank-aware compiler** | `src/dictionary.asm` / `src/memory.asm` (per-bank `(here, latest, wordlist-heads)` triple in `bank-table[]`); `src/compiler.asm` (per-bank `,` and `COMPILE,`); `:` body lands in current bank; `CREATE`/`DOES>` cross-bank PFA layout; `tests/banking_tests.fth` (cross-bank `:`/`CREATE` probes) |
| **Epic 20 — Bank-aware FIND + interpreter loop** | `src/wordlists.asm` (per-wordlist `bank` field, FIND saves/switches/walks/restores, system wordlists tagged `bank=fixed`); `src/outer_interpreter.asm` (interpreter-loop bank state); error-message attribution to source bank; `tests/banking_tests.fth` (FIND probes) |
| **Epic 21 — MARKER/FORGET + ABORT/QUIT bank state (S5)** | `src/structures.asm` (per-bank dictionary tail tracking for MARKER); `src/system.asm` / `src/exception.asm` (QUIT re-asserts saved current-bank); `tests/banking_tests.fth` (ABORT-bank-restore probes) |
| **Epic 22 — Polish** | `.BANKS` formatting in `src/banking.asm`; REPL prompt indicator (`src/outer_interpreter.asm`); CODE-words-in-banks decision (Epic-22 spike per `TODO(P4-arch)` §9.1); test-harness sweep |
| **S11 version surface (per-tag)** | `src/antforth.asm` banner; `README.md`; memory `description` fields per tag; `make check-doc-sync` clean-pass |
| **S9 hardware smoke (per binary-delta story)** | Three-test-surface transcripts: iz-cpm + banking-capable emulator + real MicroBeast |

### Integration Points

**Internal communication:**

Phase 4 introduces **two new internal communication paths** beyond the Phase-3 carry-forward set:
1. **Cross-bank dispatch** via descriptor stubs (PD-P4-1) — every `EXECUTE` / `COMPILE,` / `:`-call path now flows through the stub mechanism; same-bank calls add one `JP` overhead, cross-bank calls add ~60 T-states + MMU port-write
2. **Per-bank state swap** (PD-P4-3) — `BANK!` atomically swaps the `(here, latest, wordlist-heads)` triple; FIND, `,`, `COMPILE,`, `:`, `CREATE`, `MARKER`, `FORGET` all read from the current bank's triple

CCD-1 dual-chain frame discipline (CATCH-TOP / INCLUDE-TOP) and CCD-2 THROW code allocation continue to govern cross-subsystem error flow, including across banks (sentinel-trampoline EXIT preserves CATCH frames; `IN-BANK` is CATCH-safe). The ISR invariant (PD-P4-7) holds: no banked code reachable from interrupt vectors.

**External integrations:**

- **CP/M 2.2 BDOS** — function allow-list per NFR-P4-15 unchanged; Phase 4 does not add any new BDOS functions; BDOS calls (`CALL 0005h`) work unchanged from banked code (BDOS at $DC00–$E9FF lives in fixed memory)
- **iz-cpm emulator** — used by `make test-repl` for the existing 974-PASS regression baseline; does NOT support banking; Phase 4 adds dual-track integration with a banking-capable emulator (Epic 16.3 vendor pick)
- **Banking-capable emulator** (Epic 16.3 vendor pick) — used for banked-mode probes; runs alongside iz-cpm; three eval criteria pinned (32-page MMU at ports 0x70+slot/0x74; pipe-able; bank-visibility for tests)
- **sjasmplus assembler** — used by `make` for kernel build; version pinned via `.tool-versions`
- **MicroBeast hardware** — used by S9 hardware smoke for every binary-delta story; transcript binary captured under `~/Downloads/bestialitty-<date>.bin` per established naming
- **GitHub releases** — antforth 3.x point-release tags published as GitHub releases (S11 sibling)

**Data flow (no change from v2.0):**

User Forth source → REPL or `INCLUDE` → outer interpreter → compiler / interpreter → dictionary lookup (multi-vocabulary) → execution. Errors flow through CATCH/THROW per CCD-1; uncaught errors land in the inlined `.throw_uncaught` recovery chain (`src/exception.asm:412+`) and re-enter the REPL with state reset.

### File Organisation Patterns

**Kernel source:** `src/*.asm` — one file per subsystem; Phase 4 adds `src/banking.asm` (NEW) and extends a focused set of existing files (per the File-Touch Surface table).

**Test sources:** `tests/*.fth` — one file per subsystem-or-feature; Phase 4 adds `tests/banking_tests.fth` (NEW).

**Documentation:** Phase 4 modifies `docs/ans-forth-core-compliance.md` (12 banking-word rows as antforth extensions); `docs/antforth-banking-redesign.md` is the locked Phase-4 design source.

**Planning artifacts:** Phase 4 archives the Phase-3 PRD/architecture/epics (`*-phase3-epics-14-15.md`) and writes the Phase-4 PRD, this architecture document, and the Phase-4 epics document.

**Implementation artifacts:** Phase 4 will add per-story dev notes + retrospectives + sprint-status updates as epics ship.

**Tools:** Phase 4 may add `tools/<emulator-vendor>/` if emulator integration requires custom tooling (Epic 16.3 outcome).

### Development Workflow Integration

**Build:** `make` (or `make asm`) → `build/antforth.com`. Unchanged for Phase 4 (binary still builds the same way; banking is internal infrastructure).

**Test:** `make test-repl` → runs the full `tests/*.fth` suite under iz-cpm (the 974-PASS baseline). Phase 4 adds banking-mode probe variants — likely a new `make test-repl-banked` target using the banking-capable emulator (Epic 16.3 outcome). Both must pass for Phase-4 binary-delta stories.

**Doc-sync** (`make check-doc-sync`): unchanged from Phase 3; runs before any tag-applicable close-out.

**Tool-version check** (`make check-tools`): unchanged from Phase 3; Phase 4 adds the banking-capable emulator entry to `.tool-versions`.

**Hardware smoke (S9):** binary copied to MicroBeast via established serial / SD-card path; Phase-4 banking probes typed by hand or piped from a hardware-typed Forth file. Three-test-surface discipline for binary-delta stories.

**Tag close-out (S11):** verdict-table walk; banner / README / memory `description` fields all aligned to the new 3.x version; `make check-doc-sync` clean-pass; full test suite clean across all three test surfaces (iz-cpm + banking-capable emulator + real MicroBeast); hardware smoke clean. Tag applied.

## Architecture Validation Results

### Coherence Validation

**Decision compatibility:** All Phase-4 decisions cohere with the Phase-3 close-out baseline:
- (γ) descriptor stubs (PD-P4-1) sit on top of existing dictionary/EXECUTE chain without restructuring CCD-1 dual-chain discipline or CCD-2 THROW codes
- (S1 b) sentinel-tagged returns (PD-P4-2) extend EXIT path semantics; intra-bank zero-overhead path preserves Phase-1/2/3 EXIT timing exactly
- Per-bank state triple (PD-P4-3) is additive — fixed-memory `bank-table[]` holds per-bank `(here, latest, wordlist-heads)`; the Phase-1/2/3 single-dictionary-pointer model is now bank-0's case
- CCD-1..CCD-4 (Phase-2) carry forward unchanged; CCD-P3-1 / CCD-P3-2 (Phase-3) carry forward unchanged; PD-P4-1..10 are net additions, not overrides
- The "Phase 4 wins → Phase 3 → Phase 2 → Phase 1" precedence chain is transitively correct

**Pattern consistency:** Phase-4 patterns extend Phase-1/2/3 patterns without contradiction. Banking-word naming (BANK@/BANK!) mirrors BASE @/BASE ! idiom; descriptor-stub format is new but localised to the cross-bank dispatch path; sentinel-trampoline format is new but localised to EXIT.

**Structure alignment:** The Phase-4 file-touch surface concentrates in one new file (`src/banking.asm`) plus narrow chokepoint extensions to ~6-8 existing files. No two Phase-4 epics target overlapping kernel sites at the function level (Epic 18 owns EXIT/EXECUTE, Epic 19 owns the compiler, Epic 20 owns FIND, Epic 21 owns ABORT/QUIT — all distinct).

### Requirements Coverage Validation

**Functional Requirements (FR-P4-1..43):**

| Coverage | Status |
|---|---|
| All 43 FR-P4-N requirements map to at least one architectural decision | ✅ verified via the Requirements-to-Structure Mapping table; FR-P4-1..12 (Banking Wordset) → `src/banking.asm`; FR-P4-13..21 (Descriptor stubs + cross-bank EXIT) → PD-P4-1 + PD-P4-2 + Epic 18; FR-P4-22..26 (Bank-Aware Compiler) → PD-P4-3 + Epic 19; FR-P4-27..30 (Bank-Aware FIND) → PD-P4-4 + Epic 20; FR-P4-31..33 (ABORT/QUIT Bank-State) → PD-P4-5 + Epic 21; FR-P4-34..39 (Boot Config) → `src/antforth.asm` CL parser + Epic 17; FR-P4-40..43 (Backward-Compat) → regression discipline + S9 baseline |
| Phase-1/2/3 closed FRs preserved via FR-P4-40..43 (Backward Compatibility & Regression) | ✅ explicit carry-forward statement; banked build is the new normal; existing flat programs run unmodified under banked build |
| All 7 Phase-4 epics have at least one FR mapping | ✅ Epic 16 (prework), Epic 17 (Bank primitives + CL), Epic 18 (Stub + EXIT), Epic 19 (Compiler), Epic 20 (FIND), Epic 21 (MARKER/FORGET + ABORT), Epic 22 (Polish) — all addressed |
| The 6 architecture-stage open questions (banking-redesign §9.1-9.6) are captured as `TODO(P4-arch)` markers | ✅ each owned by an Epic-16 spike story; not PRD-blockers |

**Non-Functional Requirements (NFR-P4-1..39):**

| Coverage | Status |
|---|---|
| Performance NFR-P4-1..7 (Phase-2/3 envelopes + Phase-4 banking budgets) | ✅ per-epic descriptor-stub cost tracked in Decision Impact Analysis; cross-bank ≤60 T-states (NFR-P4-2); banking infra ≤8 KB fixed mem (NFR-P4-5) |
| Reliability NFR-P4-8..11 | ✅ ISR-from-fixed-only invariant (NFR-P4-26); BDOS calls work unchanged from banked code (NFR-P4-27); sentinel-trampoline restores CATCH frames; Phase-3 baseline regression-zero (NFR-P4-10) |
| Compatibility & Standards NFR-P4-12..18 | ✅ banking words as antforth extensions (no new ANS wordset); CCD-P3-1 row schema unchanged (NFR-P4-17); CODE-source-file backward compat (NFR-P4-16) preserved with cross-bank-CODE-words flagged as architecture-stage open question |
| Maintainability NFR-P4-19..22 | ✅ banking inline-comments cite redesign-doc §-numbers per CCD-3 (NFR-P4-20); per-epic point-release decoupling (NFR-P4-21); story-template lints from B.1–B.5 fire automatically (NFR-P4-22) |
| Integration NFR-P4-23..27 | ✅ no new BDOS functions; banked default with flat-build deferred to Phase 5+; ISR invariant; emulator dual-track |
| Process Discipline NFR-P4-28..39 (S1–S12) | ✅ each codified; S1–S12 carry forward unchanged from Phase 3; no S13+ added per project-lead direction 2026-05-10 |

**Cross-cutting concerns coverage:**

| Concern (from § "Cross-Cutting Concerns Identified") | Architectural address |
|---|---|
| §-level compliance documentation (A.1) | CCD-P3-1 (row schema) carries forward; Phase 4 adds 12 banking-word rows as antforth extensions |
| Process discipline as workflow-file edits | CCD-P3-2 carries forward unchanged |
| Standing-commitment hold (S1–S12) | NFR-P4-28..39 codified; verdict-criterion meta-pattern carries forward |
| Backward-compatibility / regression invariants | FR-P4-40..43 + NFR-P4-10 enforced per Phase-4 dev-pass close |
| ROM / fixed-memory budget discipline | NFR-P4-5 + per-epic descriptor-stub envelope table |
| Asm-error THROW code block contiguity | CCD-2 reaffirmation (Phase-3-extended block -258..-272); no Phase-4 additions |

### Findings (genuine issues requiring resolution)

**Per the project's adversarial-review discipline (memory: "reviews MUST find things; zero findings is suspect"), surfacing the following before declaring ready-for-implementation:**

#### F1 — Banking-capable emulator vendor pick is a real prework risk

**Issue:** iz-cpm does not support banking. Phase 4 cannot proceed past Epic 17 onward without dual-track emulator capability. If the emulator pick (Story 16.3) slips, all downstream banking story-writing slips.

**Mitigation:** Explicit Epic 16.3 spike story; three eval criteria pinned (32-page MMU model at ports 0x70+slot/0x74; pipe-able for `make test-repl`-style automation; bank-visibility for tests). Worst-case fallback: Epic 16 stories that don't depend on banking emulation (memory-map docs, CCP eviction policy, doc lock) proceed in parallel; vendor research extends; Epic 17 story-writing slips; the existing 974-test baseline is unaffected on iz-cpm.

**Action:** Story 16.3 spec includes the three eval criteria as ACs; Epic 17 kickoff includes a gate-state check on Story 16.3 closure.

#### F2 — Descriptor-stub cost growth is linear in banked-word count

**Issue:** Stub cost grows linearly: at 1000 words × 5 B/stub = 5 KB; at 2000 words = 10 KB. Current antforth has ~500 user-visible words across all wordlists; the 1000-word target leaves ~5 KB of headroom against NFR-P4-5 (8 KB total banking infrastructure cap), but a future-Phase explosion in banked-word count could blow the cap.

**Mitigation:** Per-epic stub-count metric tracked alongside binary size in CCD-4 close-out. CCP eviction (PD-P4-6) yields +2 KB Page-3 headroom available as buffer. If the metric trends past the cap before Epic 22, sprint-change-proposal evaluation triggers — options include stub-size pinning at 3 bytes (open question §9.5), splitting infrequently-banked words to a separate dispatch path, or accepting the cap as a real-word-count limit.

**Action:** CCD-4 close-out adds a "banked-word stub-count" line item; Epic 22 polish includes a final stub-count + total fixed-memory measurement against the NFR-P4-5 envelope.

#### F3 — CCP eviction policy needs verification on real CP/M 2.2 hardware

**Issue:** PD-P4-6 evicts the CCP at $D400–$DBFF for +2 KB Page-3 headroom. CP/M 2.2's BIOS warm-boot path may expect CCP to be reloadable from disk on warm-boot. If the BIOS reloads CCP from disk, eviction is safe (the BIOS will restore it on the user's next ^C / system reset). If not, the warm-boot path needs a restore mechanism.

**Mitigation:** Epic 16 spike to verify on real MicroBeast: assert that ^C from inside antforth returns to a working CCP prompt (CCP reloaded from disk by BIOS) without crashing or corrupting state. If verification fails, restore-on-warm-boot path needed (small kernel addition; estimated +50 B).

**Action:** Epic 16 includes an explicit CCP-eviction-verification spike before any Phase-4 binary-delta story ships. If the spike surfaces a real failure, restore-on-warm-boot story spawned with a +50 B envelope.

#### F4 — Cross-bank pointer hazard documented but not guarded

**Issue:** Per-bank `HERE` (FR-P4-26) is "doc-and-pray" — user can hold HERE from one bank then `BANK!` to another and write garbage. No runtime guard. A casual user writing their first multi-bank application may hit this without warning.

**Mitigation:** Documented gotcha in user docs (post-Epic-22 user-facing documentation). No runtime guard, consistent with Forth tradition of trusting the programmer (and consistent with the broader "doc-and-pray" disposition locked per redesign §5.4).

**Action:** Epic 22 polish includes a user-docs entry titled "Cross-bank pointer hazards" naming HERE / LATEST / wordlist-head pointers as bank-sensitive; example anti-pattern shown; recommendation is "do all your work in one bank per logical session, swap banks at well-defined boundaries."

#### F5 — Six architecture-stage open questions captured as `TODO(P4-arch)` markers

**Issue:** The redesign-doc §9 lists 7 unresolved questions (item 7 closed as non-MVP per project-lead direction 2026-05-10). The remaining 6 (CODE-words-in-banks §9.1, emulator vendor pick §9.2, CL parser edge cases §9.3, bank-state-table cap §9.4, stub size §9.5, R-stack overflow §9.6) need owners. If they accumulate without spike-story owners, they could block Epic 17 story-writing.

**Mitigation:** Each open question is owned by an Epic-16 spike story (or explicit deferral to a later epic). Captured as `TODO(P4-arch)` markers in this document, not as PRD-blockers.

**Action:** Epic 16 spec includes one spike story per open question (or explicit deferral to a later epic with an Epic-N owner named); architecture document is updated as each spike closes.

#### F6 — Saved-bank-cell semantics "interactive only" needs an unambiguous test

**Issue:** PD-P4-5 (S5) says the saved-bank cell is updated only by interactive `BANK!` from the outermost interpret loop. In practice, the kernel needs to distinguish "I'm executing a colon-definition that called `BANK!`" from "the user typed `BANK!` at the REPL." The standard mechanism is a STATE-aware check (interactive = STATE @ 0=) plus an outer-interpreter-depth check. If the depth check is wrong, an `INCLUDE`d file's `BANK!` call could update the saved cell as if it were interactive.

**Mitigation:** Epic 21 spec explicitly defines the "interactive `BANK!`" recogniser: `STATE @ 0=` AND outer-interpreter-depth = 1 (i.e., not inside an `INCLUDE`). Tests assert that an `INCLUDE`d `.FTH` file's `BANK!` call does NOT update the saved-bank cell.

**Action:** Epic 21 spec includes an "interactive BANK! definition" sub-task; tests cover both the REPL case (saved cell updates) and the INCLUDE case (saved cell does NOT update).

### Gap Analysis

**Critical gaps (block implementation):** none. Findings F1–F6 are actionable in their owning epics without architectural change.

**Important gaps (could improve smoother implementation):**
- The 6 architecture-stage open questions from redesign §9 (CODE-words-in-banks §9.1, CL parser edges §9.3, bank-state-table cap §9.4, stub size §9.5, R-stack overflow §9.6, plus the emulator vendor pick §9.2 which is the explicit prework gate) need spike-story owners. **Mitigation:** Epic 16 prework spec includes one spike story per open question.
- The descriptor-stub allocator's interaction with `MARKER` / `FORGET` is under-specified. When a MARKER is set in bank 5 and the user `MARKER`-rolls back, the stubs allocated in fixed memory for words defined since the MARKER must also be reclaimed. **Mitigation:** Epic 21 spec includes per-bank dictionary tail tracking + per-bank stub-allocator tail tracking; the MARKER stores both tails and FORGET reverts both.
- `NUMBER?` and other words that internally use `,` to compile literals must continue to work cross-bank. **Mitigation:** the per-bank `,` (FR-P4-23) writes to the current bank's HERE; words that use `,` compile into whatever bank they're called from; no special-casing needed.

**Nice-to-have gaps:**
- A `make banking-stub-report` target that prints per-bank stub-count and fixed-memory occupancy. Useful for the per-epic CCD-4 close-out. Could land as an Epic 22 polish item.
- A REPL prompt indicator showing the current bank (e.g., `[5] ok`). Mentioned in Epic 22 scope as optional. Not gating MVP.
- CI integration for `make test-repl-banking` (banking-capable emulator). Out of scope for Phase 4 (no current CI in repo); mention as a Phase-5+ candidate.

### Architecture Completeness Checklist

**Requirements Analysis:**
- [x] Project context thoroughly analyzed (43 FR-P4-N + carry-forward of Phase-1+2+3 closed FRs via FR-P4-40; 39 NFR-P4-N across 6 categories)
- [x] Scale and complexity assessed (low; one new subsystem — banking — with locked design)
- [x] Technical constraints identified (≤8 KB banking infra, ISR-from-fixed-only invariant, BDOS unchanged, 974 PASS / 0 FAIL baseline)
- [x] Cross-cutting concerns mapped (10 concerns, each with architectural address)

**Architectural Decisions:**
- [x] Critical decisions documented (PD-P4-1..10 — descriptor stubs, sentinel-trampoline, per-bank state, bank-aware FIND, ABORT/QUIT restore, CCP eviction, ISR invariant, CL parser, dual-track emulator, Phase-5+ future-proofing)
- [x] CCDs documented (CCD-1..CCD-4 carry-forward; CCD-P3-1, CCD-P3-2 carry-forward; Phase-4 reaffirmations spelled out)
- [x] Integration patterns defined (BDOS unchanged; ISR fixed-memory only; cross-bank dispatch transparent)
- [x] Performance considerations addressed (NFR-P4-1..6 — cross-bank ≤60 T-states, stub ≤5 B, infra ≤8 KB)

**Implementation Patterns:**
- [x] Naming conventions established (BANK@/BANK! mirror BASE @/!, USER- prefix dropped, system wordlists tagged bank=fixed, Greek-letter shorthand format)
- [x] Structure patterns defined (Phase-2/3 carry-forward; Phase-4 banking-naming additions)
- [x] Communication patterns specified (IN-BANK CATCH-safe contract, BANK! precondition checked every call, cross-bank ABI stub-mediated, per-bank state swap atomic)
- [x] Process patterns documented (S1–S12 codified as NFR-P4-28..39 unchanged; per-bank hardware-smoke discipline across three test surfaces; per-epic prework-gate review)

**Project Structure:**
- [x] Phase-4 file-touch surface enumerated (new + modified + SUPERSEDED + NOT-touched tables); src/ paths verified against actual codebase
- [x] Component boundaries established (kernel surgery localised to banking + per-bank state additions)
- [x] Integration points mapped (BDOS allow-list unchanged; dual-track emulator; real hardware load-bearing)
- [x] Requirements-to-structure mapping complete (PD records map every Phase-4 FR group to specific files)

**Validation:**
- [x] Coherence validation complete
- [x] Requirements coverage verified
- [x] Implementation readiness assessed (Epic 16 prework gate outstanding)
- [x] **Findings F1–F6 surfaced and mitigation paths assigned to owning epics**
- [x] Gap analysis completed (critical: 0; important: 3; nice-to-have: 3)

### Architecture Readiness Assessment

- **PRD lock:** ✓ (refilled 2026-05-10 per `docs/antforth-banking-redesign.md`; FR-P4-1..43, NFR-P4-1..39)
- **Design-doc lock:** ✓ (`docs/antforth-banking-redesign.md`, party-mode session 2026-05-09)
- **Architecture lock:** in-progress (this document; last edited 2026-05-10)
- **Prework gate (Epic 16):** ⏳ outstanding — banking-capable emulator vendor pick + memory-map verification + CCP-eviction check
- **Readiness verdict:** **Ready to start Epic 16 prework. NOT ready to start Epic 17 story-writing until prework gate closes** (banking-capable emulator vendor pick is the critical-path item; CCP-eviction verification on real hardware is the second critical-path item).

**Confidence Level:** **High for Epic 16; Medium-High for Epic 17+ pending prework closure.** Bases:
- The redesign doc is locked from a focused party-mode session (2026-05-09); the (γ) descriptor-stub mechanism is endorsed by the project lead.
- All Phase-4 architectural decisions trace to specific redesign-doc §-references; nothing is invented in this architecture document beyond what the redesign locked.
- Phase-3 close-out baseline (974 PASS / 0 FAIL on real hardware; S1–S12 standing-commitment hold) provides a known-good foundation.
- Phase-5+ future-proofing (multitasking, locals, ALLOCATE) confirmed not-painted-into-corner per redesign §8.2.

**Key strengths:**
- The (γ) decision collapses S1 + S6 + S7 into one artifact — single biggest design call simplifies dispatch, EXIT, and COMPILE, simultaneously.
- Sentinel-trampoline cross-bank EXIT preserves the intra-bank zero-overhead path (the common case is unchanged).
- System wordlists tagged `bank=fixed` keep the FIND common case zero-overhead.
- Boot config via CL parser (not STARTUP.FTH) makes bank availability known at banner-print time.
- Dual-track emulator strategy preserves the existing 974-test safety net while enabling cross-bank emulation.

**Areas for future enhancement (Phase-5+):**
- Multitasking (TCB-as-1-byte-bank) — Phase 5 candidate E.2
- Locals wordset (all three styles compatible) — Phase 5+ candidate E.6
- ALLOCATE / per-bank heap (recommended (β)) — Phase 5+
- Flat-build retention for the 12-word `BANK*` set — deferred from Phase-4 MVP per redesign §4
- CODE-words-in-banks decision — open question §9.1; deferred to Epic 22 if Epic 16 spike doesn't pre-resolve

### Implementation Handoff

**Phase-4 epic outline (per `docs/antforth-banking-redesign.md` §8):**

| Epic | Theme | ~Stories | Tag |
|---|---|---|---|
| **16 — Memory map & doc lock (prework)** | H1 memo, page-allocation survey, CCP overwrite policy verification, IM 2 confirmation, doc rewrite (closed by redesign doc); 16.3 = banking-capable emulator vendor selection | 3–4 | antforth 3.0.x |
| **17 — Bank primitives + CL config** | All 12 wordset words; `+BANK`/`-BANK`/`BANKS-CLEAR`; CL parser; probe-on-add; banner update; first iron spike for cross-bank call | 5–6 | antforth 3.x |
| **18 — Stub mechanism (γ) + cross-bank EXIT (S1 b)** | Per-word descriptor stubs; sentinel-trampoline return; kernel `EXECUTE` switch; `BANK-OF`; kernel-blessed `IN-BANK` | 4–5 | antforth 3.x |
| **19 — Bank-aware compiler** | Per-bank `(here, latest, wordlist-heads)`; `,` / `COMPILE,` writing into target bank; `:` lands body in current bank; stub auto-emitted; `CREATE`/`DOES>` cross-bank explicit | 4–5 | antforth 3.x |
| **20 — Bank-aware FIND + interpreter loop** | Per-wordlist `bank` field; `FIND` traversal; `WORDS`; error messages name source bank | 3–4 | antforth 3.x |
| **21 — `MARKER`/`FORGET` + ABORT/QUIT bank state (S5)** | Per-bank dictionary tail tracking; saved-bank restore on `ABORT` | 2–3 | antforth 3.x |
| **22 — Polish** | `.BANKS`; REPL prompt indicator; CODE-words-in-banks decision; test-harness sweep across all three test surfaces | 3–4 | antforth 3.x (Phase-4 close-out) |

**Per-epic shape:**
- Each epic ships an antforth 3.x point-release.
- Per-epic prework-gate review at kickoff (Epic 17+ explicitly checks Epic 16.3 closure).
- S1–S12 standing commitments hold across every epic close-out (codified as NFR-P4-28..39).
- CCD-4 per-epic benchmark gate: close-out validates NFR envelopes + tracks banked-word stub-count metric alongside binary size.
- Phase-5+ shape (multitasking, locals, ALLOCATE) confirmed not-painted-into-corner per `docs/antforth-banking-redesign.md` §8.2.

**AI Agent Guidelines:**

- Follow all Phase-4 architectural decisions exactly as documented in this document; where Phase-4 is silent, consult `architecture-phase3-epics-14-15.md`; where Phase-3 is silent, consult `architecture-phase2-epics-9-13.5.md`; where Phase-2 is silent, consult `architecture-phase1-epics-1-8.md`
- Use Phase-4 implementation patterns consistently (banking-word naming, descriptor-stub layout, sentinel-trampoline contract, per-bank state-swap idiom, ISR-from-fixed-only invariant, dual-track emulator surface annotation per probe)
- Respect the Epic 16 prework gate — Epic 17+ story-writing blocks on Story 16.3 closure (banking-capable emulator vendor pick) and CCP-eviction verification (Finding F3)
- Honour S1–S12 standing commitments codified as NFR-P4-28..39; per-bank hardware-smoke runs on three test surfaces (iz-cpm + banking-capable emulator + real MicroBeast)
- Address findings F1–F6 in their owning epics' specs (F1 + F5 owned by Epic 16; F2 owned by every binary-delta epic via CCD-4; F3 owned by Epic 16; F4 owned by Epic 22 user-docs; F6 owned by Epic 21)
- Refer to this document for all Phase-4 architectural questions; do not improvise
- For the 6 open questions captured as `TODO(P4-arch)` markers (CODE-words-in-banks §9.1, CL parser edges §9.3, bank-state-table cap §9.4, stub size §9.5, R-stack overflow §9.6, plus emulator vendor pick §9.2), check the relevant Epic 16 spike story before drafting against an unresolved question

**First Implementation Priority:**

Epic 16 prework lands first. Recommended sequencing within Epic 16:

1. **Story 16.1** — Memory map + page-allocation survey + CCP eviction policy declaration (`src/antforth.asm` memory-map declaration)
2. **Story 16.2** — Banking-capable emulator vendor research (writeup; not the integration)
3. **Story 16.3** — Banking-capable emulator vendor pick + integration into `make test-repl-banking` target (the Phase-4 prework gate)
4. **Story 16.4** — CCP-eviction verification on real CP/M 2.2 / MicroBeast (Finding F3); IM 2 confirmation; spike stories for the 6 architecture-stage open questions

After Epic 16 closes, **Epic 17 (bank primitives + CL config)** is the strategic-body kickoff. Epic 18 (stub mechanism (γ)) follows once Epic 17's primitives are in. Epics 19, 20, 21, 22 follow in dependency order per the redesign-doc §8 epic sequence.
