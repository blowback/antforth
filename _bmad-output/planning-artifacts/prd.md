---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
lastEdited: '2026-05-10'
editHistory:
  - date: '2026-05-10'
    changes: 'Phase-4 refill — banking scope per docs/antforth-banking-redesign.md'
classification:
  projectType: developer_tool_embedded
  domain: general
  complexity: low
  projectContext: brownfield
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - _bmad-output/planning-artifacts/prd-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/prd-phase3-epics-14-15.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md
  - _bmad-output/implementation-artifacts/epic-14-retro-2026-05-09.md
  - _bmad-output/implementation-artifacts/epic-15-retro-2026-05-09.md
  - docs/PHASE-3-CARRY-FORWARD.md
  - docs/antforth-banking-redesign.md
  - docs/WISHLIST.md
  - docs/ans-forth-core-compliance.md
  - docs/z80_forth_assemblers.md
  - docs/register-conventions.md
  - docs/throw-codes.md
documentCounts:
  briefCount: 1
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 13
workflowType: 'prd'
---

# Product Requirements Document - antforth

**Author:** Ant
**Date:** 2026-05-10
**Phase:** 4 — banked-RAM enablement

## Executive Summary

antforth is an ANS-compliant Forth interpreter and interactive development environment built from scratch in Z80 assembly for the MicroBeast retrocomputer (8 MHz Z80, 512K banked RAM/ROM, CP/M 2.2). **antforth 2.0 shipped 2026-05-07** (git tag `v2.0.0` on commit `6599d73`); **Phase 3 closed 2026-05-09** as a debt-cleanup interlude — §-by-§ ANS Core + Core-Extension audit complete, story-template discipline locked in, 974 PASS / 0 FAIL baseline (with two B-7/B-9 hardware-load-bearing probes PASSing on real MicroBeast), all 12 P1 carry-forward items closed.

This PRD scopes **Phase 4** — **banked-RAM enablement**, the first net-new feature phase since v2.0. Phase 4 lifts the ~25 KB binary ceiling that has constrained antforth's growth since Epic 10 by giving user code direct access to the MicroBeast's 512 KB banked RAM through a 12-word `BANK*` wordset. Phase 4 ships **antforth 3.x** point-releases, one per epic close-out.

The locked design (`docs/antforth-banking-redesign.md`, 2026-05-09 party-mode session) is built on three architectural calls:

1. **(γ) Per-word descriptor stubs in fixed memory.** Every banked word, when defined, gets a 3–5-byte stub in fixed memory carrying `(target_bank, target_addr_in_bank)`. The stub's address *is* the word's xt. This collapses cross-bank `EXIT`, `EXECUTE`, and `COMPILE,` into one artifact.
2. **(b) Sentinel-trampoline cross-bank EXIT.** Intra-bank returns push 1 cell (zero overhead). Cross-bank returns push three cells `(sentinel_addr, caller_bank, target_addr)`; a `cross_bank_return` trampoline in fixed memory restores the caller's bank then jumps. Replaces the `BIT 7,H` heuristic from the 2026-05-07 sketch (broken because user code at $8000–$BFFF always sets bit 7).
3. **Compiler-emitted, transparent dispatch.** The user types `5 BANK!` then defines and calls words like always — banked `:` is indistinguishable from flat `:`. The user-typed `THUNK-TO-USER-BANKn` family from the obsolete sketch is **deleted**.

The 12-word wordset is `BANK@ BANK! BANKS IN-BANK BANK-OF .BANKS +BANK -BANK BANKS-CLEAR SET-BANK BANK-MAPPING-ON BANK-MAPPING-OFF`. **Default 12 banks × 16 KB = 192 KB user RAM**; **theoretical max 29 banks × 16 KB = 464 KB** (sacrificing the virtual-console buffer and RAM disk). CCP eviction yields **+2 KB Page-3 headroom**. Boot configuration is command-line-driven (`antforth 24 35-3f`); `STARTUP.FTH` was rejected as the configuration mechanism because bank availability must be known at banner-print time.

Phase 4 is structured as **7 epics (16–22)** spanning 25–30 stories, opened by an Epic-16 prework gate (banking-capable emulator vendor selection — iz-cpm does not bank — running dual-track with iz-cpm so the Phase-3 close-out test baseline continues passing). The phase concludes when all 7 epics ship, the banked build runs the full Phase-3 close-out test baseline clean on real hardware, and the 12-word `BANK*` surface passes its own hardware-typed acceptance probes.

### What Makes This Special

Three things distinguish this phase:

- **First feature phase since v2.0; first net-new wordset since the File-Access work in Epic 13.** Phase 3 was a deliberate debt-cleanup interlude (project-lead direction at the Epic 13.5 retro: *"I am trying to clear the decks of baggage, before we embark on new features"*). Phase 4 returns to feature work against a §-level-defensible, process-discipline-locked baseline.
- **Compiler-transparent banking.** Existing programs run unmodified. The user does not type thunk words, does not annotate cross-bank calls, does not see banking semantics in source. Cross-bank dispatch happens at the stub layer the compiler always emits. This is the (γ) decision's payoff.
- **Future-proofed against multitasking, locals, and ALLOCATE.** The 2026-05-09 design session walked the implications of banking against three downstream-Phase candidates and confirmed no corners painted: bank-as-1-byte-of-TCB rides preemption cleanly (Phase 5); locals styles all compatible; ALLOCATE recommended as per-bank heap (β) when the day comes.

The north-star acceptance criterion: *"banked `:` is indistinguishable from flat `:` from the user's vantage; existing programs run unmodified; the ~25 KB binary ceiling no longer constrains user code."*

## Project Classification

- **Project Type:** `developer_tool_embedded` — a programming-language implementation (Forth, a developer tool) targeting embedded 8-bit hardware (MicroBeast Z80 retrocomputer + CP/M 2.2). Generic SDK signals (package managers, IDE integration, OTA updates) do not apply: the `.COM` file IS the package, the REPL IS the IDE, updates are delivered by copying a new `.COM` file to a CP/M drive.
- **Domain:** `general` — hobbyist / retrocomputing personal-learning project. No regulated industry, no external compliance regime; the ANS Forth 1994 / Forth 2014 standards are voluntary self-discipline targets, not external-compliance requirements.
- **Complexity:** `low` — single-developer, well-understood scope, no novel-technology risk, no external-stakeholder dependencies, no deadline pressure. Technical intricacy lives in Z80 assembly minutiae and the banking dispatch / compiler / FIND interactions, not systemic complexity. Phase 4 introduces one new subsystem (banked-RAM enablement) with locked design (`docs/antforth-banking-redesign.md`).
- **Project Context:** `brownfield` — Phase 1 (Epics 1–8), Phase 2 (Epics 9–13.5), and Phase 3 (Epics 14–15) shipped; v2.0.0 tagged 2026-05-07 on commit `6599d73`; Phase 3 closed 2026-05-09 with the 974 PASS / 0 FAIL baseline. This PRD scopes Phase 4 — the first feature phase since v2.0 — building on the v2.0 + Phase-3 foundation with strict regression discipline (974 PASS / 0 FAIL baseline; per-story hardware-smoke discipline per S9; dual-track emulator strategy for the Phase-4 prework gate).

## Success Criteria

### User Success

Phase 4 is the first feature phase since v2.0. User-facing wins centre on memory ceiling lift and transparent banked dispatch.

**For "The OG" (experienced retrocomputing enthusiast):**

- After `5 BANK!`, the user defines and calls words like always. Banked `:` is indistinguishable from flat `:` — no thunk words, no per-call annotation, existing program text runs unmodified.
- `IN-BANK ( n xt -- )` provides scoped bank execution: switch to bank `n`, run `xt`, restore the caller's bank on exit. Throwing inside `xt` still restores the caller's bank (CATCH-safe).
- `BANK-OF ( xt -- n )` returns the bank a word lives in (`-1` for fixed memory) — useful for debugging cross-bank dependencies.
- `+BANK ( page -- )` / `-BANK ( page -- )` / `BANKS-CLEAR ( -- )` allow runtime configuration of which physical pages are in the active list. `+BANK` probes the page on add and rejects ROM / unmapped pages with `ABORT`.
- `.BANKS ( -- )` prints a status table (logical bank index, physical page, current marker, used/free per bank, total).
- Boot-time configuration via command-line: `antforth 24 35-3f` selects portal page 0x24 and banks 0x35..0x3F. Defaults to `22 35-3F` when absent.

**For "The Newb" (newcomer to retrocomputing):**

- All Phase-1+2+3 user-visible behaviour continues to work identically under the banked build — numeric literal prefixes including `0x`, REPL survivability across errors, multi-vocabulary search order, INCLUDE / SAVE-SOURCE on B: ramdisk, hard-coded Z80 assembler.
- The boot banner shows the bank count so a newcomer knows immediately that the machine has more than ~25 KB of user RAM available.

**For the Hardware / Peripheral Developer (secondary persona):**

- ISR bodies still live in fixed memory only. BDOS calls (`CALL 0005h`) work unchanged from banked code. Hardware integration patterns from Phase-1+2+3 carry forward.

### Business Success

N/A — antforth is a hobby / learning project with no commercial objectives. Equivalent non-commercial framing for Phase 4:

- **Capability ceiling lifted.** Phase 4 demonstrates antforth can grow past the ~25 KB binary ceiling without sacrificing the core wordset or the built-in Z80 assembler. The CCP-eviction policy yields +2 KB Page-3 headroom for kernel-side growth in addition to the 192 KB user RAM the default 12 banks provide.
- **Foundation for Phase 5 (multitasking).** The 2026-05-09 design session future-proofed banking against multitasking, locals, and ALLOCATE. Banking arrives without painted corners — Phase 5 inherits a TCB-as-1-byte-bank-context-plus-stacks model directly.
- **External-visibility narrative.** The "antforth 3.x — banked builds available" announcement is itself a community-signal-positive event after the Phase-3 maintenance window. Hobbyist-Forth readers see a Z80 implementation with working banked memory under standard ANS dispatch — uncommon in the Z80 Forth space.

### Technical Success

All items below are hard, verifiable acceptance criteria for the phase.

**Banking capability:**

- 12-word `BANK*` wordset (`BANK@ BANK! BANKS IN-BANK BANK-OF .BANKS +BANK -BANK BANKS-CLEAR SET-BANK BANK-MAPPING-ON BANK-MAPPING-OFF`) shipped with documented stack effects and ABORT semantics for invalid arguments.
- Per-word descriptor stub mechanism (γ): every banked word has a 3–5-byte fixed-memory stub carrying `(target_bank, target_addr_in_bank)`; the stub's address is the word's xt.
- Sentinel-trampoline cross-bank EXIT (S1 b): intra-bank zero-overhead path; cross-bank returns push three cells and resolve through a fixed-memory `cross_bank_return` trampoline.
- Bank-aware compiler: per-bank `(here, latest, wordlist-heads)` triple in fixed-memory `bank-table[]`, swapped on `BANK!`. `,` and `COMPILE,` write into the target bank. `:` body lands in the current bank. `CREATE` / `DOES>` cross-bank explicit (PFA stores doer-stub address + data cell).
- Bank-aware FIND: per-wordlist `bank` field. `FIND` saves current bank, switches to wordlist's bank, walks the chain, restores. System wordlists (FORTH, ASSEMBLER) tagged `bank=fixed` so the common case incurs no MMU switch.
- ABORT/QUIT bank-state restore: `QUIT` re-asserts the saved current bank — the last value set by interactive `BANK!` from the outermost interpret loop. `ABORT` mid-execution does not strand the user in the wrong bank.
- Boot configuration: command-line parser accepts `antforth <portal-page> <bank-list>` (e.g. `antforth 24 35-3f`); defaults to `22 35-3F`; `+BANK` probes pages on add; banner shows bank count; bad pages produce one-line warnings.

**Performance / memory budget:**

- Cross-bank call overhead ≤60 T-states + bank-switch time.
- Per-banked-word descriptor stub ≤5 bytes.
- Banking infrastructure ≤8 KB fixed memory worst case (~6 KB at default 12 banks; ~7–8 KB at 28-bank cap).
- Default 12 banks × 16 KB = 192 KB user RAM; theoretical max 29 banks × 16 KB = 464 KB.

**Invariants preserved:**

- ISR-from-fixed-memory-only invariant maintained — no banked code reachable from any interrupt vector.
- BDOS calls (`CALL 0005h`) work unchanged from banked code (BDOS at $DC00–$E9FF is fixed memory).
- All 974 Phase-3 close-out tests continue passing under the banked build (zero regressions).

**Standing-commitment hold (S1–S12):** all 12 standing process commitments continue to hold across every Phase-4 epic:
- S1 adversarial review fresh-context CR
- S2 REPL-piped tests as default
- S3 real-byte-count estimation + capstone-aware drafting
- S4 AC-composition validation
- S5 PARTIAL → HALT
- S6 inventory grep covers helpers, not just leaves
- S7 EXX-hygiene per kernel-internal raise site
- S8 "pre-existing" cannot discharge correctness defects
- S9 mid-epic hardware-smoke cadence per story
- S10 workflow > memory > prompt
- S11 user-visible version surface audit row at any tag-applicable epic close-out
- S12 hardware-typed probe authoring discipline

**Regression / hardware:**

- Phase-3 close-out test baseline (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) maintained or extended under every Phase-4 antforth 3.x point-release.
- Mid-epic hardware-smoke per story (S9): every binary-delta Phase-4 story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast with PASS verdict.
- Banking-capable emulator vendor selected and integrated dual-track with iz-cpm before Epic-17 story-writing begins (Phase-4 prework gate, Epic 16.3).

### Measurable Outcomes

| Indicator | Phase-3 close-out baseline | Phase 4 target |
|---|---|---|
| `make test-repl` passing | 974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm (PASS on hardware) | ≥ 974 PASS / 0 FAIL under banked build (additional Phase-4 banking probes welcome; zero regressions) |
| Cross-bank call overhead | N/A (no banking) | ≤ 60 T-states + MMU port-write |
| Bank-switch latency | N/A | ≤ 60 T-states + MMU port-write |
| Per-banked-word descriptor stub | N/A | 3–5 bytes per word; ≤ 5 KB total at 1000-banked-words target |
| Banking infrastructure (fixed memory) | N/A | ≤ 8 KB worst case (28-bank cap); ~6 KB at default 12 banks |
| Default user RAM | 0 KB banked (~25 KB binary in flat memory) | 192 KB (12 banks × 16 KB) |
| Maximum user RAM | — | 464 KB (29 banks × 16 KB, trading VC + RAM disk) |
| Banking-capable emulator | iz-cpm (no banking) | Banking-capable vendor selected (Epic 16.3); iz-cpm continues for regression baseline |
| Standing process commitments | S1–S12 (post-Phase-3) | S1–S12 across every Phase-4 epic close-out |
| Hardware smoke on real CP/M 2.2 / MicroBeast | Clean (Phase-3 close-out) | Clean for every binary-delta story (S9) |
| Tag-applicable close-out version-surface audit (S11) | Held at v2.x | Held at every Phase-4 antforth 3.x point-release |

## Product Scope

### MVP — Minimum Viable Product

The **Phase-4 close-out** (final antforth 3.x point-release tag) is the MVP for this phase. All 7 banking epics (16–22) ship as MVP — no scope-cuts. The MVP ships when ALL of the following hold:

- All 7 epics (16–22) closed per `docs/antforth-banking-redesign.md` §8
- 12-word `BANK*` wordset shipped with documented stack effects, ABORT semantics, and per-word hardware-typed acceptance probes
- Per-word descriptor-stub mechanism (γ) operational; xt-as-stub-address contract holds
- Sentinel-trampoline cross-bank EXIT (S1 b) operational; intra-bank zero-overhead path holds; cross-bank dispatch transparent to user code
- Bank-aware compiler operational: per-bank `(here, latest, wordlist-heads)` swap on `BANK!`; `,` / `COMPILE,` / `:` write into target bank correctly; `CREATE` / `DOES>` cross-bank explicit
- Bank-aware FIND operational: per-wordlist `bank` field; system wordlists tagged `bank=fixed`; `WORDS` traverses banks; error messages name source bank
- ABORT/QUIT bank-state restore operational (S5)
- Boot configuration operational: CL parser `antforth <portal-page> <bank-list>`; defaults `22 35-3F`; probe-on-add via `+BANK`; banner shows bank count; bad pages produce one-line warnings
- 974 Phase-3 close-out test baseline continues passing under banked build (zero regressions)
- All Phase-4 banking acceptance probes hardware-verified clean on real CP/M 2.2 / MicroBeast
- All standing commitments S1–S12 continue to hold across every Phase-4 epic close-out
- Tag-applicable close-out passes the S11 user-visible version-surface audit (banner / README / memory-file `description` fields aligned to antforth 3.x)

**Out of MVP scope (explicitly):** flat-build retention is **not** in MVP scope. Specification of flat-build semantics for the new 12-word wordset is deferred to Phase 5+ (per `docs/antforth-banking-redesign.md` §4 and §9 item 7). Phase-4 stories should not slow down to preserve flat-build compatibility.

**Partial delivery is a legitimate antforth 3.x point-release** but does not constitute Phase-4 close-out. The phase is defined by all 7 epics shipping cleanly.

### Growth Features (Post-MVP — Phase 5+ candidates)

Candidate themes for the next phase (drawn from `docs/PHASE-3-CARRY-FORWARD.md` category E and `docs/WISHLIST.md`), to be triaged when Phase 4 closes:

- **E.1 MicroBeast hardware vocabulary** — system timer ISR, GPIO, 24×14-segment LED matrix, beeper, UART, I²C, memory-banking control, RTC. Strong fit with the multitasker via timer-driven `PAUSE`.
- **E.2 Cooperative multitasker** — PAUSE-based yield, `TASK` / `ACTIVATE`, `KEY`-hooked REPL multitasking, timer-ISR integration. Bank-as-1-byte-of-TCB rides cleanly on Phase-4 stubs/sentinels per the 2026-05-09 future-proofing analysis.
- **E.3 Semaphores** — `SIGNAL` / `WAIT`, mutexes, mailbox primitives for cooperating tasks. Depends on E.2.
- **E.4 `SEE` decompiler** — makes the system self-inspectable; depends on E.5.
- **E.5 `TRAVERSE-WORDLIST`** (ANS extension) — enables E.4 + xref tools written in Forth itself.
- **E.6 ANS Forth Locals** — `{: a b -- c :}` or `VALUE` / `TO`. All three styles confirmed compatible with the Phase-4 banking design.
- **E.7 Z80 IN / OUT primitives** — promotes commonly-used hardware-port access from user CODE words into kernel-level words.
- **E.8 Compilation to standalone `.com` binary** — tree-shaken Forth apps without the outer interpreter. Architecturally interesting; shifts antforth's product positioning.
- **E.9 Object orientation** — after study of Pountain's book (acquired) and the NEON / Yerk / FOBJ literature.
- **E.10 Beginner's guide** — user-facing documentation epic.
- **E.11 Per-wordset reference doc** — reference doc for the now-shipped wordsets.
- **Flat-build retention** — specification of flat-build semantics for the 12-word `BANK*` set, deferred from Phase-4 MVP per `docs/antforth-banking-redesign.md` §4. Re-trigger only if a specific use case emerges (e.g. a target without banked memory hardware).

### Vision (Future — Phase 5+)

Long-term platform evolution beyond the Phase-5 candidate slate:

- **Banking abstraction stable enough for non-MicroBeast Z80 targets** with similar MMU schemes (a ports-and-pages variant). The (γ) descriptor-stub mechanism does not depend on MicroBeast-specific MMU port assignments.
- **Turnkey-compiled `.com` binaries** (E.8 above, expanded into a strategic delivery mode) — the project gains a "ship a Forth app to a CP/M user who doesn't have antforth installed" affordance.
- **Cooperative multitasker leveraging banks as TCB context** (E.2 above, expanded) — each task has its own bank as part of its TCB, with stubs/sentinels riding preemption.
- **VideoBeast / AudioBeast support** (depend on hardware availability).
- **Float wordset** (significant size and complexity).
- **Portability to a second Z80 retrocomputer platform** — validates the design's inherent portability.
- **Community word library sharing** — the ecosystem begins to form.

Permanently deferred (P3 in carry-forward, no current trigger): `make bench` infrastructure, DMA pool size-reduction, `.S` migration to pictured output, MARKER full-graph snapshot, WORDS scope-pick. Rejected during Phase 2 and not under reconsideration: ASSEMBLER.FTH migration, ASSEMBLER wordlist auto-activation (per `project_assembler_keep_assembly.md` — `src/assembler.asm` stays kernel-resident hard-coded).

## User Journeys

### Scope Note on User Types

antforth is a **single-user interactive REPL** running on personal retrocomputer hardware. There is no network surface, no multi-tenant model, no authentication, no API layer. The traditional PRD categories of *admin*, *support*, *moderator*, and *API consumer* do not apply — the user **is** the admin of their own machine.

For Phase 4 — banked-RAM enablement — the journeys covered below frame the two primary personas from the 2026-05-08 product brief ("The OG" and "The Newb") and the secondary Hardware/Peripheral Developer in **non-regression** flows under the new banked build (J1–J4). The banked build is now the **default**; existing Phase-1+2+3 user-visible behaviour is preserved unchanged. J5 and J6 are net-new Phase-4 banking journeys covering the multi-bank application authoring experience (J5) and the scoped-library-invocation pattern (J6).

This is the full human-interaction surface of the product through the Phase-4 feature window.

### Journey 1 — Mo's Quiet Tuesday Afternoon (OG, happy path / non-regression)

**Opening scene.** Mo upgraded her MicroBeast's `ANTFORTH.COM` last week to the latest Phase-3 antforth 2.x release. Tuesday afternoon she boots into the REPL to continue work on her sprite-driver experiments. The banner reads `antforth 2.x — ok`. She INCLUDEs her work-in-progress driver from B: with `INCLUDE B:SPRITES.FTH`, expecting things to be exactly where she left them.

**Rising action.** They are. Every word she defined in 2.0 still works the same way in 2.x. `MARKER -OLD` still snapshots state. `CATCH` still wraps her experimental words. `WORDLIST` / `DEFINITIONS` still organise her sprite vocabulary separately from kernel words. `INCLUDE` still loads from B:; `SAVE-SOURCE` still writes back. Her CODE words assemble byte-identical against the same hard-coded inline assembler. The 21 cleanup-slate probes the upgrade brought in (944..964) didn't break anything she relied on — and the 952-baseline tests she's heard about all still pass in her own sanity check (`make test-repl`).

**Climax.** She doesn't notice anything has changed. That *is* the climax. The upgrade is invisible to her workflow.

**Resolution.** Later that evening, as she's writing a forum post about a clever trick she found, she happens to link to `docs/ans-forth-core-compliance.md` to cite that antforth's `M*` / `UM*` / `SM/REM` / `FM/MOD` behaviour matches DPANS94 §6.1. The doc now has §-level rows for every mandatory Core + Core-Extension rule (A.1's outputs). She doesn't have to caveat the link. The compliance claim is *checkable* line-by-line — a small but meaningful upgrade in how she thinks about antforth's standing.

**Requirements surfaced:** Phase-3 regression baseline (973 PASS / 0 FAIL maintained, S9 hardware-smoke per binary-delta story), A.1 §-by-§ audit complete with per-rule rows in `docs/ans-forth-core-compliance.md`, all v2.0 functional behaviour preserved (FR45-equivalent constraint).

### Journey 2 — Mo Catches an Asm Error That Used To Crash Her Session (OG, caught-form closure)

**Opening scene.** Mo is iterating on a CODE word that does block-copy of palette data. She accidentally writes `(IX) +D` without the displacement byte first — `+D` consumes its operand from the stack, gets a tag mismatch with `(IX)`, raises `-271 THROW_ASM_DISP_RANGE`. On v2.0 this would print `error -271: disp range` and (because the asm-error caught-form path was incomplete — A.2 in the carry-forward) sometimes interact awkwardly when wrapped in `' WORD CATCH . CR`.

**Rising action.** Post-A.2 (Phase 3), Mo writes a defensive shell around her experimental CODE word: `: TRY-PAL  ['] PAL-COPY CATCH ?DUP IF ." asm error " . CR THEN ;`. She runs `TRY-PAL`. Instead of an awkward print or an unwound state, she sees `asm error -271 ok` cleanly. `WORDS` still works. Her dictionary is intact. She fixes the displacement, re-runs `TRY-PAL`, gets `ok`.

**Climax.** Caught-form THROW now works for the full `-258..-272` asm-error block exactly the way it works for ANS-standard codes like `-4` (stack underflow) or `-13` (undefined word). Mo can write defensive harnesses around her experimental CODE words without the THROW system having a known asym between asm-error codes and standard codes.

**Resolution.** She mentally upgrades her trust in `CATCH` from "works for standard codes; iffy for asm errors" to "works for everything the kernel raises". The asym is closed.

**Requirements surfaced:** A.2 caught-form coverage gap closed for asm-error THROW codes -258..-272; FR16 (CATCH frame), FR17 (THROW), FR21/FR22 (REPL survives any THROW) continue to hold across the asm-error code block.

### Journey 3 — Raj Doesn't Trip on HEX Mode Confusion (Newb, base-aware parse)

**Opening scene.** Raj is following a community-authored beginner's guide that walks through experimenting with the 14-segment LED display via direct port writes. The guide says "set HEX mode and try `0xFF P!`." Raj types `HEX` and then experimentally types `255 .` — partly to check that decimal still displays correctly. On pre-A.3 antforth, he'd see `FF` (255 reinterpreted as hex 255 → output FF). Confusing.

**Rising action.** Post-A.3, antforth's unprefixed `NUMBER?` is now base-aware in the way Raj expects: the explicit `BASE` setting governs unprefixed numerals consistently. Raj sees output that matches the base he set — the typing and the display agree. He goes back to `0xFF P!` (his Forth-2014-prefixed literal, which is *always* hex regardless of BASE per FR9), gets the LED segment he expected, moves on.

**Climax.** The "wait, why is decimal showing as hex?" moment that used to derail beginners doesn't happen.

**Resolution.** Raj never even notices the gotcha was there. The kindest UX upgrades are the ones that prevent confusion that would have happened.

**Requirements surfaced:** A.3 unprefixed `NUMBER?` base-specialization; existing FR1–FR9 (Forth-2014 numeric literal prefixes including `0x`) continue to hold (prefixed literals still always parse in their declared base regardless of BASE).

### Journey 4 — Pete Stress-Tests an Edge Case That Used To Be Quiet (Hardware/Peripheral Developer, B.7 stress-matrix)

**Opening scene.** Pete is bench-testing a new hardware variant that interacts with file I/O. He fills the B: ramdisk to capacity, then deliberately exercises an edge case: trying to `WRITE-FILE` past the disk-full boundary. On pre-B.7 antforth there was no specific probe coverage for the directory-full and zero-byte-`READ-FILE` failure modes — they worked, but no test exercised them.

**Rising action.** Pete wraps his write in `' MY-WRITE CATCH ?DUP IF ." disk error " . CR THEN`. The `WRITE-FILE` returns a specific non-zero `ior`; the FCB pool stays consistent (no orphaned handles per NFR8 / B.7); the filesystem itself stays in a consistent state on real CP/M 2.2 hardware. Pete sees `disk error 8 ok` (ior = 8 — disk full). His kernel wasn't corrupted by the failed write.

**Climax.** The B.7 probe coverage that landed mid-Phase-3 (or was confirmed-not-needed by hardware run) means Pete can rely on documented failure-mode behaviour. He posts on the MicroBeast Discord: "B: ramdisk-full handling on antforth 2.x is clean — write returns ior, FCB pool stays sane, no need to defensive-CLOSE-FILE everything."

**Resolution.** A previously-untested failure-mode corner moves into "tested and documented" status. Pete validates one more variant and ships his hardware design.

**Requirements surfaced:** B.7 NFR8 stress-matrix coverage gaps (directory-full, zero-byte READ-FILE); existing FR43 (file errors raise THROW or ior) and NFR8 (filesystem error recovery) continue to hold across the new probe coverage; B.9 disk-full hardware re-verification on real CP/M 2.2 / MicroBeast.

### Journey 5 — Marcus Organises a Multi-Bank Application (OG, banking happy path)

**Opening scene.** Marcus is a hobbyist Forth programmer with a 30 KB application — a sprite-driven graphics demo backed by a small in-memory database — that won't fit in flat memory. He's been waiting for the Phase-4 banked build. He boots his MicroBeast with `antforth 24 35-3f` from the CP/M command line. The banner reads `antforth 3.x — 12 banks available — ok`.

**Rising action.** Marcus types `5 BANK!` and starts defining his graphics primitives — colon definitions, CODE words, constants. Each word lands in bank 5; the compiler emits a 3–5-byte descriptor stub in fixed memory carrying `(5, addr_in_bank_5)`. He then types `3 BANK!` and switches context to bank 3, where he defines his database words against a different `(here, latest, wordlist-heads)` triple. He calls between them — `5 BANK! GRAPHICS-INIT 3 BANK! DB-LOAD` — and also writes a top-level word `: DEMO  GRAPHICS-INIT DB-LOAD MAIN-LOOP ;` that calls across banks transparently. He never types a thunk word.

**Climax.** The compiler-emitted descriptor stubs handle the dispatch. Marcus's source text is indistinguishable from a flat-memory program except for the `BANK!` lines that organise where things land. He runs `BANK-OF` on an xt to confirm a word lives where he thought (`' GRAPHICS-INIT BANK-OF .` → `5`); types `.BANKS` to see used/free per bank.

**Resolution.** The 30 KB application fits comfortably across three banks (graphics in 5, database in 3, top-level glue in 1) with room to grow. Marcus saves his source to B: with `SAVE-SOURCE`. Next session, he loads it with `INCLUDE` and the same banking layout reconstructs because the source contains the `BANK!` lines.

**Requirements surfaced:** 12-word `BANK*` wordset (specifically `BANK!`, `BANK@`, `BANK-OF`, `.BANKS`); per-word descriptor-stub mechanism (γ); compiler-transparent cross-bank dispatch; per-bank `(here, latest, wordlist-heads)` swap on `BANK!`; CL parser; banner shows bank count; bank-aware FIND across system + user wordlists.

### Journey 6 — Marcus Uses `IN-BANK` for Scoped Library Invocation (OG, banking scoped-execution)

**Opening scene.** Marcus has a math library in bank 7 — `MATRIX-INVERT`, `DOT-PRODUCT`, etc. — that he loaded once at startup. He's currently working in bank 5 on a graphics primitive that needs one matrix inversion call. He doesn't want to permanently switch context to bank 7.

**Rising action.** Marcus writes `7 ' MATRIX-INVERT IN-BANK`. The kernel saves the current bank (5), switches to bank 7, executes `MATRIX-INVERT`, and restores bank 5 on exit. The result is on the data stack as expected. His current `(here, latest, wordlist-heads)` triple is back where it was.

**Climax.** Marcus deliberately writes a buggy variant: `7 ' BAD-INVERT IN-BANK` where `BAD-INVERT` THROWs. He has the call wrapped in `: TRY  ['] BAD-INVERT 7 SWAP CATCH . CR ;`. The THROW unwinds; the kernel still restores bank 5 on the way out (CATCH-safe semantics — `IN-BANK`'s reference body `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;` interacts correctly with CATCH frames because `>R / R>` is on the standard return stack). His REPL prompt is back at bank 5, his dictionary is intact, the THROW code printed cleanly.

**Resolution.** Marcus uses `IN-BANK` as his standard pattern for one-shot calls into auxiliary banks. The library-author idiom "call my word from anywhere with `n ' WORD IN-BANK`" emerges naturally.

**Requirements surfaced:** `IN-BANK` (kernel-blessed, not user library word); CATCH-safe bank-state restore; sentinel-trampoline cross-bank EXIT (S1 b); ABORT/QUIT bank-state restore (S5).

### Journey Requirements Summary

The six journeys above collectively surface the following PRD-level capability requirements (functional and non-functional both). J1–J4 are non-regression touchstones (banked build preserves Phase-1+2+3 user-visible behaviour); J5–J6 are net-new banking journeys.

| Capability | J1 | J2 | J3 | J4 | J5 | J6 | FR group |
|---|---|---|---|---|---|---|---|
| Phase-1+2+3 functional behaviour preserved under banked build | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Backward Compatibility & Regression |
| Phase-3 close-out test baseline (974 PASS) maintained | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Backward Compatibility & Regression |
| 12-word `BANK*` wordset present (`BANK@ BANK! BANKS …`) |  |  |  |  | ✓ | ✓ | Banking Wordset |
| `BANK!` switches current bank; ABORT on unknown bank |  |  |  |  | ✓ | ✓ | Banking Wordset |
| `BANK-OF` returns target bank for an xt (`-1` for fixed) |  |  |  |  | ✓ |  | Banking Wordset |
| `.BANKS` prints used/free per bank |  |  |  |  | ✓ |  | Banking Wordset |
| `+BANK` / `-BANK` / `BANKS-CLEAR` runtime config |  |  |  |  | ✓ |  | Banking Wordset |
| `IN-BANK ( n xt -- )` scoped execution; CATCH-safe |  |  |  |  |  | ✓ | Banking Wordset |
| Per-word descriptor stub (γ); xt = stub address |  |  |  |  | ✓ | ✓ | Cross-Bank Dispatch |
| Cross-bank call overhead ≤60 T-states + bank-switch |  |  |  |  | ✓ | ✓ | Cross-Bank Dispatch |
| Sentinel-trampoline cross-bank EXIT (S1 b) |  |  |  |  | ✓ | ✓ | Cross-Bank EXIT |
| Per-bank `(here, latest, wordlist-heads)` swap on `BANK!` |  |  |  |  | ✓ |  | Bank-Aware Compiler |
| `,` / `COMPILE,` / `:` write into current bank |  |  |  |  | ✓ |  | Bank-Aware Compiler |
| Bank-aware FIND traversal; system wordlists fixed |  |  |  |  | ✓ | ✓ | Bank-Aware FIND |
| ABORT/QUIT bank-state restore (S5) |  |  |  |  | ✓ | ✓ | ABORT/QUIT Bank-State Restore |
| CL parser `antforth <portal-page> <bank-list>`; banner shows bank count |  |  |  |  | ✓ |  | Boot Configuration |
| ISR-from-fixed-memory-only invariant maintained | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Integration NFR |
| BDOS calls work unchanged from banked code | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Integration NFR |
| S9 hardware-smoke per binary-delta story | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | NFR / standing commitment |
| S11 user-visible version-surface audit at tag close-out | ✓ |  |  |  | ✓ |  | NFR / standing commitment |
| S12 hardware-typed probe authoring discipline |  |  |  | ✓ | ✓ | ✓ | NFR / standing commitment |

Every Phase-4 banking capability maps to at least one journey (J5 + J6 between them cover the full 12-word wordset and the dispatch / compiler / FIND / ABORT-restore / boot-config FR groups). Every journey is supported by a coherent set of FRs + standing commitments. **No orphan requirements; no uncovered users.**

## Developer-Tool-Embedded Requirements

antforth is a compound `developer_tool` (programming-language implementation) + `iot_embedded` (single-purpose 8-bit hardware platform). Most generic SDK questions (package managers, IDE integration, OTA updates) do not apply — the interpreter IS the package, the device IS the IDE, and updates are delivered by copying a new `.COM` file to the CP/M filesystem. The requirements below carry forward unchanged from the Phase-2 / Phase-3 PRDs with three Phase-4 deltas: (1) the runtime model gains a bank-switching layer; (2) banking words are added as antforth extensions (not part of any ANS wordset); (3) CCP eviction yields +2 KB Page-3 headroom for kernel growth. The rest are stable platform / runtime / distribution invariants.

### Project-Type Overview

antforth is distributed as a **CP/M 2.2 `.COM` executable** that runs on the MicroBeast Z80 retrocomputer. It is simultaneously (a) an implementation of the ANS Forth 1994 / Forth 2014 programming language and (b) a self-hosted interactive development environment. It has no external build chain, no package dependency graph, no network surface, and no multi-user runtime. The user installs by copying the `.COM` file to the CP/M A: (ROM) or B: (ramdisk) drive and runs it like any other CP/M program.

**Phase-4 framing:** Phase 4 ships antforth 3.x point-releases against this same `.COM`-on-CP/M-2.2 shape. The platform is unchanged (Z80 + MicroBeast + CP/M 2.2); the runtime model gains the bank-switching layer; the distribution model is unchanged (single `.COM` file; copy to a CP/M drive; run).

### Target Platform Requirements (unchanged from Phase 2)

- **CPU:** Zilog Z80 @ 8 MHz (MicroBeast spec). Z80 instruction-set compliance only — no Z80N, no eZ80, no Z180 extensions.
- **Memory:** 512 KB banked RAM/ROM, MicroBeast bank-switching scheme. antforth kernel + dictionary live in fixed memory (CP/M's TPA + Page-3 BDOS/BIOS region). **Phase 4 lifts banking** — the portal page (default 0x22, configurable on the command line) carries the active user bank, and 12 banks of 16 KB each (default 0x35–0x3F) are available to user code per `docs/antforth-banking-redesign.md`. Theoretical max 29 banks by trading the virtual-console buffer (0x24) and RAM disk (0x25–0x34).
- **Host OS:** CP/M 2.2. All I/O (console, file system, drive select) is routed through BDOS calls; no direct hardware I/O beyond the BIOS-level abstractions CP/M provides. **Phase 4 evicts the CCP** ($D400–$DBFF) for +2 KB Page-3 headroom; BDOS ($DC00–$E9FF) and BIOS ($EA00+) stay resident. BDOS calls (`CALL 0005h`) work unchanged from banked code. The BDOS function allow-list does not grow in Phase 4.
- **Storage:** A: (ROM filesystem, read-only practically) and B: (ramdisk, read-write) as the two canonical drives. The default-12-banks configuration preserves the RAM disk; a user opting into the 29-bank max-RAM configuration trades it.
- **Terminal:** standard CP/M console (character I/O via BDOS functions 1, 2, 6, 9); no assumption of ANSI escape sequences, cursor addressing, or colour. Carried forward unchanged from Phase 2 / Phase 3.
- **Display hardware (post-phase):** 24-character 14-segment LED displays on the MicroBeast. Not consumed by Phase 4; deferred to the Phase-5+ MicroBeast hardware vocabulary epic (E.1 in the Phase-3 carry-forward catalogue).

### Language / Standard Compliance (Phase-4 delta: banking words are antforth extensions)

- **Primary standard:** ANS Forth 1994 (ANSI X3.215-1994) — Core wordset to **100% coverage**, **§-level defensible** (per the Phase-3 A.1 §-by-§ audit; per-rule rows in `docs/ans-forth-core-compliance.md`). Phase 4 inherits this commitment unchanged. Any new Core or Core-Extension word that lands in Phase 4 adds its own §-level row.
- **Secondary standard:** Forth 2014 — §3.4.1.3 (numeric literal prefixes), §3.1.4.1 (high-on-TOS double-cell stack-layout), §11.6 (File-Access wordset), §9.6.1 (Exception wordset). All carried forward unchanged from v2.0 / Phase-3 close-out.
- **antforth extensions beyond standards:** the existing extensions (`0x` hex-literal prefix, `INCLUDE-TOP` / `CATCH-TOP` USER-variables, asm-error THROW codes `-258..-272`) carry forward. **Phase 4 adds the 12-word `BANK*` wordset as antforth extensions** — ANS Forth does not standardise banked memory, so all 12 words (`BANK@ BANK! BANKS IN-BANK BANK-OF .BANKS +BANK -BANK BANKS-CLEAR SET-BANK BANK-MAPPING-ON BANK-MAPPING-OFF`) are flagged in source per CCD-3 (`; antforth extension <word> — <design reason>`).
- **No new ANS wordset compliance commitments in Phase 4.** Banking is a platform-specific extension; antforth does not adopt any external banking specification (none exists in the ANS Forth or Forth 2014 corpus). The reference design is `docs/antforth-banking-redesign.md` (locked 2026-05-09).
- **Word-set coverage within Core + selected wordsets (post-Phase-3 baseline carried forward):** §6.1 Core = 100% / §-level defensible; §6.2 Core Extension = 13/46 (DPANS94 1994 baseline) + 1 Forth-2014 bonus (HOLDS); §8.6 Double-Number = 13/13; §9.6 Exception = full; §11.6 File-Access = full user-facing surface; §16.6 Search-Order = full + ONLY (§16.6.2). Phase 4 does not change these counts.
- **Standards-citation discipline (CCD-3):** continues to apply in Phase 4 — every word whose behaviour is specified by ANS / Forth-2014 carries a one-line citation comment. Banking-extension words carry the `; antforth extension` form with a design-reason note pointing at `docs/antforth-banking-redesign.md`.

### Installation & Distribution (unchanged from Phase 2)

- **Artifact:** single `.COM` file, Z80 machine code, assembled from the antforth source tree (`src/*.asm` via the project's existing build script). Phase-3 close-out baseline: 24,995 bytes. Phase 4 adds banking infrastructure to the kernel; the cumulative budget envelope is governed by the ≤8 KB total banking infrastructure cap (per `docs/antforth-banking-redesign.md` §7), partly absorbed by the +2 KB Page-3 headroom from CCP eviction.
- **Installation:** copy `ANTFORTH.COM` to a CP/M drive (A: ROM or B: ramdisk) via whatever file-transfer mechanism the user has available (serial transfer, EPROM programmer, SD-card adapter). Single-file install. Phase 4 adds an optional command-line tail for banking configuration: `antforth <portal-page> <bank-list>` (e.g. `antforth 24 35-3f`); absent, defaults to `22 35-3F`.
- **Update mechanism:** replace the `.COM` file. No in-place upgrade, no migration tooling. Because antforth's persistent state lives in user `.FTH` source files on disk (not in interpreter image state), sessions survive interpreter updates as long as the dictionary layout is compatible. Phase 4 changes the dictionary layout (per-bank `(here, latest, wordlist-heads)` triples); pre-Phase-4 image state is not portable forward, but `.FTH` source files are.
- **Versioning:** semantic versioning. Phase-4 releases ship as **antforth 3.x** point-releases (one per epic close-out across Epics 16–22). The phase concludes when all 7 banking epics close cleanly + the banked build runs the Phase-3 close-out test baseline clean on real hardware + the 12-word `BANK*` surface passes its own hardware-typed acceptance probes. **S11 standing commitment** ensures user-visible version surface (banner string in binary, README, memory-file `description` fields) is audited at every tag-applicable epic close-out.

### Runtime Model (Phase-4 delta: bank-switching layer)

- **Boot flow:** `.COM` loaded by CP/M → CL parser reads `<portal-page> <bank-list>` (or applies defaults `22 35-3F`) → probe-on-add validates each bank → banner with bank count → REPL prompt. Assembler opcodes baked into the kernel dictionary, reachable from the global vocabulary, unchanged across all phases (per `project_assembler_keep_assembly.md` — `src/assembler.asm` stays kernel-resident hard-coded; no ASSEMBLER.FTH, no auto-activation). `BANK-MAPPING-ON` is auto-run in `COLD` so the banked build is the default user experience.
- **Persistence:** user words live in RAM until the machine is powered off. Persistence across sessions is achieved by saving source to B: and `INCLUDE`-ing on next boot. There is no image-save mechanism; this is by design (keeps the source-of-truth in the user's files, not in the interpreter's state). Phase-4 banking does not change this; banked words save and reload via source like everything else (the user's `.FTH` source contains the `BANK!` lines that recreate the layout).
- **Banking model:** per `docs/antforth-banking-redesign.md` §5 — fixed memory holds the kernel + bank-table[] + descriptor stubs + cross-bank-return trampoline + BDOS/BIOS; the portal page (default 0x22) carries the active user bank; `BANK!` swaps in a new bank's `(here, latest, wordlist-heads)` triple; ISR bodies live in fixed memory only.
- **MARKER:** in-session rollback mechanism. Phase 4 extends MARKER to track per-bank dictionary tails (Epic 21). Documented scope-pick (linear dictionary snapshot, not full graph) preserved per `docs/PHASE-3-CARRY-FORWARD.md` D.3.

### Explicitly Out of Scope for Project-Type Requirements (carried forward from Phase 2)

The following generic `developer_tool` and `iot_embedded` concerns are not applicable to antforth and will not be documented:

- **Package managers / dependency resolution** — antforth has no package ecosystem; the unit of sharing is a `.FTH` source file
- **IDE integration** — the REPL IS the IDE; syntax highlighting / completion are out of scope
- **OTA updates** — replace the `.COM` file; no over-the-air mechanism required or planned
- **Power management / sleep modes** — mains-powered retrocomputer, not battery-constrained
- **Network security** — no network surface on the platform
- **Multi-platform language-support matrix** — antforth targets Z80 + CP/M 2.2 specifically. Portability to a second Z80 retrocomputer platform is listed as a long-term Vision item but not in Phase 4's scope.
- **Visual design / store compliance / browser support** — explicitly skipped per CSV `skip_sections` for both `developer_tool` (`visual_design;store_compliance`) and `iot_embedded` (`visual_ui;browser_support`).

### Implementation Considerations (Phase-4-specific deltas)

- **Architectural anchor:** `docs/antforth-banking-redesign.md` (locked 2026-05-09 in a `/bmad-party-mode` session). This document supersedes `docs/antforth-banking-design.md` (2026-05-07 sketch with `SUPERSEDED` banner). All Phase-4 stories cite the redesign doc; the sketch is preserved only for design-evolution traceability.
- **Phase-4 epic structure (7 epics, 25–30 stories):**
  - **Epic 16** — Memory map + emulator pick + doc lock (prework). H1 memo, page-allocation survey, CCP-overwrite policy, IM 2 confirmation, doc rewrite (closed by the redesign doc), banking-capable emulator vendor selection (Story 16.3 = the prework gate).
  - **Epic 17** — Bank primitives + CL config. All 12 wordset words; `+BANK`/`-BANK`/`BANKS-CLEAR`; command-line parser; probe-on-add; banner update; hardware spike for cross-bank call on iron.
  - **Epic 18** — Stub mechanism (γ) + cross-bank EXIT (S1 b). Per-word descriptor stubs; sentinel-trampoline return; kernel `EXECUTE` switch; `BANK-OF`; `IN-BANK`.
  - **Epic 19** — Bank-aware compiler. Per-bank `HERE`/`LATEST`; `,` / `COMPILE,` writing into target bank; `:` lands body in current bank; stub auto-emitted; `CREATE`/`DOES>` cross-bank explicit (PFA stores doer-stub address + data cell).
  - **Epic 20** — Bank-aware FIND + interpreter loop. Wordlist `bank` tagging; `FIND` traversal; `WORDS`; error messages.
  - **Epic 21** — `MARKER`/`FORGET` + ABORT/QUIT bank state (S5). Per-bank dictionary tail tracking; saved-bank restore on `ABORT`.
  - **Epic 22** — Polish. `.BANKS`; REPL prompt indicator; CODE-words-in-banks decision; test-harness sweep.
- **Phase-4 prework gate (Epic 16.3):** banking-capable emulator vendor selection. iz-cpm does not support banking. Phase 4 needs a banking-capable emulator running **dual-track** alongside iz-cpm so the Phase-3 close-out test baseline (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) continues passing while banking work proceeds. Story-writing in Epic 17 onwards blocks on this selection.
- **Mechanism summary (the (γ) decision and consequences):** every banked word, when defined, gets a 3–5-byte descriptor stub in fixed memory containing `(target_bank, target_addr_in_bank)`; **the stub's address is the word's xt**. `COMPILE,` always emits the stub address. Same-bank dispatch goes through the stub with one extra `JP` overhead vs flat dispatch. Cross-bank dispatch switches MMU to target bank, pushes a sentinel-tagged 3-cell return frame `(sentinel_addr, caller_bank, target_addr)`, and jumps to target body; a `cross_bank_return` trampoline in fixed memory restores the caller's bank then jumps. Per-bank `(here, latest, wordlist-heads)` triples live in a fixed-memory `bank-table[]` swapped on `BANK!`. Per-wordlist `bank` field steers FIND. CL parser accepts `antforth <portal-page> <bank-list>`; CCP eviction yields +2 KB Page-3 headroom.
- **Architecture-stage open questions** (PRD does **not** lock these — the Phase-4 Architecture document captures them as `TODO(P4-arch)` items or Epic-16 spike stories):
  1. CODE words in banks — can user-defined CODE (assembler) words live in banks? Affects S7 dispatch. Epic 22 was left ambiguous in the redesign doc.
  2. CL parser edge cases — no args, bad token, reverse range, dup, probe-fail, empty surviving list. Final policy for each not signed off.
  3. Bank-state-table cap (29 entries, ~448 B worst case) — ABORT-on-`+BANK`-past-cap policy not formally specced.
  4. Stub size: 3 vs 4–5 bytes — final size pinning not done; affects per-word cost calculations.
  5. Recursive cross-bank R-stack overflow — documented gotcha or runtime guard? No FR or limit defined.
- **Source-of-truth boundary:** kernel written in Z80 assembly (builds with the existing cross-assembler toolchain); a small handful of system words written in Forth and pre-compiled into the kernel image at build time. Phase 4 keeps the boundary stable except where banking infrastructure requires kernel surgery (the `bank-table[]`, the `cross_bank_return` trampoline, the per-wordlist `bank` field, the CL parser). The 12-word `BANK*` wordset itself lives in fixed-memory kernel space.
- **Test harness:** REPL-piped Forth test scripts (per S2). Probe authoring follows S12 (word-existence pre-flight + TIB-128 line-length lint). The dual-track emulator strategy means each banking-touching probe must specify which emulator surface it targets (banking-capable for cross-bank assertions; iz-cpm for non-banking regression).
- **Cross-tooling:** build and test happen on a modern host (banking-capable emulator + iz-cpm + cross-assembler); final validation happens on real MicroBeast hardware. Both emulator surfaces must be exercised for any binary-delta story, with the banking-capable surface load-bearing for any cross-bank assertion (S9 mid-epic hardware-smoke cadence remains the final word).
- **ROM-size / fixed-memory budget:** Phase 4 grows the kernel for banking infrastructure. The redesign doc's budget is ≤8 KB total banking infrastructure in fixed memory, of which ~6 KB lands at default 12 banks and ~7–8 KB at the 28-bank cap. This budget includes the CL parser + probe loop (~200 B), configuration words (~120 B), the descriptor-stub allocator overhead, the `cross_bank_return` trampoline, and the bank-state-table (29 entries × ~16 B ≈ 448 B worst case). The CCP-eviction policy yields +2 KB Page-3 headroom that absorbs most of the projected growth.

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach: Feature Phase (return to feature work after Phase-3 debt-cleanup interlude).** Phase 4 is the second feature phase after v2.0 (Phase 3 was a deliberate debt-cleanup interlude). Its job is to deliver the banked-RAM enablement wordset and the supporting compiler / dispatch / FIND / boot-config infrastructure, transparently, with all 974 Phase-3-baseline tests still passing. Discrete antforth 3.x point-releases ship per epic; velocity can flex between point-releases.

This is a **capability MVP** — when Phase 4 closes, the project can claim "the ~25 KB binary ceiling no longer constrains user code" and "banked `:` is indistinguishable from flat `:`" as unqualified facts.

**No scope-cuts within MVP.** All 7 banking epics (16–22) ship. The redesign doc was locked in a `/bmad-party-mode` session on 2026-05-09 with explicit future-proofing checks against multitasking, locals, and ALLOCATE. Cuts mid-phase would re-open architectural choices that the session closed.

**Resource Requirements:** single developer (Ant), supported by the BMAD agent workflow (PM, SM, Dev, QA, Architect agents) for planning, story authoring, dev execution, code review, and retrospective. No external dependencies, no contractor time. **One outstanding research input** before story-writing in Epic 17 onwards: banking-capable emulator vendor selection (Story 16.3, the Phase-4 prework gate; Ant's responsibility per the redesign doc §8.1).

The Phase-4 work breakdown:

- **Epic 16** (3–4 stories) — memory map + emulator pick + doc lock; closes the prework gate
- **Epic 17** (5–6 stories) — bank primitives + CL config; first iron spike
- **Epic 18** (4–5 stories) — stub mechanism (γ) + cross-bank EXIT (S1 b)
- **Epic 19** (4–5 stories) — bank-aware compiler (`,` / `COMPILE,` / `:` / `CREATE` / `DOES>` per-bank semantics)
- **Epic 20** (3–4 stories) — bank-aware FIND + interpreter loop
- **Epic 21** (2–3 stories) — `MARKER`/`FORGET` per-bank + ABORT/QUIT bank-state restore
- **Epic 22** (3–4 stories) — polish (`.BANKS`, REPL prompt indicator, CODE-words-in-banks decision, test-harness sweep)

**Success Philosophy:** ship the 7 epics in dependency order (16 → 17 → 18 → 19 → 20 → 21 → 22). Each epic close-out is an antforth 3.x point-release. Phase-4 close-out tag is the antforth 3.x version after Epic 22 ships cleanly. Partial delivery is a legitimate antforth 3.x point-release but does not constitute Phase-4 close-out.

### MVP Feature Set (Phase 4 close-out — banked-RAM enablement)

**Core user journeys supported at Phase-4 close-out:**

- Journey 1–4 (non-regression) — full support throughout the phase; banked build is the default; existing v2.0 / Phase-3 user-visible behaviour preserved.
- Journey 5 (Marcus organises a multi-bank application) — full support after Epics 17 + 18 + 19 + 20 land (12-word wordset + (γ) stubs + bank-aware compiler + bank-aware FIND).
- Journey 6 (Marcus uses `IN-BANK` for scoped library invocation) — full support after Epic 18 lands (`IN-BANK`, sentinel-trampoline EXIT) and Epic 21 lands (ABORT/QUIT bank-state restore — needed for the CATCH-safe semantics).

**Must-have capabilities, grouped by epic:**

| Epic | Capability delivered | Sequencing rationale |
|---|---|---|
| **16 — Memory map + emulator pick + doc lock** | H1 memo, page-allocation survey, CCP-overwrite policy, IM 2 confirmation, doc lock (closed by `docs/antforth-banking-redesign.md`), banking-capable emulator vendor selection (Story 16.3 = prework gate) | First — establishes the dual-track emulator workflow and locks the architectural reference. No story-writing in Epic 17+ until Story 16.3 closes. |
| **17 — Bank primitives + CL config** | All 12 wordset words in their first usable form; `+BANK` / `-BANK` / `BANKS-CLEAR`; CL parser; probe-on-add; banner update; first iron spike for cross-bank call | Second — gives the kernel a usable banking surface to build the compiler / dispatch layer on top of. |
| **18 — Stub mechanism (γ) + cross-bank EXIT (S1 b)** | Per-word descriptor stubs in fixed memory; sentinel-tagged 3-cell return frame; `cross_bank_return` trampoline; kernel `EXECUTE` switches through stub; `BANK-OF`; kernel-blessed `IN-BANK` | Third — the (γ) decision's payoff. After this epic, dispatch is bank-transparent. |
| **19 — Bank-aware compiler** | Per-bank `(here, latest, wordlist-heads)` triples in `bank-table[]`; `,` / `COMPILE,` / `:` write into current bank; descriptor stub auto-emitted on `:`; `CREATE`/`DOES>` cross-bank explicit (PFA stores doer-stub address + data cell) | Fourth — makes banked `:` indistinguishable from flat `:` from the user vantage. |
| **20 — Bank-aware FIND + interpreter loop** | Per-wordlist `bank` field; `FIND` saves/switches/walks/restores; system wordlists (FORTH, ASSEMBLER) tagged `bank=fixed`; `WORDS` traverses banks; error messages name source bank | Fifth — closes the lookup half of the user-experience guarantee. |
| **21 — MARKER/FORGET + ABORT/QUIT bank state (S5)** | Per-bank dictionary tail tracking; `MARKER` / `FORGET` per-bank; `QUIT` re-asserts saved current bank; `ABORT` mid-execution does not strand user in wrong bank | Sixth — closes Journey-6 CATCH-safe semantics + makes MARKER work consistently across banks. |
| **22 — Polish** | `.BANKS` status table; REPL prompt indicator (optional, per Epic-22 design); CODE-words-in-banks decision; test-harness sweep across banking-capable emulator + iz-cpm + hardware | Seventh — close-out gate. |

**MVP rule (carried forward from Phase 2 / Phase 3):** no story is considered done until its tests pass on real MicroBeast hardware (not just emulator) AND all prior stories' tests still pass. Regression is a blocker, not a deferrable. **Phase-4 specific:** the rule extends to dual-track emulator cleanliness — every binary-delta story passes on both the banking-capable emulator (for cross-bank assertions) and iz-cpm (for non-banking regression baseline) before hardware-smoke.

### Post-MVP Features

See **§ Product Scope → Growth Features (Post-MVP — Phase 5+ candidates)** above for the full Phase-5+ candidate slate (E.1–E.11 from `docs/PHASE-3-CARRY-FORWARD.md` plus flat-build retention deferred from Phase-4 MVP). Not duplicated here.

### Risk Mitigation Strategy

**Technical risks (Phase-4-specific):**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Banking infrastructure overruns the ≤8 KB fixed-memory budget | Medium | High | Per-epic kernel-size accounting against the redesign doc's 8 KB cap. CCP eviction yields +2 KB Page-3 headroom that absorbs most of the projected growth. HALT signal if any single epic would push cumulative over; cumulative-overrun proposals go through `bmad-bmm-correct-course`. The redesign doc's stub-size open question (3 vs 4–5 bytes) is a per-1000-words multiplier — pinned in Epic-16 architecture stage. |
| Per-word descriptor-stub cost scales worse than expected with banked-word count | Medium | Medium | The 1000-banked-words target absorbs ~5 KB at 4–5 bytes/stub; current antforth has ~500 user-visible words across all wordlists, well within the budget. Excess growth triggers stub-size re-pinning (3 vs 4–5 bytes) decision in architecture. |
| Banking-capable emulator vendor selection (Epic 16.3 prework gate) delays Phase-4 start | Medium | Medium | Dual-track emulator strategy: iz-cpm continues to carry the non-banking regression baseline regardless of vendor pick. Epic 16 stories that don't depend on the banking-capable emulator (memory-map docs, CCP eviction policy, doc lock) can proceed in parallel. Worst case: vendor research extends, Epic-17 story-writing slips; the ~974-test baseline is unaffected. |
| Batch loading 5–15% slower under banked FIND | Low | Low | Acceptable per redesign doc §7 (`"interactive use, invisible; batch loading slower by ~5–15%"`). System wordlists tagged `bank=fixed` so common-case lookups incur no MMU switch. Hardware verification flagged in Epic 20 close-out. If the slowdown materialises as user-visible (e.g. INCLUDE on a large file), evaluate FIND-cache spawn at Epic-22 polish. |
| ISR-from-fixed-memory invariant accidentally violated by a Phase-4 story | Low | High | Architecture-stage rule (§5.3 in redesign doc); any Phase-4 story touching the timer-ISR / interrupt-vector path re-walks this invariant in its CCD-3 / S7 review. CCD-4-style epic-close benchmark gates check the ISR layout. |
| BDOS calls break under banked code (CALL 0005h lands in a bank instead of fixed memory) | Low | High | Architectural invariant (§5.2 in redesign doc): BDOS at $DC00–$E9FF stays in fixed memory; `CALL 0005h` always lands there regardless of which bank is currently active. Hardware verification on every binary-delta story per S9. |
| Recursive cross-bank R-stack overflow not caught (open question 5 in redesign doc §9) | Medium | Medium | Architecture-stage decision: documented gotcha vs runtime guard. Story 16.4 (or equivalent architecture spike) closes this before Epic 18 stub-mechanism work. Default policy: documented-gotcha (cheaper); upgrade to runtime guard only if a hardware repro surfaces a real failure. |

**Market / adoption risks (Phase-4-specific):**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Phase-4 banking work attracts no community attention because the user-visible surface is "banking transparent — looks like flat memory" | Low | Low (hobby project) | Phase-4 antforth 3.x point-releases are tagged and announced where interest already exists (forums / Discord). The narrative "antforth now scales past 25 KB" is itself a positive community signal. The 192 KB user RAM headline number lands in the banner. |
| MicroBeast platform itself loses community momentum during the Phase-4 feature window | Low | High (would cap antforth's reachable audience) | Outside the project's control; partially mitigated by designing for portability (Vision item) — the (γ) descriptor-stub mechanism does not depend on MicroBeast-specific MMU details, so a future port to a different banking-capable Z80 board is structurally possible. |

**Resource risks (Phase-4-specific):**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Developer (Ant) hits a burnout patch mid-Phase-4 | Medium | High | The phase is intentionally shaped as 7 discrete epics, each independently shippable as antforth 3.x.N. Velocity can flex to zero between point-releases without killing the project. Phase-3's debt-cleanup interlude was the most recent precedent for "Ant takes a break, project resumes cleanly." |
| Scope creep — banking surface keeps growing because "while we're here let's also..." | Medium | Medium | The 12-word wordset + 7-epic structure are explicitly enumerated in `docs/antforth-banking-redesign.md`. New requests mid-phase are tracked as Phase-5+ candidates, not folded into Phase 4. Project-lead approval required for any wordset-set or epic-count growth. |
| Architecture-stage open questions (CODE words in banks, CL parser edge cases, stub-size pinning, R-stack overflow) accumulate enough to block Epic-17 story-writing | Medium | Medium | Each open question is owned by an Epic-16 spike story; the architecture document captures them as `TODO(P4-arch)` items, not as PRD-blockers. The PRD does not lock these — they belong to the architecture stage. |
| Standing-commitment regression carries into Phase 4 from the Phase-3 maturity hold | Low | Medium | Every Phase-4 retro re-walks S1–S12 as Phase 3 retros do. Any break is flagged in the retro and addressed in the next epic's lead-in. The Phase-3 close-out maturity hold is the carry-forward baseline. |

## Functional Requirements

> **Capability contract notice.** This list defines the complete set of capabilities that Phase 4 must deliver. Downstream work (epics, stories, tests) will be authored against this list. Any capability not listed here will not exist in the final product unless explicitly added. **Phase 4 ships antforth 3.x point-releases**; these FRs are additive to the v2.0 baseline (Phase-1 + Phase-2 + Phase-3 closed FRs continue to hold per the regression-constraint FRs at the end of this section).

### Banking Wordset

- **FR-P4-1 (`BANK@`):** `BANK@ ( -- n )` returns the current logical bank index. `n` is the index into the active bank list (not the physical page number). Available at the REPL and inside colon definitions.
- **FR-P4-2 (`BANK!`):** `BANK! ( n -- )` switches the current logical bank to `n`. Swaps the per-bank `(here, latest, wordlist-heads)` triple. If `n` is not in the active bank list, the word raises `ABORT" bank?"`. Available at the REPL and inside colon definitions.
- **FR-P4-3 (`BANKS`):** `BANKS ( -- n )` returns the count of currently-available banks (a `VALUE` derived from the active bank-list length). Updated by `+BANK` / `-BANK` / `BANKS-CLEAR`.
- **FR-P4-4 (`IN-BANK`):** `IN-BANK ( n xt -- )` saves the current bank, switches to bank `n`, executes `xt`, and restores the saved bank on exit. **Kernel-blessed** (not a user library word). If `xt` raises a THROW, the surrounding CATCH frame still sees the saved bank restored on the way out (CATCH-safe). Reference body: `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;`. Available at the REPL and inside colon definitions.
- **FR-P4-5 (`BANK-OF`):** `BANK-OF ( xt -- n )` returns the bank a word lives in. `n = -1` indicates the word lives in fixed memory (e.g. system wordlists). Implemented as a one-byte read from the descriptor stub at `xt` (free under the (γ) mechanism — FR-P4-13).
- **FR-P4-6 (`.BANKS`):** `.BANKS ( -- )` prints a status table to the console: logical bank index, physical page, current marker (which bank is active), used / free per bank, totals.
- **FR-P4-7 (`+BANK`):** `+BANK ( page -- )` adds a physical page to the active bank list. Probes the page on add: writes a sentinel byte, reads it back, restores the original. If the read-back fails (page is ROM, unmapped, or returns an unstable value), `+BANK` raises `ABORT" probe?"` and does not modify the active list. On success, `BANKS` increments by one.
- **FR-P4-8 (`-BANK`):** `-BANK ( page -- )` removes a physical page from the active bank list. Does not affect the underlying memory contents. After removal, `BANKS` decrements by one. If the page is not in the active list, the word is a no-op (no THROW).
- **FR-P4-9 (`BANKS-CLEAR`):** `BANKS-CLEAR ( -- )` empties the active bank list. After invocation, `BANKS` returns 0; `BANK!` raises `ABORT" bank?"` for any argument until `+BANK` rebuilds the list. Intended for startup-config rebuild.
- **FR-P4-10 (`SET-BANK`):** `SET-BANK ( page slot -- )` performs a raw MMU port write of `page` into MMU `slot`. Bypasses the bank-table[] machinery; intended for diagnostics only. Does not validate; bad arguments produce undefined hardware behaviour.
- **FR-P4-11 (`BANK-MAPPING-ON`):** `BANK-MAPPING-ON ( -- )` enables the MMU mapping hardware. Auto-run in `COLD` so the banked build is the default user experience.
- **FR-P4-12 (`BANK-MAPPING-OFF`):** `BANK-MAPPING-OFF ( -- )` disables the MMU mapping hardware. Provided for the CP/M warm-boot escape (returning control to a flat-memory CP/M context).

### Cross-Bank Dispatch (descriptor-stub mechanism)

- **FR-P4-13 (per-word descriptor stub):** Every word defined in a bank gets a 3–5-byte descriptor stub allocated in fixed memory at definition time. The stub carries `(target_bank, target_addr_in_bank)`. **The stub's address is the word's xt** (the xt-as-stub-address contract). Words defined in fixed memory carry `target_bank = -1` (fixed-memory marker).
- **FR-P4-14 (transparent compiler emission):** `COMPILE,` always emits the stub address (the word's xt). The compiler does not inspect whether the target is in the same bank as the call site — the stub handles dispatch at run time. Source text for `:`-defined words is identical to flat-memory antforth.
- **FR-P4-15 (intra-bank dispatch overhead):** A call from within a bank to another word in the same bank goes through the stub with one extra `JP` overhead vs flat dispatch. No MMU port write occurs.
- **FR-P4-16 (cross-bank dispatch overhead):** A call from one bank to a word in another bank costs ≤ 60 T-states + the MMU port-write time. The stub switches MMU to the target bank, pushes the sentinel-tagged 3-cell return frame (FR-P4-18), and jumps to the target body.
- **FR-P4-17 (xt portability):** An xt obtained via `'` (tick) or `[']` is a stub address in fixed memory. xts are stable across `BANK!` calls and can be passed across bank boundaries on the data stack without modification.

### Cross-Bank EXIT (sentinel-trampoline)

- **FR-P4-18 (sentinel-tagged cross-bank return):** A cross-bank call pushes three cells onto the return stack: `(sentinel_addr, caller_bank, target_addr)`. `sentinel_addr` is the address of the `cross_bank_return` trampoline in fixed memory; the kernel `EXIT` recognises it.
- **FR-P4-19 (intra-bank zero-overhead path):** An intra-bank call pushes one cell onto the return stack (the standard ANS return frame). Intra-bank `EXIT` decodes the standard frame; no sentinel check overhead beyond a single comparison against the sentinel address.
- **FR-P4-20 (cross-bank-return trampoline):** A `cross_bank_return` trampoline lives in fixed memory. When `EXIT` encounters the sentinel, the trampoline restores the caller's bank by writing `caller_bank` to the MMU and jumps to `target_addr` (the standard return address inside the caller's bank).
- **FR-P4-21 (recursive cross-bank R-stack):** Recursive cross-bank calls accumulate 3-cell return frames on the standard return stack. The kernel does not impose a hard limit beyond the existing return-stack depth limit; runaway recursion across banks raises the standard `-5 RETURN-STACK-OVERFLOW` THROW. `TODO(P4-resolve)` marker: the redesign-doc open question 5 (documented gotcha vs runtime guard for cross-bank-specific overflow) is deferred to architecture stage; this FR captures only the existing-overflow-THROW behaviour.

### Bank-Aware Compiler

- **FR-P4-22 (per-bank dictionary state):** Each bank carries its own `(here, latest, wordlist-heads)` triple. The triples live in a fixed-memory `bank-table[]` indexed by logical bank number. `BANK!` swaps in the target bank's triple atomically.
- **FR-P4-23 (per-bank `,` and `COMPILE,`):** `,` writes a cell at the current bank's `here` and advances `here`. `COMPILE,` writes an xt (a stub address in fixed memory) at the current bank's `here` and advances. Cross-bank `,` is not exposed (the user must `BANK!` to the target bank to write into it).
- **FR-P4-24 (`:` lands body in current bank):** `:` allocates the word body at the current bank's `here`, allocates the descriptor stub in fixed memory, links the word into the current bank's `latest`, and updates the current wordlist's chain. After `;`, the new word's xt is the stub address.
- **FR-P4-25 (`CREATE` / `DOES>` cross-bank explicit):** `CREATE` allocates a doer-stub in fixed memory + a data cell in the current bank's data space; the PFA stores the doer-stub address paired with the data cell. `DOES>` reassigns the doer-stub's target. The user must explicitly arrange cross-bank `CREATE`/`DOES>` patterns; the compiler does not auto-redirect across banks.
- **FR-P4-26 (`HERE` / `LATEST` per bank):** `HERE` returns the current bank's `here`. `LATEST` returns the current bank's `latest`. Cross-bank pointer hazards (e.g. capturing `HERE` in bank 5 then `BANK!`-ing to bank 7) are documented gotchas — no runtime guard. The "doc-and-pray" disposition is locked per `docs/antforth-banking-redesign.md` §5.4.

### Bank-Aware FIND

- **FR-P4-27 (per-wordlist `bank` field):** Each wordlist carries a `bank` field naming the bank its head chain lives in. System wordlists (FORTH, ASSEMBLER) are tagged `bank = fixed` (-1). User wordlists default to the bank they were created in.
- **FR-P4-28 (FIND traversal):** `FIND` saves the current bank, switches to the wordlist's bank, walks the wordlist's chain, restores the saved bank, returns the result. Words in `bank = fixed` wordlists incur no MMU switch (the common case).
- **FR-P4-29 (`WORDS` traverses banks):** `WORDS` lists the words across the current search order, switching banks as needed per wordlist's `bank` field. Bank switches are invisible in the output unless explicitly annotated by a future option (out of MVP scope).
- **FR-P4-30 (error messages name source bank):** Lookup-failure error messages (e.g. `<word> ?`) for any word that exists in a wordlist with a non-default `bank` include the bank context in the error text, so the user can disambiguate "I forgot to switch banks" from "I never defined that word".

### ABORT/QUIT Bank-State Restore

- **FR-P4-31 (saved current-bank on outermost interactive `BANK!`):** Each interactive `BANK!` from the outermost interpret loop updates a kernel-internal "saved current bank" cell.
- **FR-P4-32 (`QUIT` re-asserts saved bank):** `QUIT` re-asserts the saved current bank when re-entering the outermost interpret loop. The user does not get stranded in a wrong bank after an `ABORT` mid-execution. `IN-BANK`'s save/restore (FR-P4-4) is independent of this mechanism — `IN-BANK` operates within nested execution; this FR governs the outermost loop only.
- **FR-P4-33 (`ABORT` bank-state):** `ABORT` (and `ABORT"`) unwinds the data stack and return stack and re-enters `QUIT`, which then re-asserts the saved current bank per FR-P4-32. The bank state is consistent with the user's last interactive `BANK!` choice.

### Boot Configuration

- **FR-P4-34 (CL parser syntax):** The interpreter accepts a command-line tail of the form `antforth <portal-page> <bank-list>`, e.g. `antforth 24 35-3f`. `<portal-page>` is a single hex byte naming the MMU slot 2 page assignment. `<bank-list>` is a hex range or list naming the physical pages to seed into the active bank list.
- **FR-P4-35 (CL parser defaults):** Absent a command-line tail, the interpreter applies defaults `22 35-3F` (portal page 0x22, banks 0x35..0x3F = 11 banks). The default-12-banks figure (FR-P4-39) reflects the portal page itself counted as bank 0.
- **FR-P4-36 (CL parser probe-on-add):** During CL parsing, each page in `<bank-list>` is probed before being added to the active list (the same probe `+BANK` runs at runtime — FR-P4-7). Pages that fail probe produce a one-line warning to the console and are excluded from the active list; parsing does not abort on a single bad page.
- **FR-P4-37 (banner shows bank count):** The boot banner includes the active-bank count (e.g. `antforth 3.x — 12 banks available — ok`). The count reflects pages that passed probe.
- **FR-P4-38 (`STARTUP.FTH` not the configuration mechanism):** Boot-time bank configuration happens via the command line, not via a `STARTUP.FTH` file. (This FR captures a deliberate design rejection from `docs/antforth-banking-redesign.md` §6: bank availability must be known at banner-print time, before any `.FTH` file could run.)
- **FR-P4-39 (default bank capacity):** With CL defaults, the system provides 12 banks × 16 KB = 192 KB user RAM. With the maximum CL bank-list (29 banks, sacrificing the virtual-console buffer at 0x24 and the RAM disk at 0x25–0x34), the system provides 29 banks × 16 KB = 464 KB user RAM.

### Backward Compatibility & Regression (phase-wide constraint)

- **FR-P4-40 (Phase-1+2+3 functional behaviour preserved):** All functional behaviour delivered in Phase 1 (Epics 1–8), Phase 2 (Epics 9–13.5), and Phase 3 (Epics 14–15) — REPL behaviour, colon definitions, variables, constants, `CREATE` / `DOES>`, control flow, error reporting, `MARKER`, `CATCH` / `THROW` (including caught-form for the asm-error block `-258..-272`), multi-vocabulary Search-Order, File-Access wordset, Forth-2014 §3.4.1.3 numeric-literal prefixes including `0x`, double-precision arithmetic, pictured numeric output, the unchanged hard-coded inline assembler, base-aware unprefixed parsing, and all existing word semantics — continues to work identically in every Phase-4 antforth 3.x point-release under the banked build.
- **FR-P4-41 (Phase-3 close-out test baseline):** All existing REPL-piped test scripts in the Phase-3 close-out baseline (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) continue to pass against every Phase-4 antforth 3.x point-release. Zero regressions on the baseline is a release blocker. Additional Phase-4 banking probes are welcome but additive.
- **FR-P4-42 (CODE-word source backward compatibility):** All existing CODE-word source files written against pre-Phase-4 antforth assemble correctly under every Phase-4 antforth 3.x point-release. CODE words defined at the REPL or in `.FTH` source produce byte-identical output to the pre-Phase-4 baseline when assembled into the same memory region (fixed memory or banked memory; cross-bank CODE-word policy is an architecture-stage open question per Implementation Considerations).
- **FR-P4-43 (`BANK*` wordset is additive):** The 12-word `BANK*` wordset is additive to the existing kernel wordlist. No pre-Phase-4 word changes name, stack effect, or semantics. Pre-Phase-4 `.FTH` files that do not call any `BANK*` word run unchanged under the banked build (they implicitly run in bank 0, the portal page).

**Self-validation summary:**

- ✅ **Coverage** — every capability surfaced in the Executive Summary, Success Criteria, User Journeys, and Project-Type sections is represented by at least one FR. Every word in the 12-word `BANK*` wordset has its own FR (FR-P4-1..FR-P4-12). Every architectural pillar from `docs/antforth-banking-redesign.md` (descriptor stubs, sentinel-trampoline EXIT, per-bank compiler state, bank-aware FIND, ABORT/QUIT restore, CL config) maps to its own FR group.
- ✅ **Traceability** — every FR is traceable to either the redesign doc (§-references in commentary) or the journey table. The Journey Requirements Summary cross-references J1–J6 to FR groups.
- ✅ **Altitude** — FRs describe WHAT capabilities exist, not HOW the kernel implements them. Where the (γ) mechanism, sentinel-trampoline, and per-bank dictionary triples are named, they are named because they constitute the user-visible / xt-contract / dispatch-cost surface — not as implementation directives.
- ✅ **Testability** — every FR can be verified by an observable outcome (REPL probe, hardware probe, byte-identical output, error path, return value, MMU port-write trace, etc.).
- ✅ **Independence** — each FR is understandable in isolation; cross-references are explicit pointers, not narrative dependencies.
- ✅ **Completeness bar** — if the system satisfies FR-P4-1..FR-P4-43, Phase 4's MVP gate is met.

**FR numbering note.** Phase-4 FRs use the `FR-P4-N` prefix (for "Phase 4") to distinguish them from the Phase-3 `FR-P3-N` set (now closed) and the Phase-2 FR1–FR47 set (carried forward via FR-P4-40). Cross-references to closed FRs in `prd-phase3-epics-14-15.md` and `prd-phase2-epics-9-13.5.md` use those documents' explicit FR labels.

## Non-Functional Requirements

> **Selective approach.** antforth is a single-user, single-machine, offline, hobby-scale retrocomputing tool. Categories that do not apply — **Security** (no network, no sensitive data, no auth), **Scalability** (one user, one 8-bit CPU), **Accessibility** (hardware-constrained; LED display is outside software control) — are explicitly omitted to avoid requirement bloat. Phase 4 carries forward the Phase-2 NFR1–NFR21 + Phase-3 NFR-P3-* sets with explicit "still holds" statements; new Phase-4-specific NFRs use the `NFR-P4-N` prefix and live under their natural category.

### Performance

- **NFR-P4-1 (carries Phase-2 NFR1–NFR5):** All performance envelopes from the Phase-2 PRD continue to hold across every Phase-4 antforth 3.x point-release. Specifically: numeric-literal prefix parse overhead ≤ ~20 Z80 cycles over unprefixed (NFR1); multi-vocabulary lookup regression ≤ 10% vs single-vocabulary baseline (NFR2); uncaught CATCH frame overhead ≤ ~15 Z80 cycles (NFR3); per-epic ROM-footprint budget logged and justified (NFR4); double-precision primitives within ~20% of hand-rolled Z80 equivalents (NFR5). No Phase-4 work measurably regresses any of these envelopes; if any banking story would, sprint-change-proposal evaluation is triggered.
- **NFR-P4-2 (bank-switch latency):** A `BANK!` operation completes in ≤ 60 Z80 T-states + the MMU port-write time. Measured at the granularity of "from the data-stack pop of the new bank index to the moment the new bank's `(here, latest, wordlist-heads)` triple is in effect."
- **NFR-P4-3 (cross-bank call overhead):** A cross-bank call (caller in one bank, target in a different bank) costs ≤ 60 Z80 T-states + the bank-switch time (NFR-P4-2). Measured at the granularity of "from the call site's `JP <stub>` to the first instruction of the target body in the new bank."
- **NFR-P4-4 (per-banked-word descriptor stub size):** Each banked-word descriptor stub occupies ≤ 5 bytes of fixed memory. The 1000-banked-words target absorbs ≤ 5 KB of total stub allocation.
- **NFR-P4-5 (banking infrastructure fixed-memory budget):** Total banking infrastructure occupies ≤ 8 KB of fixed memory at the 28-bank cap (~6 KB at the default 12 banks). Includes the CL parser + probe loop (~200 B), configuration words (~120 B), descriptor-stub allocator overhead, `cross_bank_return` trampoline, and bank-state-table (29 entries × ~16 B ≈ 448 B worst case).
- **NFR-P4-6 (FIND batch-loading regression envelope):** Bank-aware FIND incurs ≤ 5–15 % regression on batch-loading workloads (e.g. INCLUDE on a large file). Interactive FIND latency is invisible to the user (sub-frame at 8 MHz). Measured against the Phase-3 close-out FIND baseline.

### Reliability

- **NFR-P4-7 (carries Phase-2 NFR6 / Phase-3 NFR-P3-3 — REPL survivability):** The REPL survives any THROW, including stack overflow, division by zero, undefined-word invocation, and the asm-error THROW codes (-258..-272). User's dictionary, in-session definitions, and working state are preserved across errors. **Phase-4 delta:** REPL also survives any THROW raised across a bank boundary; the `cross_bank_return` trampoline restores the caller's bank on the unwind path so the user is not stranded in the wrong bank after a cross-bank THROW.
- **NFR-P4-8 (carries Phase-2 NFR7 / Phase-3 NFR-P3-4 — state integrity after error):** No internal data structure (dictionary, wordlists, input buffer, pad, return stack, FCB pool, INCLUDE source frames, bank-table[]) may be left in a corrupted or inconsistent state after a THROW. Standard ANS catch-frame cleanup semantics apply. **Phase-4 delta:** the bank-table[] entries (per-bank `(here, latest, wordlist-heads)` triples) are not corrupted by a mid-execution THROW; ABORT/QUIT bank-state restore (FR-P4-31..FR-P4-33) is the consistency guarantee.
- **NFR-P4-9 (carries Phase-2 NFR8 / Phase-3 NFR-P3-5 — filesystem error recovery):** Failures during file operations leave the filesystem in a consistent state — no partial writes that corrupt CP/M directory entries, no orphaned file handles. Carries forward unchanged from Phase 3 close-out.
- **NFR-P4-10 (Phase-4 test-baseline regression guarantee):** The complete Phase-3 close-out test suite (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) passes on every Phase-4 antforth 3.x point-release candidate. A single regression on any of the 974 tests is a release blocker. Additional Phase-4 banking probes are welcome but additive — they do not replace the baseline.
- **NFR-P4-11 (mid-epic hardware-smoke cadence per story — codifies S9):** Every binary-delta Phase-4 story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast with a PASS verdict before the story is considered done. Zero-binary-delta stories document their S9 exemption explicitly.

### Compatibility & Standards Conformance

- **NFR-P4-12 (carries Phase-2 NFR10 / Phase-3 NFR-P3-8 — ANS Forth 1994 Core compliance):** The Core wordset (DPANS94 §6.1) is implemented to 100% coverage, **§-level defensible**, with behaviour matching the ANS specification (per the Phase-3 A.1 §-by-§ audit). Phase 4 inherits this commitment; any new Core or Core-Extension word adds its own §-level row in `docs/ans-forth-core-compliance.md`.
- **NFR-P4-13 (carries Phase-2 NFR11 — Forth 2014 §3.4.1.3 conformance):** Numeric-literal prefix syntax is implemented verbatim per Forth 2014 §3.4.1.3. Carried forward unchanged from v2.0 / Phase-3 close-out.
- **NFR-P4-14 (extension discipline; Phase-4 delta — banking words are antforth extensions):** The non-standard additions are the existing extensions (`0x` hex-literal prefix, `INCLUDE-TOP` / `CATCH-TOP` USER-variables, asm-error THROW codes `-258..-272`) plus the new 12-word `BANK*` wordset. ANS Forth does not standardise banked memory; all 12 banking words are flagged in source per CCD-3 (`; antforth extension <word> — <design reason>`) with a design-reason note pointing at `docs/antforth-banking-redesign.md`.
- **NFR-P4-15 (carries Phase-2 NFR13 / Phase-3 NFR-P3-11 — CP/M 2.2 BDOS integration):** antforth uses only CP/M 2.2 standard BDOS functions (the existing allow-list: 0, 1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40). **Phase 4 does not add any new BDOS functions to the allow-list.** BDOS calls (`CALL 0005h`) work unchanged from banked code (BDOS at $DC00–$E9FF lives in fixed memory).
- **NFR-P4-16 (carries Phase-2 NFR14 / Phase-3 NFR-P3-12 — CODE-word source file backward compatibility):** CODE-word source files written against pre-Phase-4 antforth assemble correctly and produce byte-identical output under every Phase-4 antforth 3.x point-release when assembled into the same memory region. Cross-bank CODE-word policy is an architecture-stage open question.
- **NFR-P4-17 (carries Phase-3 NFR-P3-13 — §-level compliance auditability):** `docs/ans-forth-core-compliance.md` carries enough information per row (§-number, source `file:line`, story-number for closure, caveats) that an external Forth implementor can verify any single row against the standard text and the source code in under 10 minutes. Carried forward unchanged.

### Maintainability

- **NFR-P4-18 (carries Phase-2 NFR15 / Phase-3 NFR-P3-14 — code density and readability):** Z80 assembly source favours readability over micro-optimisation, except where the epic explicitly targets performance. Comments on non-obvious logic are required; comments re-stating what assembly already says are forbidden. **Phase-4 specifically:** banking infrastructure code (descriptor-stub allocator, `cross_bank_return` trampoline, per-bank dictionary swap) carries inline commentary referencing `docs/antforth-banking-redesign.md` §-numbers.
- **NFR-P4-19 (carries Phase-2 NFR16 / Phase-3 NFR-P3-15 — test-first discipline):** Every new word, every behaviour change, and every defect closure introduced in Phase 4 has REPL-piped Forth test coverage before being declared done (per S2). Test scripts are the canonical regression surface. **Phase-4 specifically:** banking probes are dual-tracked — the banking-capable emulator carries the cross-bank assertions; iz-cpm carries the non-banking regression baseline; hardware is the load-bearing final word.
- **NFR-P4-20 (carries Phase-2 NFR17 / Phase-3 NFR-P3-16 — single-source-of-truth for standards references):** Word behaviours that derive from a standard cite the standard section in the source comment per CCD-3. Banking-extension words cite `docs/antforth-banking-redesign.md` instead of an external standard.
- **NFR-P4-21 (carries Phase-2 NFR18 / Phase-3 NFR-P3-17 — epic-level decoupling):** Each Phase-4 epic delivers an independently-shippable antforth 3.x point-release. Intermediate releases are legitimate release artifacts. The Phase-4 close-out tag is the antforth 3.x version after Epic 22 ships.
- **NFR-P4-22 (carries Phase-3 NFR-P3-18 — story-template discipline as quality attribute):** The story-template lints / HALT signals / pre-edit task additions established by Phase-3 (B.1–B.5) fire automatically when triggered. Carried forward unchanged for Phase 4.

### Integration (CP/M and Platform)

- **NFR-P4-23 (carries Phase-2 NFR19 / Phase-3 NFR-P3-19 — terminal I/O portability):** antforth uses only character-based BDOS console I/O (functions 1, 2, 6, 9). No assumption of ANSI escape codes, cursor positioning, line-mode vs raw-mode toggles, or colour support.
- **NFR-P4-24 (carries Phase-2 NFR20 / Phase-3 NFR-P3-20 — file path conventions):** `INCLUDE` and related words accept CP/M 2.2 file path syntax (optional drive letter + `:` + 8.3 filename) exactly. No wildcards in scope; no Unix-style paths.
- **NFR-P4-25 (carries Phase-2 NFR21 / Phase-3 NFR-P3-21 — MicroBeast hardware dependency isolation):** No MicroBeast-specific hardware word (timer, GPIO, LED matrix, beeper, UART, I²C, RTC) enters the kernel during Phase 4. The MicroBeast hardware vocabulary is a Phase-5+ epic (E.1) and must be loadable as pure Forth source from disk, not kernel-resident. **The 12-word `BANK*` wordset is the exception:** banking control is platform-specific (MicroBeast MMU port assignments) but is explicitly kernel-resident because it is a memory-model primitive, not a peripheral.
- **NFR-P4-26 (ISR-from-fixed-memory-only invariant):** No banked code is reachable from any interrupt vector. ISR bodies live in fixed memory only. Any kernel code that runs in interrupt context (timer ISR, peripheral ISR if added in a future phase) executes against fixed memory regardless of which user bank is active. The MMU port writes that bank-switch are non-atomic from the ISR vantage; an ISR firing mid-`BANK!` is safe because the ISR body does not depend on which user bank is mapped.
- **NFR-P4-27 (BDOS calls work unchanged from banked code):** A `CALL 0005h` from any bank-resident user word lands in fixed memory (BDOS at $DC00–$E9FF). The `CALL` itself executes in the caller's bank; the return address is pushed in the caller's stack frame; on `RET` the BDOS returns to the caller's bank context. No bank-switching glue is required around BDOS calls.

### Process Discipline (S1–S12 standing commitments)

These NFRs codify the 12 standing process commitments (S1–S12 from the Epic 13.5 retro) as Phase-4 quality attributes. Each must hold across every Phase-4 epic close-out. Carried forward from Phase 3 unchanged.

- **NFR-P4-28 (S1 — adversarial review fresh-context external):** Code reviews are conducted via the `/CR` command (fresh-context external) per the post-PD-1 structural close, not in-pass within the dev-pass. Every Phase-4 retro confirms continued hold of this commitment.
- **NFR-P4-29 (S2 — REPL-piped tests as default):** New tests in Phase 4 are REPL-piped Forth scripts, not assembly test thread extensions. Probes follow S12 hardware-typed authoring discipline.
- **NFR-P4-30 (S3 — real-byte-count estimation + capstone-aware drafting):** Story byte-budget rationale is itemised per-part, not asserted via "mirrors prior arm" shorthand. The Phase-3 story-template lint catches the shorthand pattern.
- **NFR-P4-31 (S4 — AC-composition validation):** Story acceptance criteria are validated for composability — each AC stands alone or in composition with its named antecedents; no AC silently depends on another's side-effects.
- **NFR-P4-32 (S5 — PARTIAL → HALT):** PARTIAL verdicts trigger a HALT signal at the dev-pass; root-cause is handled in-pass or the story spawns a sibling, with no carry-forward as tech debt.
- **NFR-P4-33 (S6 — inventory grep covers helpers, not just leaves):** Story inventory grep walks the helper layer not just the user-facing word, ensuring fan-in completeness.
- **NFR-P4-34 (S7 — EXX-hygiene per kernel-internal raise site):** Kernel sites that raise THROW preserve EXX state per the established §3 leaf-level rule and §7 EXX-using inventory in `docs/register-conventions.md`. **Phase-4 specifically:** the `cross_bank_return` trampoline and any Phase-4 kernel addition that can raise THROW re-walks this rule in its CCD-3 review.
- **NFR-P4-35 (S8 — "pre-existing" cannot discharge correctness defects):** Per `feedback_no_preexisting_discharge.md`, correctness defects (clobbers, lost writes, silent error swallowing) cannot be marked "accepted-with-rationale: pre-existing" — they must be surfaced, filed, fixed (or explicitly re-prioritised down with project-lead approval).
- **NFR-P4-36 (S9 — mid-epic hardware-smoke cadence per story):** Codified as NFR-P4-11 above (binary-delta stories run their own S9 hardware-smoke).
- **NFR-P4-37 (S10 — workflow > memory > prompt):** Process / discipline fixes land in workflow files (BMAD step files, story templates, agent definitions) and codified-discipline files (memory entries, `feedback_*.md`), not in conversational prompts.
- **NFR-P4-38 (S11 — user-visible version surface audit row at tag-applicable epic close-out):** Every Phase-4 antforth 3.x point-release tag passes the user-visible version surface audit (banner string in binary, README version reference, memory-file `description` fields). Mismatches against the tag being applied are HALT signals.
- **NFR-P4-39 (S12 — hardware-typed probe authoring discipline):** Every smoke-batch destined for human typing on real hardware passes (a) word-existence pre-flight (every word resolves in antforth's dictionary or is documented as a planned new word) and (b) TIB-128 line-length lint (every line ≤ 128 chars).
