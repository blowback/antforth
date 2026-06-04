---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
phase: 4
phaseScope: 'Phase 4 — banked-RAM enablement (Epics 16–22)'
lastEdited: '2026-05-10'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics-phase3-epics-14-15.md
  - _bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md
  - _bmad-output/implementation-artifacts/epic-14-retro-2026-05-09.md
  - _bmad-output/implementation-artifacts/epic-15-retro-2026-05-09.md
  - docs/antforth-banking-redesign.md
  - docs/PHASE-3-CARRY-FORWARD.md
  - docs/WISHLIST.md
  - docs/ans-forth-core-compliance.md
  - docs/register-conventions.md
  - docs/throw-codes.md
---

# antforth - Epic Breakdown (Phase 4 — banked-RAM enablement, Epics 16–22)

## Overview

This document provides the complete epic and story breakdown for **antforth Phase 4 — banked-RAM enablement**, decomposing requirements from `prd.md` (FR-P4-1..43, NFR-P4-1..39) and `architecture.md` (PD-P4-1..10 plus Phase-4 file-touch surface) into implementable stories across **Epics 16–22**. Phase 4 ships **antforth 3.x point-releases**, one per epic close-out, on top of the v2.0 + Phase-3-close-out baseline (974 PASS / 0 FAIL).

## Requirements Inventory

### Functional Requirements

#### Banking Wordset (FR-P4-1..12)

- **FR-P4-1 (`BANK@`):** `BANK@ ( -- n )` returns the current logical bank index (index into the active bank list, not the physical page number). Available at the REPL and inside colon definitions.
- **FR-P4-2 (`BANK!`):** `BANK! ( n -- )` switches the current logical bank to `n`; swaps the per-bank `(here, latest, wordlist-heads)` triple. If `n` is not in the active bank list, raises `ABORT" bank?"`. Available at the REPL and inside colon definitions.
- **FR-P4-3 (`BANKS`):** `BANKS ( -- n )` returns the count of currently-available banks (a `VALUE` derived from the active bank-list length). Updated by `+BANK` / `-BANK` / `BANKS-CLEAR`.
- **FR-P4-4 (`IN-BANK`):** `IN-BANK ( n xt -- )` saves current bank, switches to bank `n`, executes `xt`, restores the saved bank on exit. **Kernel-blessed** (not user library). CATCH-safe: a THROW inside `xt` still restores caller's bank. Reference body: `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;`.
- **FR-P4-5 (`BANK-OF`):** `BANK-OF ( xt -- n )` returns the bank a word lives in. `n = -1` for words in fixed memory. Implemented as one-byte read from descriptor stub at `xt` (free under FR-P4-13).
- **FR-P4-6 (`.BANKS`):** `.BANKS ( -- )` prints status table: logical bank index, physical page, current marker, used / free per bank, totals.
- **FR-P4-7 (`+BANK`):** `+BANK ( page -- )` adds a physical page to the active bank list. Probes the page (write-sentinel / read-back / restore); raises `ABORT" probe?"` if page is ROM, unmapped, or unstable; on success `BANKS` increments by one.
- **FR-P4-8 (`-BANK`):** `-BANK ( page -- )` removes a physical page from the active bank list. Does not affect underlying memory. After removal, `BANKS` decrements by one. No-op (no THROW) if page not in active list.
- **FR-P4-9 (`BANKS-CLEAR`):** `BANKS-CLEAR ( -- )` empties the active bank list. After invocation, `BANKS` returns 0; `BANK!` raises `ABORT" bank?"` until `+BANK` rebuilds the list.
- **FR-P4-10 (`SET-BANK`):** `SET-BANK ( page slot -- )` raw MMU port write of `page` into MMU `slot`. Bypasses `bank-table[]`; diagnostics only; no validation.
- **FR-P4-11 (`BANK-MAPPING-ON`):** `BANK-MAPPING-ON ( -- )` enables MMU mapping hardware. Auto-run in `COLD`.
- **FR-P4-12 (`BANK-MAPPING-OFF`):** `BANK-MAPPING-OFF ( -- )` triggers CP/M warm-boot escape via BIOS WBOOT (`JP $0000`); returns to a healthy `B>` CCP prompt. Does **not** write the MMU mapping hardware bit — port 0x74 write from kernel-resident code disconnects RAM mid-instruction-fetch and traps into firmware reset (Story 17.1 AC10 hardware finding).

#### Cross-Bank Dispatch — descriptor-stub mechanism (FR-P4-13..17)

- **FR-P4-13 (per-word descriptor stub):** Every word defined in a bank gets a 3–5-byte descriptor stub allocated in fixed memory at definition time, carrying `(target_bank, target_addr_in_bank)`. **The stub's address is the word's xt.** Words defined in fixed memory carry `target_bank = -1`.
- **FR-P4-14 (transparent compiler emission):** `COMPILE,` always emits the stub address (the word's xt). Compiler does not inspect whether target is in same bank as call site — the stub handles dispatch at run time. Source text for `:`-defined words is identical to flat-memory antforth.
- **FR-P4-15 (intra-bank dispatch overhead):** Intra-bank call goes through stub with one extra `JP` overhead vs flat dispatch. No MMU port write.
- **FR-P4-16 (cross-bank dispatch overhead):** Cross-bank call costs ≤ 60 T-states + MMU port-write time. Stub switches MMU to target bank, pushes sentinel-tagged 3-cell return frame (FR-P4-18), jumps to target body.
- **FR-P4-17 (xt portability):** xt obtained via `'` or `[']` is a stub address in fixed memory. xts are stable across `BANK!` calls and may be passed across bank boundaries on the data stack without modification.

#### Cross-Bank EXIT — sentinel-trampoline (FR-P4-18..21)

- **FR-P4-18 (sentinel-tagged cross-bank return):** Cross-bank call pushes three cells onto the return stack: `(sentinel_addr, caller_bank, target_addr)`. `sentinel_addr` is the address of the `cross_bank_return` trampoline in fixed memory; kernel `EXIT` recognises it.
- **FR-P4-19 (intra-bank zero-overhead path):** Intra-bank call pushes one cell (standard ANS return frame). Intra-bank `EXIT` decodes the standard frame; no sentinel-check overhead beyond a single CP against the sentinel address.
- **FR-P4-20 (cross-bank-return trampoline):** A `cross_bank_return` trampoline lives in fixed memory. When `EXIT` encounters the sentinel, the trampoline restores the caller's bank by writing `caller_bank` to the MMU and jumps to `target_addr`.
- **FR-P4-21 (recursive cross-bank R-stack):** Recursive cross-bank calls accumulate 3-cell return frames. No hard limit beyond existing return-stack depth limit; runaway recursion raises standard `-5 RETURN-STACK-OVERFLOW` THROW. (Per redesign §9.6 closure 2026-05-14: documented-gotcha; no runtime guard added — see `_bmad-output/planning-artifacts/architecture.md` PD-P4-12.)

#### Bank-Aware Compiler (FR-P4-22..26)

- **FR-P4-22 (per-bank dictionary state):** Each bank carries its own `(here, latest, wordlist-heads)` triple in fixed-memory `bank-table[]` indexed by logical bank number. `BANK!` swaps the active triple atomically.
- **FR-P4-23 (per-bank `,` and `COMPILE,`):** `,` writes a cell at the current bank's `here` and advances `here`. `COMPILE,` writes an xt (stub address in fixed memory) at the current bank's `here` and advances. Cross-bank `,` is not exposed.
- **FR-P4-24 (`:` lands body in current bank):** `:` allocates word body at the current bank's `here`, allocates descriptor stub in fixed memory, links into the current bank's `latest`, updates current wordlist's chain. After `;`, the new word's xt is the stub address.
- **FR-P4-25 (`CREATE` / `DOES>` cross-bank explicit):** `CREATE` allocates a doer-stub in fixed memory + a data cell in current bank's data space; PFA stores doer-stub address paired with data cell. `DOES>` reassigns the doer-stub's target. Cross-bank `CREATE`/`DOES>` patterns are user-explicit; no auto-redirect across banks.
- **FR-P4-26 (`HERE` / `LATEST` per bank):** `HERE` returns the current bank's `here`; `LATEST` returns the current bank's `latest`. Cross-bank pointer hazards documented as gotchas (no runtime guard) per redesign §5.4.

#### Bank-Aware FIND (FR-P4-27..30)

- **FR-P4-27 (per-wordlist `bank` field):** Each wordlist carries a `bank` field naming the bank its head chain lives in. System wordlists (FORTH, ASSEMBLER) tagged `bank = fixed` (-1). User wordlists default to the bank they were created in.
- **FR-P4-28 (FIND traversal):** `FIND` saves current bank, switches to wordlist's bank, walks chain, restores saved bank, returns result. Words in `bank = fixed` wordlists incur no MMU switch.
- **FR-P4-29 (`WORDS` traverses banks):** `WORDS` lists words across the current search order, switching banks per wordlist's `bank` field. Bank switches invisible in output (annotation deferred post-MVP).
- **FR-P4-30 (error messages name source bank):** Lookup-failure error messages for any word in a non-default-bank wordlist include bank context in the error text.

#### ABORT/QUIT Bank-State Restore (FR-P4-31..33)

- **FR-P4-31 (saved current-bank on outermost interactive `BANK!`):** Each interactive `BANK!` from the outermost interpret loop updates a kernel-internal "saved current bank" cell.
- **FR-P4-32 (`QUIT` re-asserts saved bank):** `QUIT` re-asserts the saved current bank when re-entering the outermost interpret loop. `IN-BANK`'s save/restore (FR-P4-4) is independent — it operates within nested execution; this FR governs the outermost loop only.
- **FR-P4-33 (`ABORT` bank-state):** `ABORT` (and `ABORT"`) unwinds the data stack and return stack and re-enters `QUIT`, which re-asserts saved current bank per FR-P4-32.

#### Boot Configuration (FR-P4-34..39)

- **FR-P4-34 (CL parser syntax):** Interpreter accepts CL tail `antforth <portal-page> <bank-list>` (e.g. `antforth 24 35-3f`). `<portal-page>` = single hex byte naming MMU slot 2 page assignment. `<bank-list>` = hex range or list naming physical pages to seed into the active bank list.
- **FR-P4-35 (CL parser defaults):** Absent a CL tail, defaults `22 35-3F` apply (portal page 0x22, banks 0x35..0x3F = 11 banks); 12 total counting the portal page as bank 0.
- **FR-P4-36 (CL parser probe-on-add):** Each page in `<bank-list>` is probed before being added (same probe as FR-P4-7). Pages that fail probe produce a one-line warning to console and are excluded; parsing does not abort on a single bad page.
- **FR-P4-37 (banner shows bank count):** Boot banner includes the active-bank count (e.g. `antforth 3.x — 12 banks available — ok`); count reflects pages that passed probe.
- **FR-P4-38 (`STARTUP.FTH` not the configuration mechanism):** Boot-time bank configuration happens via the command line, not via `STARTUP.FTH`. Bank availability must be known at banner-print time, before any `.FTH` file could run.
- **FR-P4-39 (default bank capacity):** With CL defaults, system provides 12 banks × 16 KB = 192 KB user RAM. With max CL bank-list (29 banks, sacrificing the virtual-console buffer at 0x24 and the RAM disk at 0x25–0x34), system provides 29 banks × 16 KB = 464 KB user RAM.

#### Backward Compatibility & Regression — phase-wide constraint (FR-P4-40..43)

- **FR-P4-40 (Phase-1+2+3 functional behaviour preserved):** All functional behaviour delivered in Phases 1–3 — REPL behaviour, colon definitions, variables/constants, `CREATE`/`DOES>`, control flow, error reporting, `MARKER`, `CATCH`/`THROW` (incl. caught-form for asm-error block -258..-272), multi-vocabulary Search-Order, File-Access wordset, Forth-2014 §3.4.1.3 numeric-literal prefixes (incl. `0x`), double-precision arithmetic, pictured numeric output, hard-coded inline assembler, base-aware unprefixed parsing — continues to work identically in every Phase-4 antforth 3.x point-release under the banked build.
- **FR-P4-41 (Phase-3 close-out test baseline):** All existing REPL-piped test scripts in the Phase-3 close-out baseline (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) continue to pass against every Phase-4 antforth 3.x point-release. Zero regressions is a release blocker.
- **FR-P4-42 (CODE-word source backward compatibility):** All existing CODE-word source files written against pre-Phase-4 antforth assemble correctly under every Phase-4 antforth 3.x point-release. Cross-bank CODE-word policy is an architecture-stage open question (§9.1).
- **FR-P4-43 (`BANK*` wordset is additive):** The 12-word `BANK*` wordset is additive to the existing kernel wordlist. No pre-Phase-4 word changes name, stack effect, or semantics. Pre-Phase-4 `.FTH` files that do not call any `BANK*` word run unchanged under the banked build (implicitly in bank 0 / portal page).

### NonFunctional Requirements

#### Performance (NFR-P4-1..6)

- **NFR-P4-1 (carries Phase-2 NFR1–NFR5):** Phase-2 performance envelopes hold across every Phase-4 release: numeric-literal prefix parse overhead ≤ ~20 Z80 cycles over unprefixed; multi-vocabulary lookup regression ≤ 10% vs single-vocabulary baseline; uncaught CATCH frame overhead ≤ ~15 Z80 cycles; per-epic ROM-footprint budget logged and justified; double-precision primitives within ~20% of hand-rolled Z80 equivalents.
- **NFR-P4-2 (bank-switch latency):** A `BANK!` operation completes in ≤ 60 Z80 T-states + the MMU port-write time.
- **NFR-P4-3 (cross-bank call overhead):** A cross-bank call costs ≤ 60 Z80 T-states + the bank-switch time (NFR-P4-2). Measured from call site's `JP <stub>` to first instruction of target body in the new bank.
- **NFR-P4-4 (per-banked-word descriptor stub size):** Each banked-word descriptor stub occupies ≤ 5 bytes of fixed memory. The 1000-banked-words target absorbs ≤ 5 KB of total stub allocation.
- **NFR-P4-5 (banking infrastructure fixed-memory budget):** Total banking infrastructure occupies ≤ 8 KB of fixed memory at the 28-bank cap (~6 KB at default 12 banks).
- **NFR-P4-6 (FIND batch-loading regression envelope):** Bank-aware FIND incurs ≤ 5–15 % regression on batch-loading workloads. Interactive FIND latency invisible to the user. Measured against Phase-3 close-out FIND baseline.

#### Reliability (NFR-P4-7..11)

- **NFR-P4-7 (REPL survivability incl. cross-bank):** REPL survives any THROW, including across a bank boundary; the `cross_bank_return` trampoline restores caller's bank on the unwind path.
- **NFR-P4-8 (state integrity after error, incl. bank-table[]):** No internal data structure (dictionary, wordlists, input buffer, pad, return stack, FCB pool, INCLUDE source frames, **bank-table[]**) may be left in a corrupted or inconsistent state after a THROW.
- **NFR-P4-9 (filesystem error recovery):** Carries forward unchanged from Phase 3 — failures during file operations leave the filesystem in a consistent state.
- **NFR-P4-10 (Phase-4 test-baseline regression guarantee):** Complete Phase-3 close-out test suite (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) passes on every Phase-4 antforth 3.x point-release candidate. A single regression is a release blocker.
- **NFR-P4-11 (mid-epic hardware-smoke cadence per story — codifies S9):** Every binary-delta Phase-4 story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast with a PASS verdict before story is considered done. Zero-binary-delta stories document their S9 exemption explicitly.

#### Compatibility & Standards Conformance (NFR-P4-12..17)

- **NFR-P4-12 (ANS Forth 1994 Core compliance):** Core wordset (DPANS94 §6.1) implemented to 100% coverage, §-level defensible. Phase 4 inherits this; any new Core/Core-Extension word adds its own §-level row.
- **NFR-P4-13 (Forth 2014 §3.4.1.3 conformance):** Numeric-literal prefix syntax verbatim per Forth 2014 §3.4.1.3. Carried forward unchanged.
- **NFR-P4-14 (extension discipline; banking words are antforth extensions):** All 12 `BANK*` words flagged in source per CCD-3 (`; antforth extension <word> — <design reason>`) with a §-reference to `docs/antforth-banking-redesign.md`.
- **NFR-P4-15 (CP/M 2.2 BDOS allow-list unchanged):** Phase 4 does not add any new BDOS functions to the existing allow-list.
- **NFR-P4-16 (CODE-word source byte-identical regression):** CODE-word source files assemble correctly and produce byte-identical output under every Phase-4 release (same memory region). Cross-bank CODE-word policy is an architecture-stage open question.
- **NFR-P4-17 (§-level compliance auditability):** `docs/ans-forth-core-compliance.md` rows verifiable in under 10 minutes per row.

#### Maintainability (NFR-P4-18..22)

- **NFR-P4-18 (code density and readability):** Z80 assembly source favours readability over micro-optimisation. Banking infrastructure code carries inline commentary referencing redesign-doc §-numbers.
- **NFR-P4-19 (test-first discipline):** Every new word, behaviour change, defect closure has REPL-piped Forth test coverage before being declared done (S2). Banking probes dual-tracked across banking-capable emulator + iz-cpm; hardware is the load-bearing final word.
- **NFR-P4-20 (single-source-of-truth for standards references):** Word behaviours derived from a standard cite the standard section in source comment per CCD-3. Banking-extension words cite `docs/antforth-banking-redesign.md`.
- **NFR-P4-21 (epic-level decoupling):** Each Phase-4 epic delivers an independently-shippable antforth 3.x point-release.
- **NFR-P4-22 (story-template discipline as quality attribute):** Story-template lints / HALT signals / pre-edit task additions established by Phase-3 (B.1–B.5) fire automatically when triggered.

#### Integration — CP/M and Platform (NFR-P4-23..27)

- **NFR-P4-23 (terminal I/O portability):** antforth uses only character-based BDOS console I/O (functions 1, 2, 6, 9). No assumption of ANSI escape codes, cursor positioning, line-mode toggles, or colour.
- **NFR-P4-24 (file path conventions):** `INCLUDE` and related words accept CP/M 2.2 file path syntax (optional drive letter + `:` + 8.3 filename). No wildcards in scope; no Unix-style paths.
- **NFR-P4-25 (MicroBeast hardware dependency isolation):** No MicroBeast-specific hardware word (timer, GPIO, LED matrix, beeper, UART, I²C, RTC) enters the kernel during Phase 4. Banking control is the explicit exception (it's a memory-model primitive, not a peripheral).
- **NFR-P4-26 (ISR-from-fixed-memory-only invariant):** No banked code is reachable from any interrupt vector. ISR bodies live in fixed memory only. MMU port writes are non-atomic from the ISR vantage.
- **NFR-P4-27 (BDOS calls work unchanged from banked code):** A `CALL 0005h` from any bank-resident user word lands in fixed memory (BDOS at $DC00–$E9FF). No bank-switching glue required around BDOS calls.

#### Process Discipline — S1–S12 standing commitments (NFR-P4-28..39)

- **NFR-P4-28 (S1 — adversarial review fresh-context external):** Code reviews via `/CR` command (fresh-context external) per post-PD-1 structural close.
- **NFR-P4-29 (S2 — REPL-piped tests as default):** New Phase-4 tests are REPL-piped Forth scripts, not assembly test thread extensions; probes follow S12 hardware-typed authoring discipline.
- **NFR-P4-30 (S3 — real-byte-count estimation + capstone-aware drafting):** Story byte-budget rationale itemised per-part, not asserted via "mirrors prior arm" shorthand.
- **NFR-P4-31 (S4 — AC-composition validation):** Story acceptance criteria validated for composability — each AC stands alone or in composition with its named antecedents.
- **NFR-P4-32 (S5 — PARTIAL → HALT):** PARTIAL verdicts trigger a HALT signal at the dev-pass; root-cause handled in-pass or story spawns a sibling.
- **NFR-P4-33 (S6 — inventory grep covers helpers, not just leaves):** Story inventory grep walks the helper layer, not just the user-facing word.
- **NFR-P4-34 (S7 — EXX-hygiene per kernel-internal raise site):** Kernel sites that raise THROW preserve EXX state per established §3 leaf-level rule. The `cross_bank_return` trampoline and any Phase-4 kernel addition that can raise THROW re-walks this rule in its CCD-3 review.
- **NFR-P4-35 (S8 — "pre-existing" cannot discharge correctness defects):** Per `feedback_no_preexisting_discharge.md` — correctness defects must be surfaced, filed, fixed.
- **NFR-P4-36 (S9 — mid-epic hardware-smoke cadence per story):** Codified as NFR-P4-11.
- **NFR-P4-37 (S10 — workflow > memory > prompt):** Process / discipline fixes land in workflow files and codified-discipline files, not in conversational prompts.
- **NFR-P4-38 (S11 — user-visible version surface audit row at tag-applicable epic close-out):** Every Phase-4 antforth 3.x point-release tag passes the user-visible version surface audit (banner, README version, memory-file `description` fields).
- **NFR-P4-39 (S12 — hardware-typed probe authoring discipline):** Every smoke-batch destined for human typing on real hardware passes (a) word-existence pre-flight and (b) TIB-128 line-length lint.

### Additional Requirements

#### From Architecture (`architecture.md`)

- **No starter template / no project-init story.** Phase 4 is brownfield; the "starter" is the Phase-3-close-out working tree (24,995-byte `build/antforth.com`, 974 PASS / 0 FAIL on real CP/M 2.2 / MicroBeast). No Epic 1 Story 1 scaffolding work needed.
- **New kernel file:** `src/banking.asm` — descriptor-stub allocator, sentinel-trampoline cross-bank EXIT (`cross_bank_return` at a fixed address), MMU port wrappers, `bank-table[]` allocator, `BANK!` swap routine, the 12 banking-word assembly bodies.
- **New test file:** `tests/banking_tests.fth` — REPL probes for the 12 wordset words + cross-bank dispatch round-trip + ABORT/QUIT bank-restore + boot-config edge cases; per-probe annotation of which test surface (banking-capable emulator / iz-cpm / hardware) the probe targets.
- **CCP eviction (PD-P4-6):** evict CCP from `$D400–$DBFF` (+2 KB Page-3 headroom) — one-line memory-map change in `src/antforth.asm`. CP/M warm-boot reloads CCP from disk on user's next `^C` (verification needed in Epic 16, F3 in arch findings).
- **Banking-capable emulator dual-track (PD-P4-9):** Epic 16.3 vendor-pick prework gate is the load-bearing sequencing constraint — blocks Epic 17+ story-writing because every banking-touching probe must specify which emulator surface it targets. Three pinned eval criteria: (1) models 32-page MMU at ports `0x70+slot / 0x74`; (2) pipe-able for `make test-repl`-style automation; (3) bank-visibility for tests.
- **Three-test-surface discipline:** binary-delta stories run on iz-cpm + banking-capable emulator + real MicroBeast. Test surface expands from 1 → 3 once Epic 16.3 closes.
- **`Makefile` extension:** new `make test-repl-banking` (or equivalent) target per Epic 16.3 vendor pick; iz-cpm-only path preserved for the 974-PASS baseline.
- **`.tool-versions` extension:** add the banking-capable emulator vendor entry once selected.
- **UserArea cells added (`src/structures.asm`):** `saved-bank`, `current-bank`, `bank-table-base`, `bank-mapping-state`.
- **Existing kernel files extended at narrow chokepoints:** `src/inner_interpreter.asm` (`EXIT` sentinel branch + `EXECUTE` stub dispatch), `src/compiler.asm` (`COMPILE,` always emits stub address; `:` allocates stub), `src/dictionary.asm` (per-wordlist `bank` field on `FIND`; per-bank dictionary tail for MARKER), `src/wordlists.asm` (system wordlists tagged `bank=fixed`; `WORDS` traverses banks), `src/memory.asm` (`HERE`, `LATEST`, `,`, `C,` per-bank), `src/system.asm` (`ABORT`/`ABORT"` leave saved-bank intact; CCP-eviction memory-map edit), `src/outer_interpreter.asm` (`QUIT` re-asserts saved bank; outermost `BANK!` recogniser), `src/exception.asm` (verify `.throw_uncaught` recovery interacts correctly with cross-bank frames), `src/antforth.asm` (CL parser, banner update, auto-`BANK-MAPPING-ON` in COLD).
- **Six architecture-stage open questions** (`docs/antforth-banking-redesign.md` §9.1–§9.6) to be resolved by Epic-16 spike stories before downstream epics depend on them:
  - §9.1 — Cross-bank CODE-words decision (affects Epic 22 dispatch policy)
  - §9.3 — CL parser edge-case policy (no args / bad token / reverse range / dup / probe-fail / empty surviving list)
  - §9.4 — `+BANK` past `bank-table[]` cap (29 entries) policy
  - §9.5 — Stub size pinning (3 vs 4–5 bytes; affects per-1000-words cost)
  - §9.6 — Cross-bank R-stack overflow disposition (documented gotcha vs runtime guard; default = documented-gotcha unless hardware repro forces upgrade)
  - (§9.2 is the legacy redesign-doc question slot, currently unallocated.)
- **CCD carry-forward (no re-decision):** CCD-1 dual-chain frame discipline; CCD-2 THROW code allocation (Phase 4 allocates **no** new THROW codes; uses standard `-9 invalid memory address` / `-13 undefined word` plus existing `-258..-272` block; `BANK!`/`+BANK` failures use ABORT" decoded via existing -2 allocation); CCD-3 standards-citation discipline (banking words flagged `; antforth extension` with redesign-doc §-reference); CCD-4 per-epic benchmark gate (Phase 4 also tracks banked-word stub-count metric); CCD-P3-1 §-level compliance-doc row schema (12 banking-word rows added flagged as `Implemented (antforth extension)`); CCD-P3-2 process-discipline-in-workflow-files convention.
- **Per-tag close-out (S11 / NFR-P4-38) artifacts touched on every Phase-4 antforth 3.x point-release:** `src/antforth.asm` banner string; `README.md` version reference; memory-file `description` fields citing antforth version (e.g., a Phase-4 successor to `project_phase3_scope.md`); `make check-doc-sync` clean-pass; verdict-table walk per Story-13.5.6 precedent.
- **Files SUPERSEDED:** `docs/antforth-banking-design.md` (banner-marked SUPERSEDED — the obsolete 2026-05-07 sketch with the broken `BIT 7,H` heuristic and `THUNK-TO-USER-BANKn` family); preserved only for design-evolution traceability.
- **Files explicitly NOT touched in Phase 4:** `src/assembler.asm` (per `project_assembler_keep_assembly.md`); `src/file_access.asm` (Epic 13.5 close-out — BDOS lives in fixed memory, banking doesn't change BDOS call semantics); `src/strings.asm` (post-A.3); the Phase-1/2 frozen subsystems (`hash`, `control_flow`, `io`, `arithmetic`, `logic`, `stack_ops`, `double`, `pictured`, `formatting`, `number_prefixes`, `bootstrap`, `macros`, `constants`); `disk/`, `build/`, `examples/`, `blog/`, `images/`, `reference_docs/`, `node_modules/`.

#### From PRD (cross-cutting non-FR/NFR commitments)

- **Phase-4 ships antforth 3.x point-releases** — one per epic close-out (NFR-P4-21). The Phase-4 close-out tag is the antforth 3.x version after Epic 22 ships.
- **Default 12-banks (192 KB user RAM); theoretical max 29 banks (464 KB user RAM)** sacrificing the virtual-console buffer at 0x24 and the RAM disk at 0x25–0x34.
- **Compiler-transparent banking is the north-star UX:** banked `:` indistinguishable from flat `:`; existing programs run unmodified; user does not type thunk words, does not annotate cross-bank calls, does not see banking semantics in source.
- **The 12-word `BANK*` wordset is locked:** `BANK@ BANK! BANKS IN-BANK BANK-OF .BANKS +BANK -BANK BANKS-CLEAR SET-BANK BANK-MAPPING-ON BANK-MAPPING-OFF`.
- **Future-proofing constraints (PD-P4-10):** Phase-4 design must not paint Phase-5+ corners — multitasking (bank = 1 byte of TCB), locals (all three styles), and ALLOCATE (per-bank heap (β)) all confirmed compatible.

### FR Coverage Map

| FR | Epic | Notes |
|---|---|---|
| FR-P4-1 (`BANK@`) | Epic 17 | Current logical bank index getter |
| FR-P4-2 (`BANK!`) | Epic 17 | Logical bank switcher; swaps `(here, latest, wordlist-heads)` triple |
| FR-P4-3 (`BANKS`) | Epic 17 | Active bank count |
| FR-P4-4 (`IN-BANK`) | Epic 18 | Kernel-blessed scoped exec; CATCH-safe |
| FR-P4-5 (`BANK-OF`) | Epic 18 | xt → bank lookup (one-byte read from descriptor stub) |
| FR-P4-6 (`.BANKS`) | Epic 22 | Final formatting; minimal/working version lands in Epic 17 |
| FR-P4-7 (`+BANK`) | Epic 17 | Add physical page + probe-on-add |
| FR-P4-8 (`-BANK`) | Epic 17 | Remove physical page |
| FR-P4-9 (`BANKS-CLEAR`) | Epic 17 | Empty active list |
| FR-P4-10 (`SET-BANK`) | Epic 17 | Diagnostic raw MMU port write |
| FR-P4-11 (`BANK-MAPPING-ON`) | Epic 17 | Enable MMU mapping; auto-on in COLD |
| FR-P4-12 (`BANK-MAPPING-OFF`) | Epic 17 | Disable MMU mapping |
| FR-P4-13 (descriptor stub) | Epic 18 | Per-word stub allocator (PD-P4-1) |
| FR-P4-14 (compiler emits stub) | Epic 18 → 19 | First wired in Epic 18; full `COMPILE,` integration in Epic 19 |
| FR-P4-15 (intra-bank ≤ 1 `JP` overhead) | Epic 18 | Same-bank dispatch budget |
| FR-P4-16 (cross-bank ≤ 60 T-states + MMU) | Epic 18 | Cross-bank dispatch budget |
| FR-P4-17 (xt portability across `BANK!`) | Epic 18 | xts stable across bank switches |
| FR-P4-18 (sentinel-tagged cross-bank return) | Epic 18 | 3-cell return frame `(sentinel_addr, caller_bank, target_addr)` |
| FR-P4-19 (intra-bank zero-overhead path) | Epic 18 | 1-cell standard frame preserved |
| FR-P4-20 (`cross_bank_return` trampoline) | Epic 18 | Fixed-memory trampoline body (PD-P4-2) |
| FR-P4-21 (recursive cross-bank R-stack) | Epic 18 | Standard `-5 RETURN-STACK-OVERFLOW`; disposition resolved in Epic 16 spike (§9.6) |
| FR-P4-22 (per-bank dict state) | Epic 17 → 19 | `bank-table[]` allocated + `BANK!` swap in Epic 17; full `HERE`/`LATEST`/compiler plumbing in Epic 19 |
| FR-P4-23 (per-bank `,` and `COMPILE,`) | Epic 19 | Cell writes go into current bank's `here` |
| FR-P4-24 (`:` lands body in current bank) | Epic 19 | Colon allocates body in bank + stub in fixed memory |
| FR-P4-25 (`CREATE` / `DOES>` cross-bank explicit) | Epic 19 | Doer-stub + data-cell PFA layout |
| FR-P4-26 (`HERE` / `LATEST` per bank) | Epic 19 | Per-bank getters |
| FR-P4-27 (per-wordlist `bank` field) | Epic 20 | Wordlist header extension; system wordlists tagged `bank=fixed` |
| FR-P4-28 (FIND traversal) | Epic 20 | Save / switch / walk / restore per wordlist |
| FR-P4-29 (`WORDS` traverses banks) | Epic 20 | Multi-bank `WORDS` |
| FR-P4-30 (error messages name source bank) | Epic 20 | `<word> ?` with bank context |
| FR-P4-31 (saved current-bank cell) | Epic 21 | Outermost interactive `BANK!` updates kernel cell |
| FR-P4-32 (`QUIT` re-asserts saved bank) | Epic 21 | QUIT bank-restore (PD-P4-5) |
| FR-P4-33 (`ABORT` bank-state) | Epic 21 | `ABORT` / `ABORT"` unwind into `QUIT` |
| FR-P4-34 (CL parser syntax) | Epic 17 | `antforth <portal-page> <bank-list>` |
| FR-P4-35 (CL parser defaults) | Epic 17 | `22 35-3F` default; CL edge-case policy resolved Epic 16 spike (§9.3) |
| FR-P4-36 (CL parser probe-on-add) | Epic 17 | One-line warning per failed page; parsing does not abort |
| FR-P4-37 (banner shows bank count) | Epic 17 | `antforth 3.x — N banks available — ok` |
| FR-P4-38 (`STARTUP.FTH` not the configuration mechanism) | Epic 17 | Architectural rejection captured (PD-P4-8) |
| FR-P4-39 (default bank capacity) | Epic 17 | 12 banks × 16 KB = 192 KB; max 29 × 16 KB = 464 KB |
| FR-P4-40 (Phase-1+2+3 functional preserved) | Phase-wide (all epics) | Per-epic regression discipline; baseline release blocker |
| FR-P4-41 (Phase-3 974-PASS test baseline holds) | Phase-wide (all epics) | NFR-P4-10 release-blocker; verified across Epics 17–22 |
| FR-P4-42 (CODE-word source backward compat) | Phase-wide + Epic 22 | Cross-bank CODE-word policy resolved by Epic 16 spike (§9.1); enforcement in Epic 22 |
| FR-P4-43 (`BANK*` wordset is additive) | Phase-wide (all epics) | No pre-Phase-4 word changes name, stack effect, or semantics |

## Epic List

The 7-epic Phase-4 outline is locked by `docs/antforth-banking-redesign.md` §8 and architecture §"Decision Impact Analysis — Implementation sequence". Epics 16–22 ship sequentially as antforth 3.x point-releases (NFR-P4-21), with Epic 16 as the load-bearing prework gate (Epic 17+ story-writing blocks on Epic 16.3 emulator-vendor pick + the six §9.1–§9.6 spike resolutions).

### Epic 16: Phase-4 prework — memory map, emulator pick, design lock

**Goal:** Resolve every sequencing prerequisite for Phase-4 feature work so Epic 17+ stories can be authored with binding inputs. Pick the banking-capable emulator vendor (load-bearing per PD-P4-9 / NFR-P4-19), verify CCP eviction is safe on real hardware (PD-P4-6 + arch finding F3), supersede `docs/antforth-banking-design.md` (broken `BIT 7,H` heuristic + obsolete `THUNK-TO-USER-BANKn` family), lock `docs/antforth-banking-redesign.md` as the Phase-4 design source, and resolve the six redesign-doc open questions (§9.1 cross-bank CODE-words, §9.3 CL parser edge-case policy, §9.4 `+BANK` past-cap policy, §9.5 stub-size pin, §9.6 cross-bank R-stack overflow disposition) so downstream FRs have binding inputs. Outcome: spike artifacts + emulator integration target + CCP-eviction verification transcript. **Zero binary delta** (planning + verification only); S9 hardware smoke is exempted with explicit rationale per NFR-P4-11.

**FRs covered:** prerequisite-resolution for FR-P4-13..17 (§9.5 stub size), FR-P4-21 (§9.6 R-stack policy), FR-P4-34..36 (§9.3/§9.4 CL parser + cap policies), FR-P4-42 (§9.1 cross-bank CODE-words). No FRs delivered as user-visible behaviour.

**Standalone:** ✅ Epic 16 ships planning + design-lock artifacts that are valuable on their own (downstream-Phase architects can re-litigate these decisions with the records in hand). It does not require Epic 17+ to function.

---

### Epic 17: Bank primitives + CL configuration

**Goal:** Ship the banking foundation. The 9 runtime/MMU-layer `BANK*` words land in first usable form (`BANK@`, `BANK!`, `BANKS`, `+BANK`, `-BANK`, `BANKS-CLEAR`, `SET-BANK`, `BANK-MAPPING-ON`, `BANK-MAPPING-OFF`), plus a working-but-pre-polish `.BANKS`. The `bank-table[]` allocator and the `BANK!` swap routine land in `src/banking.asm`. The CL-tail parser lands in `src/antforth.asm`; defaults `22 35-3F` apply absent CL args; each page in `<bank-list>` is probed before being added; the boot banner reports the active-bank count. After Epic 17 ships, the user types `5 BANK!` at the REPL and the active bank index changes; `+BANK` rejects ROM/unmapped pages with `ABORT" probe?"`; the boot banner reads `antforth 3.x — 12 banks available — ok`.

**FRs covered:** FR-P4-1, FR-P4-2, FR-P4-3, FR-P4-7, FR-P4-8, FR-P4-9, FR-P4-10, FR-P4-11, FR-P4-12, FR-P4-22 (table + swap; full plumbing in Epic 19), FR-P4-34, FR-P4-35, FR-P4-36, FR-P4-37, FR-P4-38, FR-P4-39. Initial form of FR-P4-6 (`.BANKS`); final polish in Epic 22.

**Standalone:** ✅ After Epic 17, banking-control surface is observable + testable end-to-end at the REPL. Cross-bank dispatch (Epic 18+) is not needed for Epic 17's value (the user can already exercise BANK!, BANKS, +BANK, -BANK and observe the table change).

**Depends on:** Epic 16 (banking-capable emulator vendor pick + CCP-eviction verification + §9.3/§9.4 CL parser policies).

---

### Epic 18: Stub mechanism (γ) + cross-bank EXIT (S1 b) + `IN-BANK` + `BANK-OF`

**Goal:** Land the load-bearing cross-bank dispatch infrastructure. Per-word descriptor stubs allocated in fixed memory at definition time (PD-P4-1); the sentinel-trampoline cross-bank EXIT (PD-P4-2) with the `cross_bank_return` trampoline at a fixed address; kernel `EXECUTE` dispatches through the stub; kernel-blessed `IN-BANK` (CATCH-safe via `>R` / `R>`); `BANK-OF` reads stub byte 0 (free under (γ)). After Epic 18 ships, a hand-allocated banked code body can be `EXECUTE`d via its stub address as xt and `EXIT` correctly back to a fixed-memory caller; the intra-bank zero-overhead 1-cell return path is preserved exactly; `IN-BANK` switches/restores around an arbitrary xt with CATCH-safety.

**FRs covered:** FR-P4-4, FR-P4-5, FR-P4-13, FR-P4-14 (initial wiring; full integration Epic 19), FR-P4-15, FR-P4-16, FR-P4-17, FR-P4-18, FR-P4-19, FR-P4-20, FR-P4-21.

**Standalone:** ✅ After Epic 18, the cross-bank dispatch surface is observable + testable using hand-allocated stubs and hand-built banked bodies (no need for the bank-aware `:` from Epic 19). `IN-BANK` is usable end-to-end.

**Depends on:** Epic 17 (`BANK@` / `BANK!` to set up test banks).

---

### Epic 19: Bank-aware compiler (`:` / `,` / `COMPILE,` / `CREATE` / `DOES>`)

**Goal:** Make `:` indistinguishable from flat `:` (the north-star UX). Plumb the per-bank `(here, latest, wordlist-heads)` triple through the full compiler chain — `,` and `COMPILE,` write into the current bank's `here`; `:` allocates the word body in the current bank + the descriptor stub in fixed memory + links into the current bank's `latest`; `CREATE` / `DOES>` allocate the doer-stub in fixed memory + the data cell in the current bank's data space; `HERE` / `LATEST` return per-bank values. After Epic 19 ships, the user types `5 BANK! : MYWORD ... ;` and the colon defines into bank 5 transparently; subsequent `MYWORD` calls dispatch via stub.

**FRs covered:** FR-P4-14 (full integration), FR-P4-22 (full plumbing), FR-P4-23, FR-P4-24, FR-P4-25, FR-P4-26.

**Standalone:** ✅ After Epic 19, end-to-end define-into-bank then call-from-anywhere works. FIND from a different bank's wordlist (Epic 20) is not needed for Epic 19's value (defining and calling within a single bank is observable).

**Depends on:** Epic 18 (descriptor-stub allocator must exist for `:` to allocate stubs; sentinel-trampoline EXIT must work for cross-bank `:` calls to return correctly).

---

### Epic 19.5: Cross-bank dispatch stabilization (DTC threading rework) — interlude

**Goal:** Make the north-star UX *actually* compiler-transparent. Epic 19 shipped the bank-aware compiler mechanism (`:` / `CREATE` / `COMPILE,` land bodies + stubs correctly, verified on emulator + bank-0/hardware), but compiled-body dispatch of a banked word is blocked by a root defect: the inner-interpreter `NEXT` (`src/macros.asm` `NEXTHL`) does a blind `JP (HL)` to each fetched thread cell, and a banked word's cell is a descriptor-stub xt whose byte 0 = `target_bank` decodes as a Z80 opcode — bypassing the MMU swap + sentinel trampoline that `w_EXECUTE_cf`'s 3-way dispatch performs correctly. This interlude epic teaches `NEXT` about stubs. It **leads with an Architecture-Decision-Record (ADR) spike** — no kernel edit until two decisions are locked: (1) root-cause + fix for the sentinel-trampoline layout-fragility (a +17–33 B kernel shift currently hangs the EXIT chain under iz-cpm-banking — the prerequisite that blocked landing/verifying every prior attempt, per [[iz-cpm-trampoline-fragility]]); (2) the DTC-dispatch architecture (A inline-`NEXTHL`-discriminator / B shared-dispatcher-subroutine / C self-dispatching-stub), chosen on envelope + T-state evidence against NFR-P4-1/3, including whether C's reopening of Epic-18's locked 4-byte stub contract is warranted. Implementation stories are authored FROM the locked ADR.

**FRs covered:** none new — completes the *behavioural* delivery of FR-P4-15 / FR-P4-16 / FR-P4-24 / FR-P4-25 (compiled-body intra-/cross-bank dispatch) that Epic 18/19 wired structurally but left blocked. Discharges the Epic-19 architectural debt (19.2 AC4/AC5, 19.3 AC3/DOES>, banked NFR-P4-8).

**Standalone:** ✅ After Epic 19.5, `5 BANK! : MYWORD ... ;` then calling `MYWORD` from a compiled definition in any bank dispatches correctly (the Epic-19 north-star UX, which today requires a manual `ALLOT` workaround and only works via explicit `EXECUTE`). The HW intra-bank-into-slot-2 gap (Probe-19.2-F) and the bank-N HERE COLD-init collision (H5) are closed here too.

**Depends on:** Epic 19 (the bank-aware compiler mechanism whose compiled-body dispatch this epic unblocks). Framed as an explicit stabilization interlude per the Epic-11.5 / Epic-13.5 precedent — debt-cleanup is not smuggled into a feature epic.

---

### Epic 20: Bank-aware FIND + `WORDS` + interpreter-loop attribution

**Goal:** Make `FIND` / `WORDS` traverse banks invisibly. Wordlist header extends with a `bank` field; system wordlists (FORTH, ASSEMBLER) are tagged `bank=fixed` (-1) at kernel build time so the everyday lookup case incurs no MMU switch (the (b) decision in PD-P4-4); `FIND` saves the current bank, switches only if the wordlist is non-fixed, walks the chain, restores on the way out; `WORDS` traverses banks per the search-order's wordlists; lookup-failure error messages name the source bank where appropriate. After Epic 20 ships, the user can define a word in bank 5, switch to bank 7, and `FIND` resolves the bank-5 word transparently if the bank-5 wordlist is in the search order; failed lookups report bank context.

**FRs covered:** FR-P4-27, FR-P4-28, FR-P4-29, FR-P4-30.

**Standalone:** ✅ After Epic 20, the cross-bank lookup surface is observable + testable. `MARKER` / `FORGET` per-bank (Epic 21) is not needed for Epic 20's value.

**Depends on:** Epic 17 (banks + bank-table[]); Epic 18 (cross-bank dispatch, so a found word in another bank can actually be executed). Can run in parallel with Epic 19 once Epic 18 is in.

---

### Epic 21: `MARKER` / `FORGET` per-bank + `ABORT` / `QUIT` bank-state restore (S5)

**Goal:** Land the bank-aware lifecycle plumbing. `MARKER` and `FORGET` track per-bank dictionary tail correctly (each bank's `(here, latest, wordlist-heads)` triple snapshotted/restored); the kernel-internal "saved current bank" cell is updated by every interactive `BANK!` from the outermost interpret loop; `QUIT` re-asserts the saved current bank on re-entry; `ABORT` / `ABORT"` unwind through the trampoline cleanly and re-enter `QUIT`. After Epic 21 ships, the user can define a marker in bank 5, define throwaway words across multiple banks, and `FORGET <marker>` correctly restores all per-bank tails; an `ABORT` mid-execution inside bank 7 returns the user to the bank they had typed at the REPL (not bank 7).

**FRs covered:** FR-P4-31, FR-P4-32, FR-P4-33.

**Standalone:** ✅ After Epic 21, the bank-state-correctness-on-error surface is observable + testable. Polish (Epic 22) is not required for Epic 21's safety guarantee.

**Depends on:** Epic 17 (bank-table[]); Epic 18 (sentinel-trampoline must be in place — uncaught THROW unwind across banks is a recursive sentinel-trampoline walk per arch validation §"Coherence"); Epic 19 (per-bank dictionary state must be plumbed for `MARKER`/`FORGET` to track per-bank tails correctly).

---

### Epic 22: Polish + Phase-4 close-out

**Goal:** Ship the close-out polish: `.BANKS` final formatting (status table per FR-P4-6's spec); REPL prompt indicator (current-bank visibility per redesign §"polish"); the cross-bank CODE-words decision implemented per Epic 16's §9.1 resolution; the three-test-surface harness sweep (iz-cpm + banking-capable emulator + real MicroBeast); Phase-3 974-test baseline + new Phase-4 banking probes verified clean across all surfaces. Tag the antforth 3.x close-out release; verdict-table walk per Story-13.5.6 precedent; banner / README / memory `description` fields all aligned to the close-out tag (S11 / NFR-P4-38); `make check-doc-sync` clean-pass (B.5).

**FRs covered:** FR-P4-6 (final), FR-P4-42 (CODE-word source compat — cross-bank CODE-word disposition implemented). Phase-wide constraints FR-P4-40, FR-P4-41, FR-P4-43 verified.

**Standalone:** ✅ Epic 22 closes Phase 4 — the Phase-4 close-out tag is the antforth 3.x version after Epic 22 ships.

**Depends on:** Epics 17–21 all in (the test-harness sweep validates the integrated surface).

---

### Epic-level dependency summary

```
Epic 16 (prework, gates Epic 17+ via emulator pick + spike resolutions)
  └─ Epic 17 (bank primitives + CL config; first observable banking surface)
       └─ Epic 18 (cross-bank dispatch + EXIT + IN-BANK + BANK-OF)
            ├─ Epic 19 (bank-aware compiler — depends on Epic 18 stub allocator)
            │    ├─ Epic 19.5 (DTC dispatch stabilization interlude — ADR-first; unblocks compiled-body banked dispatch)
            │    └─ Epic 21 (MARKER/FORGET + ABORT/QUIT bank-state restore)
            ├─ Epic 20 (bank-aware FIND — parallelable with Epic 19)
            └─ Epic 21 (also depends on Epic 18 trampoline)
                 └─ Epic 22 (polish + close-out — depends on Epics 17–21)
```

Phase-wide constraints FR-P4-40 / FR-P4-41 / FR-P4-43 + NFR-P4-10 (974-PASS regression) + NFR-P4-11 (S9 per-story hardware smoke) + S11 / NFR-P4-38 (per-tag version surface audit) are enforced at every epic close-out, not bundled into a single epic.

---

## Epic 16: Phase-4 prework — memory map, emulator pick, design lock

**Goal:** Resolve every sequencing prerequisite for Phase-4 feature work so Epic 17+ stories can be authored with binding inputs. Zero binary delta (planning + verification only); S9 hardware-smoke is exempted per story with explicit rationale per NFR-P4-11.

**User outcomes at epic close-out:**
- Ant (project lead) has a verified CCP-eviction hardware transcript (F3 closed) so PD-P4-6's +2 KB Page-3 headroom is safe to consume in Epic 17+.
- A banking-capable emulator vendor is picked, integrated into the test harness, and its `make test-repl-banking` target exists. iz-cpm continues carrying the non-banking 974-PASS baseline (F1 closed).
- The obsolete `docs/antforth-banking-design.md` is banner-marked SUPERSEDED so future readers (dev-agents, downstream-Phase architects) cannot accidentally consume the broken `BIT 7,H` heuristic / `THUNK-TO-USER-BANKn` family from the 2026-05-07 sketch.
- The five remaining redesign-doc open questions (§9.1, §9.3, §9.4, §9.5, §9.6) have binding resolutions captured in `architecture.md` so downstream-epic story-writing has no `TODO(P4-arch)` blockers (F5 closed).

**FRs covered:** prerequisite-resolution for FR-P4-13..17 (§9.5 stub size pin), FR-P4-21 (§9.6 R-stack overflow disposition), FR-P4-34..36 (§9.3/§9.4 CL parser + cap policies), FR-P4-42 (§9.1 cross-bank CODE-words). No FRs delivered as user-visible behaviour.

**NFRs codified:** NFR-P4-19 (test-first discipline — banking-capable emulator integration); NFR-P4-26 (ISR-from-fixed-memory-only invariant — verified against MicroBeast BIOS IM 2 vector table). All 39 NFR-P4-N continue to hold.

**Architecture findings closed at epic close-out:** F1 (emulator vendor pick), F3 (CCP eviction verification), F5 (six open questions → five remaining after §9.2 closes via 16.3). F2 (stub-cost growth) and F4 (cross-bank pointer hazard) deferred to Epic 22 polish and ongoing CCD-4 metrics.

### Story 16.1: CCP eviction hardware-verification spike + memory-map page-allocation survey

As Ant (project lead investigating PD-P4-6 safety),
I want a hardware-verified transcript confirming CCP eviction at `$D400–$DBFF` is reloadable by CP/M 2.2 BIOS on warm-boot,
So that Epic 17+ can consume the +2 KB Page-3 headroom for the descriptor-stub allocator without risking a stranded warm-boot state on real MicroBeast.

**Acceptance Criteria:**

**Given** the v2.0 baseline `src/antforth.asm` memory-map declaration includes CCP at `$D400–$DBFF` as occupied,
**When** Story 16.1 is dev-passed,
**Then** AC1 — a one-shot kernel patch (not committed) zeroes the CCP region at startup, runs antforth, then exits via `^C`; a real-MicroBeast transcript captures the warm-boot path; the transcript shows the CCP prompt returns clean (BIOS reloads CCP from disk on `^C` per CP/M 2.2 BIOS warm-boot semantics).
**And** AC2 — if AC1's transcript shows a stranded state (CCP not reloaded, system unresponsive, or corrupted dictionary), a follow-up restore-on-warm-boot story is spawned with a +50 B envelope per F3 mitigation; otherwise F3 is closed and the action item dropped.
**And** AC3 — the AC1 transcript is committed to `docs/dev_journal.md` (or a dedicated `_bmad-output/implementation-artifacts/16.1-ccp-eviction-hardware-transcript.md` artifact) with date, hardware revision, transcript verbatim, and verdict (PASS/FAIL-with-spawn).
**And** AC4 — `architecture.md` Findings F3 row is updated from "Issue" / "Mitigation" / "Action" to "**Closed by Story 16.1, <date>, verdict PASS**" (or "FAIL-spawning-16.1.1" if the spike fails).
**And** AC5 — the Phase-4 memory-map declaration draft (the `src/antforth.asm` line that will move kernel-end up by 2 KB) is captured in Dev Notes as a future-edit reference; the edit itself ships in Epic 17 Story 17.1 (or wherever the kernel-end moves first).
**And** AC6 — a Page 0–3 page-allocation survey table is appended to `architecture.md` (or a dedicated `docs/phase4-memory-map.md`): each MMU page from `0x00..0x3F` named with its assignment (BIOS/BDOS/CCP/Zero-page/Application/Virtual-console/RAM-disk/Banks-available), citing the source-of-truth for each assignment (BIOS source / CP/M 2.2 docs / MicroBeast schematic).
**And** AC7 — `wc -c build/antforth.com` unchanged from Phase-3 close-out baseline (24,995 bytes); story dev-pass produces zero binary delta; S9 hardware-smoke is exempt with explicit rationale ("zero binary delta — the hardware transcript IS the verification").
**And** AC8 — `make test-repl` reports ≥ 974 PASS / 0 FAIL on iz-cpm; zero regressions on the Phase-3 close-out baseline.

**FRs covered:** prerequisite-resolution for PD-P4-6 (CCP eviction). **Findings closed:** F3.

### Story 16.2: Doc-lock — supersede obsolete `docs/antforth-banking-design.md`

As any reader (dev-agent, downstream-Phase architect, future-Ant) encountering the banking-design doc tree,
I want the obsolete 2026-05-07 sketch banner-marked SUPERSEDED and pointing unambiguously at `docs/antforth-banking-redesign.md`,
So that the broken `BIT 7,H` heuristic and the obsolete `THUNK-TO-USER-BANKn` family cannot be accidentally consumed as the Phase-4 design source.

**Acceptance Criteria:**

**Given** `docs/antforth-banking-design.md` exists with the obsolete 2026-05-07 sketch and no SUPERSEDED banner,
**When** Story 16.2 is dev-passed,
**Then** AC1 — a `> **SUPERSEDED 2026-05-09.**` banner block is inserted at the very top of `docs/antforth-banking-design.md`, before any other content; the banner names `docs/antforth-banking-redesign.md` as the canonical Phase-4 design source.
**And** AC2 — the banner enumerates the two specific elements of the obsolete sketch that were rejected: (a) the `BIT 7,H` cross-bank-EXIT heuristic (broken because user code at $8000–$BFFF always sets bit 7) and (b) the user-typed `THUNK-TO-USER-BANKn` family (replaced by compiler-emitted descriptor stubs (γ) per redesign §2.1).
**And** AC3 — `docs/antforth-banking-design.md` is preserved otherwise unmodified; the file is retained for design-evolution traceability, not deleted.
**And** AC4 — any cross-document references to `docs/antforth-banking-design.md` in `architecture.md`, `prd.md`, or `architecture-phase3-epics-14-15.md` are audited; references that should now point at `docs/antforth-banking-redesign.md` are updated; references that legitimately point at the historical sketch (e.g., "the obsolete BIT 7,H sketch") are left alone but verified.
**And** AC5 (verdict-criterion grep-able) — `grep -l 'BIT 7,H' docs/*.md` returns at most one file (`docs/antforth-banking-design.md` itself, in the banner or the original sketch body); `grep -l 'THUNK-TO-USER-BANK' docs/*.md` likewise.
**And** AC6 — `wc -c build/antforth.com` unchanged; zero binary delta; S9 hardware-smoke is exempt (documentation-only).
**And** AC7 — `make test-repl` reports ≥ 974 PASS / 0 FAIL; zero regressions.
**And** AC8 — `make check-doc-sync` (B.5) reports clean-pass after the banner addition (no new PRD-vs-architecture drift introduced).

**FRs covered:** none directly (documentation hygiene). **NFR codified:** NFR-P4-20 (single-source-of-truth for design references — `docs/antforth-banking-redesign.md` is the locked Phase-4 source).

### Story 16.3: Banking-capable emulator vendor selection + `make test-repl-banking` integration

As Ant (project lead authoring Epic 17+ story test-plans),
I want a banking-capable emulator picked, integrated into the test harness with a `make test-repl-banking` target, and entered in `.tool-versions`,
So that every Phase-4 binary-delta story can specify which test surface its probes target (iz-cpm / banking-capable emulator / hardware) per the three-test-surface discipline.

**Acceptance Criteria:**

**Given** iz-cpm is the only emulator currently integrated and does not support banking,
**When** Story 16.3 is dev-passed,
**Then** AC1 — vendor research is captured in a research artifact (e.g., `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md`): each candidate emulator evaluated against the three pinned criteria — (a) models the 32-page MMU at ports `0x70+slot / 0x74` matching MicroBeast hardware; (b) pipe-able for `make test-repl`-style automation; (c) bank-visibility for tests (test scripts can assert which logical/physical bank is currently active).
**And** AC2 — a single vendor is picked; the pick is justified against the three criteria; explicit pass/fail per criterion is recorded; non-picked candidates have a one-line "rejected because <reason>" entry. **Fallback path:** if zero candidates satisfy all three criteria, the story does NOT force a pick — instead, escalate via `/bmad-bmm-correct-course` for sprint-change-proposal evaluation (re-scope of the criteria, re-pin of the Phase-4 prework gate, or interim single-criterion pick with documented gaps).
**And** AC3 — `Makefile` gains a `make test-repl-banking` target (or equivalent — exact name decided in the story; if integration favours an `EMULATOR=` variable selector on the existing `make test-repl` target, that is acceptable and is captured in the story Dev Notes).
**And** AC4 — `.tool-versions` gains an entry for the picked emulator vendor (version pinned to a specific release/commit) per the Phase-3 tool-version discipline.
**And** AC5 — `tests/README.md` is extended with a "Three test surfaces" section naming iz-cpm, the picked banking-capable emulator, and real MicroBeast; per-probe annotation convention is documented (e.g., a comment block on each probe stating its target surface).
**And** AC6 — a first iron probe is authored: a minimal `tests/banking_tests.fth` skeleton (or a one-off probe file under `_bmad-output/implementation-artifacts/16.3-probe.fth`) confirms the banking-capable emulator can run a Forth script and assert MMU-port state via `SET-BANK`; the probe PASSes under the picked emulator and FAILs / SKIPs under iz-cpm with a clear surface-annotation reason.
**And** AC7 — `architecture.md` Findings F1 row is updated from "Issue" / "Mitigation" / "Action" to "**Closed by Story 16.3, <date>, vendor = <name>**"; redesign-doc §9.2 is marked CLOSED in architecture's "open questions" tracking.
**And** AC8 — `wc -c build/antforth.com` unchanged (kernel itself unchanged); zero binary delta; S9 hardware-smoke is exempt with rationale ("emulator integration is dev-tooling, not kernel — no hardware behaviour change").
**And** AC9 — `make test-repl` reports ≥ 974 PASS / 0 FAIL on iz-cpm (regression baseline preserved); the new `make test-repl-banking` target reports PASS on the first iron probe under the picked emulator.

**FRs covered:** none directly (test-tooling). **NFR codified:** NFR-P4-19 (test-first discipline — banking dual-track). **Findings closed:** F1. **Open questions closed:** redesign-doc §9.2.

### Story 16.4: Architecture-stage open-questions resolution (§9.1 / §9.3 / §9.4 / §9.5 / §9.6)

As any dev-agent or story-author working on Epic 17+,
I want the five remaining redesign-doc open questions (§9.1, §9.3, §9.4, §9.5, §9.6) resolved with binding decisions captured in `architecture.md`,
So that downstream-epic stories have no `TODO(P4-arch)` blockers and FR ACs can be written against concrete specifications.

**Acceptance Criteria:**

**Given** `architecture.md` carries `TODO(P4-arch)` markers for the five remaining redesign-doc open questions (§9.1 cross-bank CODE-words, §9.3 CL parser edge-case policy, §9.4 `+BANK` past-cap policy, §9.5 stub-size pin, §9.6 cross-bank R-stack overflow disposition),
**When** Story 16.4 is dev-passed,
**Then** AC1 (§9.5 stub-size pin) — `architecture.md` records the final stub-size decision (3 bytes vs 4 bytes vs 5 bytes) with explicit rationale citing the per-1000-words cost calculation against NFR-P4-5; the chosen size is referenced by future Epic 18 stories without further negotiation.
**And** AC2 (§9.6 cross-bank R-stack overflow) — `architecture.md` records the disposition (default: documented-gotcha, no runtime guard) with explicit rationale; FR-P4-21's `TODO(P4-resolve)` marker is removed and replaced with a `(per redesign §9.6 closure 2026-MM-DD: documented-gotcha)` reference; the documented-gotcha is added to the F4-related user-docs entry slated for Epic 22 polish.
**And** AC3 (§9.4 `+BANK` past-cap) — `architecture.md` records the policy when `+BANK` is called with `BANKS` already at the 29-entry `bank-table[]` cap: chosen disposition is captured (ABORT" cap?" raised, or silent no-op, or growable table) with rationale; Story 17.5 (or whichever Epic-17 story implements `+BANK`) inherits this as a binding AC input.
**And** AC4 (§9.3 CL parser edge-cases) — `architecture.md` records the policy for each named edge case from the redesign-doc session: no args (apply defaults), bad token (per-token warning, continue parsing), reverse range (warning, treat as empty range), dup (warning, deduplicate silently), probe-fail (one-line warning per failed page, exclude from active list, continue), empty surviving list after probes (warning + boot continues with `BANKS = 0`); Epic 17's CL-parser story inherits these as binding AC inputs.
**And** AC5 (§9.1 cross-bank CODE-words) — `architecture.md` records whether user-defined CODE (assembler) words can live in banks, with rationale and S7 dispatch implications captured; Epic 22's polish story for §9.1 inherits this as a binding AC input. (Acceptable outcomes: "yes, banks can host CODE words with the following dispatch rule" / "no, CODE words must live in fixed memory with rationale" / "deferred to Phase 5+ with explicit fallback in Phase 4".)
**And** AC6 — `architecture.md` "open questions" / `TODO(P4-arch)` tracking section is updated: all five resolved questions move from "open" to "closed, <story-ref>, <date>"; the Findings F5 row is updated from "Issue" / "Mitigation" / "Action" to "**Closed by Story 16.4, <date>, 5 of 5 remaining open questions resolved**".
**And** AC7 — `docs/antforth-banking-redesign.md` §9 is updated in-place: each of §9.1, §9.3, §9.4, §9.5, §9.6 receives a closure line pointing at `architecture.md` for the binding decision (one-line cross-reference, not a full redecision).
**And** AC8 — `wc -c build/antforth.com` unchanged; zero binary delta; S9 hardware-smoke is exempt (documentation-only).
**And** AC9 — `make test-repl` reports ≥ 974 PASS / 0 FAIL; `make check-doc-sync` reports clean-pass.

**FRs covered:** prerequisite-resolution for FR-P4-13..17, FR-P4-21, FR-P4-34..36, FR-P4-42. **Findings closed:** F5. **Open questions closed:** redesign-doc §9.1, §9.3, §9.4, §9.5, §9.6.

---

**Epic 16 summary:** 4 stories. All zero-binary-delta planning / verification work. Epic 16 closes when Stories 16.1, 16.2, 16.3, 16.4 are dev-passed. After close-out, Findings F1, F3, F5 are closed; the six redesign-doc open questions (§9.1–§9.6) are all closed (§9.2 by 16.3, the rest by 16.4); CCP-eviction hardware verification is in hand; the banking-capable emulator is integrated; the obsolete design doc is SUPERSEDED. Epic 17+ story-writing is unblocked.

---

## Epic 17: Bank primitives + CL configuration

**Goal:** Ship the banking foundation as antforth 3.x.1. After Epic 17, the user types `5 BANK!` at the REPL and the active bank index changes; `+BANK` rejects ROM/unmapped pages with `ABORT" probe?"`; the boot banner reads `antforth 3.x.1 — 12 banks available — ok`. A hand-built cross-bank call validates the layer end-to-end on real MicroBeast before Epic 18's stub mechanism lands.

**User outcomes at epic close-out:**
- Marc (OG retrocomputing user) can type `5 BANK!` `BANK@ .` at the REPL on real MicroBeast and see `5 ok`; the banking surface is observable end-to-end at the REPL even before bank-aware `:` (Epic 19) ships.
- Marc can boot with `antforth 24 35-3f` and see the banner report the active-bank count; `+BANK` / `-BANK` mutate the active list at runtime with probe-on-add guarding against ROM/unmapped pages.
- The Phase-4 banking subsystem `src/banking.asm` exists; UserArea cells are wired; the CCP-eviction memory-map change is in place (verified safe by Story 16.1).
- antforth 3.x.1 is tagged with banner / README / memory-`description` aligned per S11 / NFR-P4-38.

**FRs covered:** FR-P4-1 (`BANK@`), FR-P4-2 (`BANK!`), FR-P4-3 (`BANKS`), FR-P4-7 (`+BANK`), FR-P4-8 (`-BANK`), FR-P4-9 (`BANKS-CLEAR`), FR-P4-10 (`SET-BANK`), FR-P4-11 (`BANK-MAPPING-ON`), FR-P4-12 (`BANK-MAPPING-OFF`), FR-P4-22 (initial bank-table[] + swap; full plumbing in Epic 19), FR-P4-34, FR-P4-35, FR-P4-36, FR-P4-37, FR-P4-38, FR-P4-39. Initial form of FR-P4-6 (`.BANKS`).

**NFRs codified:** NFR-P4-2 (bank-switch latency ≤ 60 T-states + MMU port-write); NFR-P4-5 (banking infrastructure fixed-memory budget — first Epic 17 contribution against ~400 B envelope per Decision Impact Analysis); NFR-P4-11 / NFR-P4-36 (S9 mid-epic hardware-smoke per binary-delta story); NFR-P4-14 (CCD-3 banking-word source flags); NFR-P4-21 (epic-level decoupling — Epic 17 ships antforth 3.x.1); NFR-P4-38 (S11 user-visible version surface audit at tag close-out); NFR-P4-39 (S12 hardware-typed probe authoring discipline for the hardware-smoke probes). All 39 NFR-P4-N continue to hold.

**Architectural inputs:** Story 16.1 (CCP eviction safe to consume); Story 16.3 (banking-capable emulator available); Story 16.4 §9.3 (CL parser edge-case policy) + §9.4 (`+BANK` past-cap policy).

### Story 17.1: `bank-table[]` allocator + UserArea cells + `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` + CCP-eviction memory-map edit

As Ant (developer wiring the Phase-4 banking foundation),
I want the `src/banking.asm` subsystem file created with the `bank-table[]` allocator in the CCP-evicted Page-3 region, the four UserArea cells (`saved-bank`, `current-bank`, `bank-table-base`, `bank-mapping-state`) wired, and the `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` words working with auto-`ON` in `COLD`,
So that subsequent Epic-17 stories have a working infrastructure to land `BANK@` / `BANK!` / `+BANK` against.

**Acceptance Criteria:**

**Given** Phase-3 close-out has no `src/banking.asm` and no banking UserArea cells,
**When** Story 17.1 is dev-passed,
**Then** AC1 — `src/banking.asm` is created as a new kernel-resident file following the existing per-subsystem-file convention; its header carries `; antforth Phase-4 banking subsystem — see docs/antforth-banking-redesign.md §<n>` per CCD-3 / NFR-P4-14.
**And** AC2 — `src/antforth.asm`'s memory-map declaration moves the kernel-end up by 2 KB, reclaiming `$D400–$DBFF` for the `bank-table[]` allocator and the descriptor-stub allocator (allocator allocations themselves land in Epic 18; Story 17.1 only reclaims the region and routes the `bank-table[]` base into it).
**And** AC3 — four UserArea cells land in `src/structures.asm`: `saved-bank`, `current-bank`, `bank-table-base`, `bank-mapping-state`. Cell positions are documented in source comments; cell semantics are documented inline per CCD-3.
**And** AC4 — the `bank-table[]` structure is declared in `src/banking.asm` with the 29-entry cap (per the redesign-doc §9.4 closure from Story 16.4); each entry reserves space for the per-bank `(here, latest, wordlist-heads)` triple (full plumbing in Epic 19; Story 17.1 only allocates the structure shell with zero-initialised entries).
**And** AC5 — `BANK-MAPPING-ON ( -- )` is implemented; writes the appropriate MMU enable bit; verified by REPL probe under the banking-capable emulator: `BANK-MAPPING-OFF BANK-MAPPING-ON` round-trips cleanly with no side-effects.
**And** AC6 — `BANK-MAPPING-OFF ( -- )` is implemented; writes the appropriate MMU disable bit; verified by REPL probe under both emulator surfaces: `BANK-MAPPING-OFF` leaves the system in a flat-memory CP/M context (warm-boot escape per FR-P4-12).
**And** AC7 — `COLD` is extended to auto-`BANK-MAPPING-ON` after the UserArea is initialised but before the boot banner is printed; verified by hardware-smoke (after boot, `BANK-MAPPING-OFF` is a no-op on an already-disabled state, but `BANK-MAPPING-ON` reaches the expected MMU-port-write trace).
**And** AC8 (CCD-3 source flags) — both `BANK-MAPPING-ON` and `BANK-MAPPING-OFF` carry `; antforth extension <word> — see docs/antforth-banking-redesign.md §5.1` source-comment blocks; `docs/ans-forth-core-compliance.md` gains two rows tagged `Implemented (antforth extension)` per CCD-P3-1.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~150 B for this story (subsystem file shell + UserArea cells + two control words + memory-map edit); the per-story envelope is captured in Dev Notes and tracked against the Epic 17 ~400 B budget per Decision Impact Analysis.
**And** AC10 (S9 hardware-smoke) — a hardware-typed probe batch (per NFR-P4-39 word-existence pre-flight + TIB-128 line-length lint) runs on real CP/M 2.2 / MicroBeast and PASSes: boot reaches the banner; `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` round-trip; no crash. Transcript saved per established `~/Downloads/bestialitty-<date>.bin` naming.
**And** AC11 — `make test-repl` reports ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports PASS on the round-trip probe under the banking-capable emulator.

**FRs covered:** FR-P4-11 (`BANK-MAPPING-ON`), FR-P4-12 (`BANK-MAPPING-OFF`), FR-P4-22 (initial `bank-table[]` structure). **NFR codified:** NFR-P4-14 (CCD-3 source flags). **Architectural input consumed:** Story 16.1 (CCP eviction verified safe).

### Story 17.2: `BANK@` / `BANK!` / `BANKS` — read + swap primitives

As Marc (OG user) running antforth on real MicroBeast,
I want to read the current logical bank index with `BANK@`, switch banks with `BANK!`, and query the active-bank count with `BANKS`,
So that I have observable end-to-end banking control at the REPL before bank-aware `:` (Epic 19) ships.

**Acceptance Criteria:**

**Given** Story 17.1 has shipped (`bank-table[]` infrastructure + UserArea cells exist),
**When** Story 17.2 is dev-passed,
**Then** AC1 — `BANK@ ( -- n )` is implemented in `src/banking.asm`; returns the index of the current logical bank (read from the `current-bank` UserArea cell, per FR-P4-1 — index into the active bank list, NOT the physical page number).
**And** AC2 — `BANK! ( n -- )` is implemented; preconditions: if `n` is not in the active bank list, raises `ABORT" bank?"` per FR-P4-2; on success, writes the corresponding physical page to the MMU port for slot 2, swaps the per-bank `(here, latest, wordlist-heads)` triple into the active-state cells (initial swap only; per-bank `,` / `COMPILE,` plumbing is Epic 19), and updates the `current-bank` UserArea cell.
**And** AC3 — `BANKS ( -- n )` is implemented as a `VALUE` (per FR-P4-3) returning the count of currently-available banks; reads the active bank-list length; updates via `+BANK` / `-BANK` / `BANKS-CLEAR` in Story 17.3.
**And** AC4 (CCD-3 source flags) — all three words carry `; antforth extension <word> — see docs/antforth-banking-redesign.md §<n>` per NFR-P4-14; three rows added to `docs/ans-forth-core-compliance.md`.
**And** AC5 (NFR-P4-2 latency) — a benchmark probe under the banking-capable emulator measures `BANK!` completing in ≤ 60 Z80 T-states + the MMU port-write time; result captured in Dev Notes against the envelope.
**And** AC6 (REPL probes — per S2 / NFR-P4-29) — `tests/banking_tests.fth` (NEW) gains a probe block: `BANK@ .` returns `0 ok` at boot; `1 BANK! BANK@ .` returns `1 ok`; `0 BANK!` round-trips; `BANKS .` returns the configured-banks count (initially 12 with defaults); `99 BANK!` raises `ABORT" bank?"` and the REPL recovers to the prompt with state intact.
**And** AC7 (probe surfaces) — probes from AC6 are annotated per Story 16.3's three-test-surface convention; PASS verdicts on iz-cpm (no-op surface since banking emu not present → SKIP-on-iz-cpm with rationale) and banking-capable emulator; one hardware-typed probe runs on real MicroBeast per S9.
**And** AC8 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story; tracked against the Epic 17 ~400 B budget.
**And** AC9 — `make test-repl` reports ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS under the banking-capable emulator.

**FRs covered:** FR-P4-1, FR-P4-2, FR-P4-3. **NFRs codified:** NFR-P4-2 (bank-switch latency).

### Story 17.3: `+BANK` (with probe-on-add) + `-BANK` + `BANKS-CLEAR` + `SET-BANK`

As Marc (OG user) configuring banks at runtime,
I want `+BANK` to safely add a physical page (probing first, ABORT-ing on ROM/unmapped/unstable), `-BANK` to remove a page from the active list, `BANKS-CLEAR` to empty the active list, and `SET-BANK` as a diagnostic raw MMU port write,
So that I can adjust the bank configuration at runtime without booting fresh and have a diagnostic escape hatch for hardware investigation.

**Acceptance Criteria:**

**Given** Story 17.2 has shipped (`BANK@` / `BANK!` / `BANKS` exist),
**When** Story 17.3 is dev-passed,
**Then** AC1 — `+BANK ( page -- )` is implemented; probes the page by writing a sentinel byte (e.g., 0x5A), reading it back, restoring the original byte; if read-back fails (ROM, unmapped, unstable), raises `ABORT" probe?"` and does not modify the active list (per FR-P4-7); on success, appends `page` to the active list, increments `BANKS` by one.
**And** AC2 — `+BANK` past the 29-entry `bank-table[]` cap follows the Story 16.4 §9.4 closure policy (whatever the architecture decision was: ABORT" cap?" / silent no-op / growable table); the AC text inherits that decision verbatim.
**And** AC3 — `-BANK ( page -- )` is implemented (per FR-P4-8); removes the page from the active list, decrements `BANKS` by one; if page is not in the active list, is a silent no-op (no THROW); does not affect the underlying memory contents.
**And** AC4 — `BANKS-CLEAR ( -- )` is implemented (per FR-P4-9); empties the active bank list; after invocation, `BANKS` returns 0 and `BANK!` raises `ABORT" bank?"` for any argument until `+BANK` rebuilds the list.
**And** AC5 — `SET-BANK ( page slot -- )` is implemented (per FR-P4-10); performs a raw MMU port write of `page` into MMU `slot`; bypasses `bank-table[]`; does not validate (diagnostic intent); does NOT update `current-bank` or `BANKS`; documented in source as "diagnostics only — bad arguments produce undefined hardware behaviour".
**And** AC6 (CCD-3 source flags) — all four words carry `; antforth extension <word> — see docs/antforth-banking-redesign.md §<n>` per NFR-P4-14; four rows added to `docs/ans-forth-core-compliance.md`.
**And** AC7 (REPL probes) — `tests/banking_tests.fth` extends with: `+BANK` accepts a known-good page and `BANKS` increments; `+BANK` rejects a ROM page (e.g., 0x00) with `ABORT" probe?"` and `BANKS` is unchanged; `-BANK` of a present page decrements; `-BANK` of an absent page is a no-op; `BANKS-CLEAR` zeroes `BANKS`; `BANK!` after `BANKS-CLEAR` raises `ABORT" bank?"`; `SET-BANK` writes to the named MMU slot (verified via subsequent memory read that confirms the new page is mapped).
**And** AC8 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch runs on real MicroBeast confirming `+BANK` rejects a known-ROM page and accepts a known-good page; transcript saved per S9.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~120 B for this story (four words + probe loop); tracked against the Epic 17 ~400 B budget.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-7, FR-P4-8, FR-P4-9, FR-P4-10. **Architectural input consumed:** Story 16.4 §9.4 (`+BANK` past-cap policy).

### Story 17.4: CL-tail parser + boot configuration + banner update

As Marc (OG user) booting antforth from CP/M,
I want to pass `antforth <portal-page> <bank-list>` on the command line and have the boot banner report the active-bank count,
So that I can configure banks at boot time without editing source, and the banner tells me unambiguously how many banks the current invocation has available.

**Acceptance Criteria:**

**Given** Story 17.3 has shipped (`+BANK` / `-BANK` / `BANKS-CLEAR` exist with probe-on-add),
**When** Story 17.4 is dev-passed,
**Then** AC1 — `src/antforth.asm` gains a CL-tail parser invoked early in boot (after the kernel is initialised, before the banner is printed); parser accepts `antforth <portal-page> <bank-list>` (e.g., `antforth 24 35-3f`) per FR-P4-34; `<portal-page>` is a single hex byte naming MMU slot 2 page assignment; `<bank-list>` is a hex range (`35-3f`) or comma-separated list (`35,36,3a`).
**And** AC2 — absent a CL tail, defaults `22 35-3F` apply (portal page 0x22, banks 0x35..0x3F = 11 banks + portal = 12 total counting portal as bank 0) per FR-P4-35 / FR-P4-39.
**And** AC3 — each page in `<bank-list>` is probed before being added via the Story 17.3 probe loop; pages that fail probe produce a one-line warning to console (`probe? <page>` or equivalent — exact format captured per Story 16.4's §9.3 closure) and are excluded; parsing does NOT abort on a single bad page per FR-P4-36.
**And** AC4 — the boot banner is updated to include the active-bank count: `antforth 3.x.1 — N banks available — ok` (where N reflects the count of pages that passed probe) per FR-P4-37; the banner format change is recorded in `docs/dev_journal.md` for S11 / NFR-P4-38 traceability.
**And** AC5 — CL parser edge-case policy follows Story 16.4 §9.3 closure verbatim: no args (defaults apply), bad token (per-token warning + continue), reverse range (warning + treat as empty), dup (warning + silent dedup), probe-fail (per-page warning + exclude), empty surviving list (warning + boot continues with `BANKS = 0`).
**And** AC6 — FR-P4-38 is captured as an architectural rejection in the parser's source comment: `; STARTUP.FTH NOT the boot-config mechanism — bank availability needed at banner-print time, before any .FTH file could run (see docs/antforth-banking-redesign.md §6)`.
**And** AC7 (REPL probes — for the non-CL-driven part) — `tests/banking_tests.fth` extends with probes that boot the binary with various CL tails under the banking-capable emulator and assert the resulting `BANKS .` and banner string; at least 6 probe cases cover: no-args / defaults / single-page-range / multi-page-list / mixed-with-probe-failure / empty-surviving-list.
**And** AC8 (hardware smoke) — one hardware-typed probe batch runs on real MicroBeast booting with `antforth 24 35-3f` (a non-default tail) and confirms the banner reports the expected bank count; transcript saved per S9.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~200 B for this story (CL parser ~200 B per redesign §7 budget; banner string delta nominal); tracked against the Epic 17 ~400 B budget.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (CL parser is invoked only on `antforth.com` boot under the emulator-with-CL-tail; iz-cpm path unaffected); `make test-repl-banking` reports new CL probes PASS.

**FRs covered:** FR-P4-34, FR-P4-35, FR-P4-36, FR-P4-37, FR-P4-38, FR-P4-39. **Architectural input consumed:** Story 16.4 §9.3 (CL parser edge-case policy).

### Story 17.5: `.BANKS` — minimal working form

As Marc (OG user) wanting to inspect the current banking configuration,
I want `.BANKS` to print a status table showing the logical bank index, physical page, current marker, and per-bank used/free,
So that I have observability into the configuration before bank-aware `:` (Epic 19) makes per-bank `here`/`latest` meaningful.

**Acceptance Criteria:**

**Given** Story 17.4 has shipped (CL parser + banner; configuration is now known at runtime),
**When** Story 17.5 is dev-passed,
**Then** AC1 — `.BANKS ( -- )` is implemented in `src/banking.asm` per FR-P4-6; prints a status table to the console: header row + one row per active bank.
**And** AC2 — each row carries: logical bank index, physical page (hex), current-bank marker (e.g., `*` next to the active bank), per-bank used / free (initial values: used = 0, free = 16384 — full per-bank `here` tracking lands in Epic 19; Story 17.5's `.BANKS` reports zero-used and full-free placeholders).
**And** AC3 — a totals row at the bottom sums the per-bank used / free across all active banks.
**And** AC4 — output format is human-readable; column widths are stable across rows; total output fits in the 80-column CP/M console (no wrap on the default terminal).
**And** AC5 — the source comment marks `.BANKS` as "Epic 17 minimal form — Epic 22 polishes formatting + adds prompt indicator integration" so future readers can locate the polish-pass.
**And** AC6 (CCD-3 source flag) — `.BANKS` carries `; antforth extension .BANKS — see docs/antforth-banking-redesign.md §1` per NFR-P4-14; one row added to `docs/ans-forth-core-compliance.md`.
**And** AC7 (REPL probes) — `tests/banking_tests.fth` extends with a `.BANKS` probe that captures the output under the banking-capable emulator and asserts: at least 12 rows for the default-12-banks configuration; one row per `+BANK`-added page; the current-bank marker (`*`) is on the row matching `BANK@`; after `1 BANK!`, the marker moves to the bank-1 row.
**And** AC8 (hardware smoke) — one hardware-typed `.BANKS` probe runs on real MicroBeast and visually inspects for column-stability + readability; transcript saved per S9.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (formatting loop + literals); tracked against the Epic 17 budget (cumulative envelope check at this point).
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-6 (minimal form). Final polish in Epic 22.

### Story 17.6: Iron-spike — first hand-built cross-bank call on real MicroBeast + Epic 17 close-out + antforth 3.x.1 tag

As Ant (project lead validating the banking layer end-to-end before Epic 18 stub mechanism lands),
I want a hand-built cross-bank call (no descriptor stub, no compiler integration — just `BANK!` + direct address + return-by-RET) verified PASSing on real MicroBeast,
So that the Epic-17 banking foundation is proven load-bearing before Epic 18 builds the stub mechanism on top of it; and I want the Epic-17 close-out tag (`antforth 3.x.1`) applied with S11 user-visible version surface audit clean.

**Acceptance Criteria:**

**Given** Stories 17.1–17.5 are dev-passed (`bank-table[]`, `BANK@`/`BANK!`/`BANKS`, `+BANK`/`-BANK`/`BANKS-CLEAR`/`SET-BANK`, CL parser, banner, `.BANKS` all working),
**When** Story 17.6 is dev-passed,
**Then** AC1 (iron-spike probe) — a hand-written cross-bank probe is authored in `tests/banking_tests.fth` (or `_bmad-output/implementation-artifacts/17.6-iron-spike.fth` if it's experimental enough to keep separate): manually-allocated code body in bank 5 (small RET sled at a known address), `BANK!`-to-5, `EXECUTE` against the known address, RET back, assert no crash and correct state.
**And** AC2 — the iron-spike probe is run under the banking-capable emulator and PASSes (validates the emulator's MMU model is correct).
**And** AC3 — the iron-spike probe is hardware-typed and run on real MicroBeast per NFR-P4-39 (S12 word-existence pre-flight + TIB-128 lint); PASSes on real hardware; transcript saved per S9 / NFR-P4-11.
**And** AC4 — the iron-spike probe is annotated in the test source with explicit "Epic 17 iron-spike — Epic 18 supersedes this with descriptor-stub dispatch" so future readers understand its provisional role.
**And** AC5 (S11 / NFR-P4-38 user-visible version surface audit) — `src/antforth.asm` banner string reads `antforth 3.x.1 — N banks available — ok` (or the exact format established in Story 17.4); `README.md` version reference is updated to `3.x.1`; the memory-file `description` field for the Phase-4-scope memory entry (successor to `project_phase3_scope.md`) reads `3.x.1` or the Phase-4 in-progress equivalent.
**And** AC6 (verdict-table walk per Story-13.5.6 precedent) — Story 17.6 Dev Notes include a verdict-table walk for all Epic-17 stories: Story 17.1 PASS / 17.2 PASS / 17.3 PASS / 17.4 PASS / 17.5 PASS / 17.6 PASS with one-line evidence per story.
**And** AC7 (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no drift between PRD, architecture, this epics document, and the banner / README versions.
**And** AC8 (full test surface sweep) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports all Epic-17 banking probes PASS under the banking-capable emulator; one full hardware-typed smoke batch covering all Epic-17 user-facing words PASSes on real MicroBeast.
**And** AC9 (Epic 17 envelope check) — total Epic-17 binary delta is ≤ ~400 B (per Decision Impact Analysis envelope); cumulative `wc -c build/antforth.com` from Phase-3 close-out (24,995 bytes) is reported; any over-envelope outcome triggers sprint-change-proposal evaluation per NFR-P4-5.
**And** AC10 (tag applied) — `git tag v3.x.1` is applied to the close-out commit; tag is pushed to GitHub release per the NFR-P4-21 / NFR-P4-38 close-out discipline.

**FRs covered:** none directly (close-out + validation). **NFRs codified:** NFR-P4-11 / NFR-P4-36 (S9 hardware smoke per binary-delta story); NFR-P4-21 (epic-level decoupling — antforth 3.x.1 ships); NFR-P4-38 (S11 user-visible version surface audit); NFR-P4-39 (S12 hardware-typed probe discipline).

---

**Epic 17 summary:** 6 stories. Cumulative binary delta target ≤ ~400 B. Ships antforth 3.x.1. After close-out, the banking-control surface (9 user-facing words + CL parser + banner + `.BANKS` minimal + `BANK-MAPPING-*`) is observable end-to-end at the REPL under all three test surfaces. The iron-spike validates the banking layer end-to-end before Epic 18 builds the descriptor-stub mechanism. NFR-P4-2 (bank-switch latency) and NFR-P4-5 (fixed-memory envelope) are both first-measured here against their envelopes.

---

## Epic 18: Stub mechanism (γ) + cross-bank EXIT (S1 b) + `BANK-OF` + `IN-BANK`

**Goal:** Ship the load-bearing cross-bank dispatch infrastructure as antforth 3.x.2. After Epic 18, a hand-allocated banked code body can be `EXECUTE`d via its descriptor-stub address as xt, dispatching through the (γ) stub mechanism; cross-bank returns work through the sentinel-trampoline (S1 b); the intra-bank zero-overhead 1-cell return path is preserved exactly; `BANK-OF` and `IN-BANK` are available at the REPL. Epic 19's bank-aware `:` builds on this foundation.

**User outcomes at epic close-out:**
- Marc (OG user) can hand-allocate a banked code body, take its xt (the stub address), pass the xt across bank boundaries on the data stack, and `EXECUTE` it correctly — round-tripping returns to the caller's bank cleanly.
- Marc can call `IN-BANK ( n xt -- )` to run an arbitrary xt in a named bank with automatic save/restore of the caller's bank; THROWs from inside `xt` still restore the caller's bank on the unwind path (CATCH-safe per FR-P4-4).
- Marc can call `BANK-OF ( xt -- n )` to learn which bank a word lives in (`-1` for fixed-memory words; logical bank index otherwise).
- The intra-bank zero-overhead path is preserved — Phase-1/2/3 EXIT timing is unaffected for words that call other words in the same bank.
- antforth 3.x.2 is tagged with banner / README / memory-`description` aligned per S11 / NFR-P4-38.

**FRs covered:** FR-P4-4 (`IN-BANK`), FR-P4-5 (`BANK-OF`), FR-P4-13 (descriptor stub), FR-P4-14 (initial `COMPILE,` stub-emission; full integration Epic 19), FR-P4-15 (intra-bank ≤ 1 `JP` overhead), FR-P4-16 (cross-bank ≤ 60 T-states + MMU), FR-P4-17 (xt portability), FR-P4-18 (sentinel-tagged 3-cell return frame), FR-P4-19 (intra-bank zero-overhead path), FR-P4-20 (`cross_bank_return` trampoline body), FR-P4-21 (recursive cross-bank R-stack overflow per Story 16.4 §9.6 closure).

**NFRs codified:** NFR-P4-3 (cross-bank call overhead ≤ 60 T-states + MMU); NFR-P4-4 (per-stub size ≤ 5 B — pinned per Story 16.4 §9.5); NFR-P4-7 (REPL survives cross-bank THROW); NFR-P4-8 (state integrity after cross-bank THROW — bank-table[] preserved); NFR-P4-34 (S7 — EXX-hygiene per kernel-internal raise site, re-walked for the trampoline). All 39 NFR-P4-N continue to hold.

**Architectural inputs:** Stories 16.4 §9.5 (stub-size pin) + §9.6 (R-stack overflow disposition).

### Story 18.1: Descriptor-stub allocator + xt-as-stub-address contract

As Ant (developer wiring the (γ) cross-bank dispatch mechanism),
I want a descriptor-stub allocator in `src/banking.asm` that allocates a 3–5-byte stub in fixed memory at definition time, carrying `(target_bank, target_addr_in_bank)`, with the stub's address acting as the word's xt,
So that Epic 18.2's cross-bank EXIT and Epic 18.3's `EXECUTE` switch have a stable per-word artifact to dispatch through, and `BANK-OF` (Story 18.4) becomes a one-byte read.

**Acceptance Criteria:**

**Given** the Epic 17 `bank-table[]` infrastructure exists in `src/banking.asm`,
**When** Story 18.1 is dev-passed,
**Then** AC1 — a descriptor-stub allocator lands in `src/banking.asm` in the CCP-evicted Page-3 region (`$D400–$DBFF`); it allocates stubs at the per-stub size pinned by Story 16.4 §9.5 (the binding decision was 3 / 4 / 5 B — Story 18.1 inherits that verbatim).
**And** AC2 — stub layout follows the architecture convention (`target_bank` field at byte 0 as a signed byte: `-1` for fixed-memory marker, `0..28` for active bank indices; `target_addr_in_bank` at bytes 1–2 as a 16-bit address inside the target bank's body region; any additional bytes per the §9.5 pin); the layout is documented inline per CCD-3 + NFR-P4-20.
**And** AC3 — the allocator name follows the `xt_<word>` convention in source (stub IS the xt; do NOT name `stub_<word>` per the architecture's naming pattern in Implementation Patterns).
**And** AC4 — at this story's close, allocator-callable hand-test: a hand-written test driver allocates one stub for a fixed-memory word (`target_bank = -1`, `target_addr = <known body address>`) and one stub for a hand-built banked code body (`target_bank = 5`, `target_addr = <known address in bank 5>`); both stubs are inspected to confirm the byte layout; both stub addresses are recorded for downstream Story 18.2 / 18.3 / 18.4 probes.
**And** AC5 — the allocator carries `; antforth Phase-4 — see docs/antforth-banking-redesign.md §2.1 (γ mechanism)` per CCD-3 / NFR-P4-20.
**And** AC6 (NFR-P4-4 per-stub size) — a benchmark probe measures one stub's allocation footprint; reports against the ≤ 5 B envelope; result captured in Dev Notes.
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — a probe allocates a stub, reads `target_bank` and `target_addr_in_bank` via direct memory peeks (`@`, `C@`), asserts the expected values; another probe allocates 10 stubs, walks the allocator-tail to confirm sequential allocation with no overlap.
**And** AC8 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe runs on real MicroBeast asserting two allocated stubs have distinct, non-overlapping addresses; transcript saved per S9 / NFR-P4-11.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~150 B for this story (allocator routine + allocator-tail UserArea cell + stub-layout documentation); tracked against the Epic 18 ~400 B budget per Decision Impact Analysis.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-13 (descriptor stub), FR-P4-17 (xt portability — stub is in fixed memory so xts are stable across `BANK!`). **NFR codified:** NFR-P4-4 (per-stub size). **Architectural input consumed:** Story 16.4 §9.5 (stub-size pin).

### Story 18.2: Sentinel-trampoline `cross_bank_return` + kernel `EXIT` distinguishes intra-bank from cross-bank

As Ant (developer wiring the (S1 b) sentinel-trampoline cross-bank EXIT),
I want the `cross_bank_return` trampoline in fixed memory, and kernel `EXIT` extended with a sentinel-address comparison so the intra-bank zero-overhead 1-cell return path is preserved while cross-bank returns route through the trampoline to restore the caller's bank,
So that Epic 18.3's `EXECUTE` switch + Epic 19's bank-aware `:` can rely on `EXIT` doing the right thing automatically.

**Acceptance Criteria:**

**Given** Story 18.1 has shipped (descriptor-stub allocator exists),
**When** Story 18.2 is dev-passed,
**Then** AC1 — a `cross_bank_return:` label exists at a fixed address in `src/banking.asm`; the trampoline pops `target_addr` and `caller_bank` from the return stack, writes `caller_bank` to the MMU port for slot 2, and jumps to `target_addr` (per FR-P4-20 / redesign §2.2).
**And** AC2 — the sentinel address IS `cross_bank_return` itself (one symbol does both jobs per the architecture's "Sentinel-trampoline labels" pattern).
**And** AC3 — `src/inner_interpreter.asm`'s `w_EXIT_cf` is extended with a sentinel comparison: if the top of the return stack equals `cross_bank_return`, drop the sentinel and fall through to the trampoline (which then handles the bank-switch + jump); otherwise the standard 1-cell return path runs unchanged (per FR-P4-19 — intra-bank zero-overhead path preserved exactly).
**And** AC4 (NFR-P4-19 intra-bank invariance) — a benchmark probe times an intra-bank `EXIT` round-trip against the Phase-3 baseline; assert the intra-bank path adds no measurable overhead beyond a single `CP` against the sentinel; result captured in Dev Notes.
**And** AC5 (S7 EXX-hygiene — NFR-P4-34) — the `cross_bank_return` trampoline's source is re-walked against `docs/register-conventions.md` §3 leaf-level rule + §7 EXX-using inventory; the trampoline's THROW-raise potential is documented (it does not raise THROW under normal operation — the MMU port write is hardware-deterministic — but if a future `+BANK`-cap-policy disposition ever turns the trampoline into a raise site, the re-walk discipline applies); CCD-3 source comment records the audit.
**And** AC6 (recursive cross-bank R-stack — FR-P4-21) — per Story 16.4 §9.6 closure (documented-gotcha disposition), no runtime guard is added; the existing `-5 RETURN-STACK-OVERFLOW` THROW catches runaway recursion; the gotcha is documented in the source comment.
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — hand-built cross-bank-EXIT probes: (a) push the 3-cell sentinel frame manually `(sentinel_addr, 5, return_addr)`, invoke `EXIT`, assert the bank switches to 5 and execution resumes at `return_addr`; (b) intra-bank `EXIT` round-trip with no sentinel and assert no bank switch occurs (read MMU port via `SET-BANK`-style memory inspection).
**And** AC8 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe runs on real MicroBeast confirming the trampoline's MMU port write + jump path; transcript saved per S9 / NFR-P4-11.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (trampoline body + EXIT sentinel branch); tracked against the Epic 18 budget.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (intra-bank path preserved exactly — Phase-3 baseline regression-clean); `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-18 (sentinel-tagged cross-bank return), FR-P4-19 (intra-bank zero-overhead path), FR-P4-20 (`cross_bank_return` trampoline), FR-P4-21 (recursive cross-bank R-stack — per §9.6 closure). **NFRs codified:** NFR-P4-7 (cross-bank THROW survivability), NFR-P4-34 (S7 EXX-hygiene re-walk for the trampoline).

### Story 18.3: Kernel `EXECUTE` dispatches through stub + initial `COMPILE,` stub-emission wiring + dispatch-budget verification

As Marc (OG user) calling `EXECUTE` with an xt that may live in any bank,
I want kernel `EXECUTE` to dispatch through the descriptor stub correctly, switching MMU + pushing the sentinel frame on cross-bank entry, falling through with one `JP` overhead on intra-bank entry,
So that all downstream Epic-19 colon definitions can compile xt references without inspecting bank state at call site (per FR-P4-14 transparent compiler emission).

**Acceptance Criteria:**

**Given** Stories 18.1 (stub allocator) + 18.2 (sentinel-trampoline EXIT) have shipped,
**When** Story 18.3 is dev-passed,
**Then** AC1 — `src/inner_interpreter.asm`'s `w_EXECUTE_cf` is extended: read `target_bank` byte from stub-address; if `target_bank == BANK@` or `target_bank == -1` (fixed memory), fall through to a single `JP <target_addr_in_bank>` (intra-bank zero-overhead vs flat per FR-P4-15); else push the 3-cell sentinel frame `(cross_bank_return, BANK@, return_addr)`, write `target_bank` to MMU slot 2, jump to `target_addr_in_bank` (cross-bank dispatch per FR-P4-16 / FR-P4-18).
**And** AC2 — `src/compiler.asm`'s `w_COMPILE_COMMA_cf` is extended to always emit the stub address (the word's xt) per FR-P4-14 initial wiring; full integration with bank-aware `:` lands in Epic 19 (where `:` allocates the stub itself); Story 18.3 only wires `COMPILE,` to treat the xt as the stub address (the architecture-locked xt-as-stub-address contract per FR-P4-13 / FR-P4-17).
**And** AC3 (NFR-P4-3 cross-bank call overhead) — a benchmark probe times a cross-bank call (caller in bank A, target in bank B, return) end-to-end from the call site's `JP <stub>` to the first instruction of the target body in the new bank; assert ≤ 60 T-states + MMU port-write time; result captured in Dev Notes against the envelope.
**And** AC4 (NFR-P4-19 intra-bank invariance) — a benchmark probe times an intra-bank `EXECUTE` against the Phase-3 baseline; assert intra-bank `EXECUTE` adds exactly one `JP` overhead vs flat dispatch per FR-P4-15.
**And** AC5 (REPL probes — `tests/banking_tests.fth`) — hand-built cross-bank `EXECUTE` probes: (a) allocate stub for fixed-memory word, `EXECUTE` it, assert it runs in fixed memory (no MMU switch); (b) allocate stub for hand-built banked body in bank 5, `BANK!`-to-0, `EXECUTE` the stub, assert bank switches to 5, the body runs, and `EXIT` (via Story 18.2's trampoline) returns to bank 0 with state intact; (c) repeat (b) from bank 7 (cross-bank-from-non-zero) and assert correct round-trip; (d) data-stack passing — pass values across the cross-bank `EXECUTE` and assert they survive the bank switch (xt portability per FR-P4-17).
**And** AC6 (cross-bank THROW survivability — NFR-P4-7) — a probe builds a banked body that raises THROW; `CATCH` of the cross-bank `EXECUTE` returns the THROW code on the data stack; assert the caller's bank is restored on the unwind path (trampoline runs even on THROW unwind).
**And** AC7 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering all four AC5 sub-probes + AC6 unwind probe runs on real MicroBeast; transcript saved per S9 / NFR-P4-11.
**And** AC8 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (EXECUTE extension + COMPILE, edit); tracked against the Epic 18 budget.
**And** AC9 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-14 (initial `COMPILE,` stub emission), FR-P4-15 (intra-bank ≤ 1 `JP`), FR-P4-16 (cross-bank ≤ 60 T-states + MMU), FR-P4-17 (xt portability — verified via data-stack passing probe). **NFRs codified:** NFR-P4-3 (cross-bank call overhead), NFR-P4-7 (cross-bank THROW survivability).

### Story 18.4: `BANK-OF` — one-byte read from descriptor stub

As Marc (OG user) debugging cross-bank dependencies,
I want `BANK-OF ( xt -- n )` to return the bank a word lives in (`-1` for fixed-memory words; logical bank index otherwise),
So that I can disambiguate "this word is in bank 5" from "this word is in fixed memory" when writing cross-bank applications or investigating dispatch surprises.

**Acceptance Criteria:**

**Given** Story 18.1 has shipped (stub layout has `target_bank` at byte 0),
**When** Story 18.4 is dev-passed,
**Then** AC1 — `BANK-OF ( xt -- n )` is implemented in `src/banking.asm` per FR-P4-5; reads byte 0 of the stub at `xt` (treats it as a signed byte to preserve the `-1` fixed-memory marker); returns `n` on the data stack.
**And** AC2 — the implementation is the one-byte read promised by the (γ) decision (essentially free under the descriptor-stub mechanism per PD-P4-1 rationale).
**And** AC3 — `BANK-OF` carries `; antforth extension BANK-OF — see docs/antforth-banking-redesign.md §1` per CCD-3 / NFR-P4-14; one row added to `docs/ans-forth-core-compliance.md`.
**And** AC4 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `' BANK@ BANK-OF .` returns `-1 ok` (BANK@ is a fixed-memory word); (b) hand-allocate a stub for a banked body in bank 5, take its address as xt, `BANK-OF .` returns `5 ok`; (c) the same xt passed through `BANK!`-to-other-bank and back still reads `5` (xt portability + bank-info-stable check per FR-P4-17).
**And** AC5 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed `BANK-OF` probe runs on real MicroBeast; transcript saved per S9 / NFR-P4-11.
**And** AC6 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~30 B for this story (one-byte-read primitive is tiny); tracked against the Epic 18 budget.
**And** AC7 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-5 (`BANK-OF`).

### Story 18.5: `IN-BANK` (kernel-blessed, CATCH-safe) + Epic 18 close-out + antforth 3.x.2 tag

As Marc (OG user) wanting to invoke a library word in a specific bank without manually saving/restoring,
I want `IN-BANK ( n xt -- )` to save the current bank, switch to bank `n`, execute `xt`, and restore the saved bank on exit (including on THROW unwind — CATCH-safe per FR-P4-4),
And as Ant (project lead) I want the Epic 18 close-out tag (`antforth 3.x.2`) applied with S11 user-visible version surface audit clean.

**Acceptance Criteria:**

**Given** Stories 18.1 (stub allocator) + 18.2 (sentinel-trampoline EXIT) + 18.3 (`EXECUTE` switch) + 18.4 (`BANK-OF`) have shipped,
**When** Story 18.5 is dev-passed,
**Then** AC1 — `IN-BANK ( n xt -- )` is implemented in `src/banking.asm` as a kernel-blessed word (not user library); reference body: `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;`; the kernel implementation may inline the reference body for tightness but must preserve the externally-observable semantics.
**And** AC2 (CATCH-safe per FR-P4-4) — a probe wraps `IN-BANK` in a `CATCH` frame with an `xt` that raises THROW; the CATCH frame receives the THROW code on the data stack AND the caller's bank is restored on the unwind path; the saved-bank `>R / R>` mechanism in the kernel implementation ensures this even on THROW (independent of Story 18.2's cross-bank trampoline — `IN-BANK`'s save/restore is its own discipline per the redesign §1 commentary that `IN-BANK` is "kernel-blessed, not user library").
**And** AC3 — `IN-BANK` carries `; antforth extension IN-BANK — see docs/antforth-banking-redesign.md §1` per CCD-3 / NFR-P4-14; one row added to `docs/ans-forth-core-compliance.md`.
**And** AC4 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `5 ' SOME-WORD IN-BANK` runs `SOME-WORD` in bank 5 and returns to the caller's bank (verified by `BANK@` before/after); (b) nested `IN-BANK` invocations (outer `5 IN-BANK { inner: 7 IN-BANK }`) round-trip correctly with the original bank restored; (c) CATCH-safe variant: `' RAISE-13 CATCH-XT 5 SWAP IN-BANK` returns `-13` on the data stack AND `BANK@` returns the original bank.
**And** AC5 (Epic 18 close-out: S11 / NFR-P4-38 user-visible version surface audit) — `src/antforth.asm` banner reads `antforth 3.x.2 — N banks available — ok`; `README.md` version reference is updated to `3.x.2`; the Phase-4-scope memory entry's `description` field reads `3.x.2`.
**And** AC6 (Epic 18 close-out: verdict-table walk per Story-13.5.6 precedent) — Story 18.5 Dev Notes include a verdict-table walk for all Epic-18 stories: 18.1 PASS / 18.2 PASS / 18.3 PASS / 18.4 PASS / 18.5 PASS with one-line evidence per story.
**And** AC7 (Epic 18 close-out: `make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no drift between PRD, architecture, this epics document, and the banner / README versions.
**And** AC8 (Epic 18 close-out: full test surface sweep) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports all Epic-17 + Epic-18 banking probes PASS under the banking-capable emulator; one full hardware-typed smoke batch covering all Epic-18 user-facing words (`IN-BANK`, `BANK-OF`, cross-bank `EXECUTE` patterns) PASSes on real MicroBeast.
**And** AC9 (Epic 18 envelope check) — total Epic-18 binary delta is ≤ ~400 B per Decision Impact Analysis envelope (allocator ~150 B + trampoline ~80 B + EXECUTE-switch ~50 B + IN-BANK + BANK-OF ~120 B); cumulative `wc -c build/antforth.com` is reported; any over-envelope outcome triggers sprint-change-proposal evaluation per NFR-P4-5; banked-word stub-count metric (CCD-4 close-out line item per Finding F2 mitigation) is captured for the first time.
**And** AC10 (tag applied) — `git tag v3.x.2` is applied to the close-out commit; tag is pushed to GitHub release.

**FRs covered:** FR-P4-4 (`IN-BANK`). **NFRs codified:** NFR-P4-11 / NFR-P4-36 (S9 hardware smoke per binary-delta story); NFR-P4-21 (epic-level decoupling — antforth 3.x.2 ships); NFR-P4-38 (S11 user-visible version surface audit); NFR-P4-39 (S12 hardware-typed probe discipline).

---

**Epic 18 summary:** 5 stories. Cumulative binary delta target ≤ ~400 B. Ships antforth 3.x.2. After close-out, the cross-bank dispatch infrastructure is observable end-to-end at the REPL: stubs allocated, sentinel-trampoline EXIT working, `EXECUTE` switching through stubs, `BANK-OF` reading stub byte 0, `IN-BANK` CATCH-safe. Epic 19's bank-aware `:` builds directly on this. NFR-P4-3 (cross-bank call overhead) is first-measured here; F2 banked-word stub-count metric tracking starts at 18.5 per CCD-4 close-out.

---

## Epic 19: Bank-aware compiler (`:` / `,` / `COMPILE,` / `CREATE` / `DOES>`)

**Goal:** Ship the bank-aware compiler as antforth 3.x.3. After Epic 19, the user types `5 BANK! : MYWORD ... ;` and the colon defines into bank 5 transparently — the north-star UX. Per-bank `(here, latest, wordlist-heads)` triple is fully plumbed through the compiler chain; `:` allocates the body in the current bank + the descriptor stub in fixed memory; `CREATE` / `DOES>` follow the cross-bank-explicit doer-stub + data-cell PFA layout.

**User outcomes at epic close-out:**
- Marc (OG user) types `5 BANK! : MYWORD ... ;` and the colon body lands in bank 5; subsequent `MYWORD` calls from any bank dispatch correctly via stub (intra-bank when caller is in bank 5; cross-bank when caller is elsewhere).
- Marc can use `CREATE`/`DOES>` to build defining words; the doer-stub + data-cell PFA layout is explicit (the user arranges cross-bank `CREATE`/`DOES>` patterns by hand — no auto-redirect per FR-P4-25).
- `HERE` and `LATEST` return per-bank values; `BANK!` swaps the active dictionary state atomically; cross-bank pointer hazards are accepted as documented gotchas per redesign §5.4.
- antforth 3.x.3 is tagged with banner / README / memory-`description` aligned per S11 / NFR-P4-38.

**FRs covered:** FR-P4-14 (full `COMPILE,` integration with bank-aware compilation), FR-P4-22 (per-bank dictionary state — full plumbing), FR-P4-23 (per-bank `,` and `COMPILE,`), FR-P4-24 (`:` lands body in current bank), FR-P4-25 (`CREATE`/`DOES>` cross-bank explicit), FR-P4-26 (`HERE` / `LATEST` per bank).

**NFRs codified:** NFR-P4-1 (Phase-2 NFR1–NFR5 envelopes hold — including the multi-vocabulary lookup regression ≤ 10%); NFR-P4-8 (state integrity after error — bank-table[] entries not corrupted by mid-compilation THROW); NFR-P4-18 (banking-code readability + redesign-doc §-citations); NFR-P4-31 (S4 — AC-composition validation for each story). All 39 NFR-P4-N continue to hold.

**Architectural inputs:** Epic 18 (descriptor-stub allocator + cross-bank EXECUTE + EXIT all in place).

### Story 19.1: Per-bank `HERE` / `LATEST` + per-bank `,` / `C,` / `COMPILE,` — full cell-write plumbing

As Marc (OG user) wanting to compile cells into a specific bank,
I want `HERE`, `LATEST`, `,`, `C,`, and `COMPILE,` to all read from and write to the current bank's `(here, latest, wordlist-heads)` triple in `bank-table[]`,
So that subsequent Story 19.2 (`:` lands body in current bank) and 19.3 (`CREATE`/`DOES>`) have a coherent per-bank cell-write foundation to compose against.

**Acceptance Criteria:**

**Given** Epic 17 has shipped (`bank-table[]` shell allocated, `BANK!` swap routine working) and Epic 18 has shipped (descriptor-stub allocator working, cross-bank EXECUTE working),
**When** Story 19.1 is dev-passed,
**Then** AC1 — `src/memory.asm`'s `w_HERE_cf` is extended to read the `here` field from the current bank's `bank-table[]` entry (per FR-P4-26) rather than from a single global cell; the Phase-1/2/3 single-dictionary-pointer model is preserved for bank 0 (the active state cell continues to act as the read-cache; `BANK!` swap is the consistency mechanism per architecture's "Per-bank state field naming").
**And** AC2 — `src/memory.asm`'s `w_LATEST_cf` is extended likewise to read the `latest` field from the current bank's `bank-table[]` entry (per FR-P4-26).
**And** AC3 — `src/memory.asm`'s `,` and `C,` are extended to write into the current bank's `here` and advance the per-bank `here` (per FR-P4-23); cross-bank `,` is NOT exposed (the user must `BANK!` to the target bank to write into it — explicit ergonomic decision per redesign §5.4).
**And** AC4 — `src/compiler.asm`'s `w_COMPILE_COMMA_cf` finalises its Epic-18.3-initial wiring: `COMPILE,` writes the xt (a stub address in fixed memory) at the current bank's `here` and advances (per FR-P4-23); the xt is always the stub address per the architecture-locked xt-as-stub-address contract from FR-P4-13.
**And** AC5 (cross-bank pointer hazard — FR-P4-26 "doc-and-pray") — the source code carries an inline comment naming the hazard ("user holds HERE from bank A then `BANK!`s to B and writes there — undefined; no runtime guard per redesign §5.4"); the actual user-docs entry lands in Epic 22 polish (F4 mitigation).
**And** AC6 (CCD-3 source citations per NFR-P4-20) — each extended word carries an inline `; per-bank — see docs/antforth-banking-redesign.md §5.4` comment block.
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `5 BANK! HERE @ DUP , @ .` returns the same address written, verifying per-bank `,` (b) `5 BANK! HERE @ 0 BANK! HERE @ - .` returns a non-zero delta (`HERE` is per-bank); (c) `5 BANK! 42 , 0 BANK! 5 BANK! HERE @ CELL- @ .` returns `42 ok` (cell written in bank 5 survives bank switches); (d) `LATEST @` returns different values after `BANK!`-switching; (e) `5 BANK! ' BANK@ COMPILE,` writes a fixed-memory stub address into bank 5's `here`; verified by reading the cell back and confirming it points into the descriptor-stub region.
**And** AC8 (NFR-P4-1 — Phase-2 envelopes hold) — a benchmark probe times intra-bank `,` and `C,` against the Phase-3 baseline; assert ≤ 5% regression (per-bank indirection adds one offset-from-bank-table[]-base read on the hot path); result captured in Dev Notes.
**And** AC9 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC7 (a)–(e) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC10 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~150 B for this story (per-bank read/write plumbing for HERE/LATEST/,/C,/COMPILE,); tracked against the Epic 19 ~300 B budget per Decision Impact Analysis.
**And** AC11 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (intra-bank-zero behavior preserved for the bank-0 / flat-equivalent path); `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-14 (final `COMPILE,` integration), FR-P4-22 (per-bank dictionary state — full plumbing), FR-P4-23 (per-bank `,` and `COMPILE,`), FR-P4-26 (`HERE` / `LATEST` per bank). **NFRs codified:** NFR-P4-1 (Phase-2 envelope hold).

### Story 19.2: `:` lands body in current bank + auto-emits descriptor stub on `;` (compiler-transparent banking)

As Marc (OG user) wanting bank-aware colon definitions,
I want `:` to allocate the word body in the current bank's `here`, allocate the descriptor stub in fixed memory, link the new word into the current bank's `latest`, and update the current wordlist's chain — with the new word's xt being the stub address,
So that the north-star UX lands: I type `5 BANK! : MYWORD ... ;` and the colon defines into bank 5 transparently; subsequent `MYWORD` calls dispatch via stub (intra-bank when caller is in bank 5; cross-bank when caller is in a different bank).

**Acceptance Criteria:**

**Given** Story 19.1 has shipped (per-bank `HERE` / `LATEST` / `,` / `C,` / `COMPILE,` all working) and Epic 18 has shipped (descriptor-stub allocator + cross-bank EXECUTE),
**When** Story 19.2 is dev-passed,
**Then** AC1 — `src/compiler.asm`'s `w_COLON_cf` is extended (per FR-P4-24): allocates the word body at the current bank's `here`; calls the Epic-18.1 descriptor-stub allocator to allocate the stub in fixed memory; populates the stub with `(target_bank = BANK@, target_addr = body_address)`; links the new word into the current bank's `latest`; updates the current wordlist's chain to point at the new word.
**And** AC2 — at `;`, the new word's xt is the stub address (the architecture-locked xt-as-stub-address contract per FR-P4-13 / FR-P4-17); `LATEST` returns the new word's stub address; `' MYWORD` returns the stub address.
**And** AC3 — source text for `:`-defined words is identical to flat-memory antforth (no banking-specific syntax — the compiler-transparent banking promise from FR-P4-14); the only difference between flat and banked compilation is which bank `here` is in.
**And** AC4 (intra-bank dispatch — FR-P4-15) — verified by probe: `5 BANK! : INTRA-CALLER MYWORD ;` (where MYWORD also lives in bank 5); calling `INTRA-CALLER` from bank 5 dispatches MYWORD with one extra `JP` overhead vs flat (no MMU port write).
**And** AC5 (cross-bank dispatch — FR-P4-16) — verified by probe: `5 BANK! : BANKED-WORD ... ; 0 BANK! BANKED-WORD` dispatches correctly via the stub (MMU switches to bank 5 + sentinel frame pushed + body runs + `EXIT` via trampoline returns to bank 0); benchmark probe measures cross-bank call overhead ≤ 60 T-states + MMU port-write against NFR-P4-3.
**And** AC6 (state integrity after compilation THROW — NFR-P4-8) — a probe interrupts compilation mid-definition (e.g., compilation-only word called outside compilation triggers a THROW); assert the bank-table[] entry for the current bank is NOT corrupted (allocator-tail rollback semantics or compile-only-on-success discipline — exact mechanism per architecture's existing compile-error recovery in `src/exception.asm`); subsequent definitions in the same bank work cleanly.
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `0 BANK! : W0 42 ;` then `5 BANK! : W5 7 ;` then `0 BANK! W0 .` and `W5 .` both return correct values (cross-bank `:` works); (b) `' W5 BANK-OF .` returns `5 ok` (the stub records the correct bank per FR-P4-13); (c) `' W0 BANK-OF .` returns `0 ok`; (d) `: TEST-LATEST 1 2 3 ; LATEST @` returns the stub address of TEST-LATEST; verified the body content lives in the current bank.
**And** AC8 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC7 (a)–(d) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (`:` extension to call stub allocator + link into per-bank latest); tracked against the Epic 19 budget.
**And** AC10 (banked-word stub-count metric — F2 mitigation) — Story 19.2 Dev Notes capture the per-test-run stub allocation count; metric trends added to CCD-4 close-out at Story 19.4.
**And** AC11 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-24 (`:` lands body in current bank). **NFRs codified:** NFR-P4-3 (cross-bank call overhead measured against envelope), NFR-P4-8 (state integrity after compilation THROW).

### Story 19.3: `CREATE` / `DOES>` cross-bank explicit — doer-stub + data-cell PFA layout

As Marc (OG user) building defining words with `CREATE`/`DOES>`,
I want `CREATE` to allocate a doer-stub in fixed memory + a data cell in the current bank's data space, with the PFA storing the doer-stub address paired with the data cell, and `DOES>` to reassign the doer-stub's target,
So that defining-word patterns work correctly across banks (the user explicitly arranges cross-bank `CREATE`/`DOES>` — no auto-redirect across banks per FR-P4-25).

**Acceptance Criteria:**

**Given** Stories 19.1 + 19.2 have shipped (per-bank cell-write + bank-aware `:` working),
**When** Story 19.3 is dev-passed,
**Then** AC1 — `src/compiler.asm`'s `w_CREATE_cf` is extended (per FR-P4-25): allocates a doer-stub in fixed memory + a data cell in the current bank's data space; the PFA stores the doer-stub address paired with the data cell; the doer-stub's initial target is the default-doer routine (the same routine flat `CREATE` uses when no `DOES>` has been attached).
**And** AC2 — `src/compiler.asm`'s `w_DOES_cf` is extended (per FR-P4-25): reassigns the doer-stub's target to the post-`DOES>` code block; the data cell paired with the doer-stub is unchanged.
**And** AC3 — cross-bank `CREATE`/`DOES>` patterns are user-explicit per FR-P4-25 (no auto-redirect): the user invokes `CREATE` in the bank where they want the data cell to live; the doer-stub lands in fixed memory regardless of which bank issued the `CREATE`.
**And** AC4 (cross-bank pointer hazard documented) — the source carries an inline comment noting that holding the data-cell address from one bank and reading it after `BANK!`-switching is the same "doc-and-pray" hazard as FR-P4-26's `HERE` hazard; no runtime guard.
**And** AC5 (CCD-3 source citation) — `CREATE` and `DOES>` source comments cite `docs/antforth-banking-redesign.md §<n>` per NFR-P4-20.
**And** AC6 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `5 BANK! CREATE C5-VALUE 42 , C5-VALUE @ .` returns `42 ok` (data cell lives in bank 5); (b) `0 BANK! C5-VALUE @ .` also returns `42 ok` (data cell is reachable across bank switches via the PFA's stable doer-stub + data-cell pair — but the user must understand the data-cell address is bank-5-resident; this is the documented gotcha); (c) `: ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ;` defining word works across banks: `5 BANK! 4 ARRAY MY-ARR 0 BANK! 2 MY-ARR @ .` exercises cross-bank `CREATE`/`DOES>` with the data in bank 5 and the call from bank 0.
**And** AC7 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC6 (a)–(c) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC8 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~70 B for this story (`CREATE` + `DOES>` extensions); tracked against the Epic 19 budget.
**And** AC9 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-25 (`CREATE`/`DOES>` cross-bank explicit).

### Story 19.4: Epic 19 close-out + antforth 3.x.3 tag

As Ant (project lead applying the Epic 19 close-out tag),
I want the user-visible version surface aligned (banner / README / memory-`description` all reading `3.x.3`), the full test surface clean across iz-cpm + banking-capable emulator + real MicroBeast, the banked-word stub-count metric captured per CCD-4 close-out, and the verdict-table walk recorded,
So that Phase 4's compiler-transparent banking promise (the north-star UX) is shipped as antforth 3.x.3 with a clean integration test pass.

**Acceptance Criteria:**

**Given** Stories 19.1 + 19.2 + 19.3 have shipped,
**When** Story 19.4 is dev-passed,
**Then** AC1 (S11 / NFR-P4-38 user-visible version surface audit) — `src/antforth.asm` banner reads `antforth 3.x.3 — N banks available — ok`; `README.md` version reference is updated to `3.x.3`; the Phase-4-scope memory entry's `description` field reads `3.x.3`.
**And** AC2 (verdict-table walk per Story-13.5.6 precedent) — Story 19.4 Dev Notes include a verdict-table walk for all Epic-19 stories: 19.1 PASS / 19.2 PASS / 19.3 PASS / 19.4 PASS with one-line evidence per story.
**And** AC3 (banked-word stub-count metric per CCD-4 + F2 mitigation) — Story 19.4 Dev Notes capture: total banked-word count after Epic 19; total descriptor-stub fixed-memory occupancy; trend vs Story 18.5 baseline; assert against the ≤ 5 KB stub-allocation envelope from NFR-P4-4 × 1000-word target.
**And** AC4 (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no drift between PRD, architecture, this epics document, and the banner / README versions.
**And** AC5 (integration probe — the north-star UX in one breath) — a single probe in `tests/banking_tests.fth` exercises the full compiler-transparent banking story: boot with defaults; `5 BANK! : FROM-FIVE 100 ;` defines into bank 5; `0 BANK! FROM-FIVE .` returns `100 ok` from bank 0; `7 BANK! FROM-FIVE .` returns `100 ok` from bank 7; `' FROM-FIVE BANK-OF .` returns `5 ok`; `5 ' FROM-FIVE IN-BANK` runs FROM-FIVE under explicit `IN-BANK` and returns to the caller's bank cleanly.
**And** AC6 (full test surface sweep) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (Phase-3 baseline preserved); `make test-repl-banking` reports all Epic-17 + Epic-18 + Epic-19 probes PASS under the banking-capable emulator; one full hardware-typed smoke batch covering Epic 19's compiler-transparent banking surface PASSes on real MicroBeast per S9 / NFR-P4-11.
**And** AC7 (Epic 19 envelope check) — total Epic-19 binary delta is ≤ ~300 B per Decision Impact Analysis envelope; cumulative `wc -c build/antforth.com` from Phase-3 close-out is reported; any over-envelope outcome triggers sprint-change-proposal evaluation per NFR-P4-5.
**And** AC8 (tag applied) — `git tag v3.x.3` is applied to the close-out commit; tag is pushed to GitHub release.

**FRs covered:** none directly (close-out + integration verification of the full Epic-19 surface). **NFRs codified:** NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic-level decoupling — antforth 3.x.3 ships); NFR-P4-38 (S11); NFR-P4-39 (S12).

---

**Epic 19 summary:** 4 stories. Cumulative binary delta target ≤ ~300 B. Ships antforth 3.x.3. After close-out, the north-star UX is observable at the REPL: `5 BANK! : MYWORD ... ;` defines into bank 5 transparently and calls from any bank dispatch correctly. The banked-word stub-count metric becomes a per-epic CCD-4 close-out line item from Story 19.4 forward (F2 mitigation operational).

**Close-out reframing (DECISION 2026-06-03):** Epic 19 closes shipping the *verified* bank-aware compiler **mechanism** (`:` / `CREATE` / `COMPILE,` allocate bodies + stubs correctly; emulator + bank-0/Probe-D hardware PASS). The *behavioural* north-star claim in the summary above — calling a banked word **from a compiled definition** in another bank — is BLOCKED by the DTC-threading-through-stub-xt root defect and is descoped to **Epic 19.5** (the stabilization interlude). Concretely for Story 19.4: AC5's `0 BANK! FROM-FIVE .` (compiled-body cross-bank) must be reworded to the EXECUTE-explicit form (`' FROM-FIVE EXECUTE`) when 19.4 is drafted — mirroring the 19.2/19.3 CR-pass rewording — and AC7's ≤300 B envelope check needs reconciling: the DTC rework is out-of-Epic-19 (lands in Epic 19.5's own envelope), **but Epic 19's own shipped cumulative is already +303 B (19.1 +20, 19.2 +123, 19.3 +35, 19.3.1 +125 — the last verified by CR rebuild 2026-06-03, correcting the dev-pass's +89), just over the ~300 B line.** Story 19.4's AC7 must record an accept-with-rationale + SCP envelope re-baseline (Epic-19's realistic envelope is ~720–810 B per the [[project_epic17_envelope]] 2.4–2.7× pattern; 303 B sits comfortably inside that), not a clean ≤300 B pass. Architectural debt anchored on Epic 19.5: DTC dispatch rework · **cross-bank trampoline assumes a DOCOL/EXIT pair** (non-DOCOL targets — `DOVAR`/`DOCON`/`VARIABLE`/code-words — hang because the pre-loaded `cross_bank_return` sentinel is never pushed/popped; surfaced by Probe-19.3-F; a *distinct* root cause from the DTC defect) · sentinel-trampoline layout-fragility · intra-bank-EXECUTE-into-slot-2 HW gap (Probe-19.2-F) · CATCH-cross-bank reboot · bank-N HERE COLD-init (H5).

---

## Epic 19.5: Cross-bank dispatch stabilization (DTC threading rework) — interlude

**Goal:** Discharge the Epic-19 architectural debt and make compiled-body banked dispatch actually work. Epic 18/19 wired the descriptor-stub mechanism structurally and verified it via explicit `EXECUTE` + on the bank-0/hardware paths, but a banked word **called from a compiled definition** corrupts the kernel: the inner-interpreter `NEXT` (`src/macros.asm` `NEXTHL` — `LD E,(HL)/INC/LD D,(HL)/INC/EX DE,HL/JP (HL)`) dispatches the fetched thread cell with a blind `JP (HL)`, and a banked word's cell is a descriptor-stub xt whose byte 0 = `target_bank` decodes as a Z80 opcode (e.g. `$05` = `DEC B`), so the stub's raw `JP target_addr` runs **without** the MMU swap + sentinel trampoline that `w_EXECUTE_cf`'s 3-way dispatch (`src/inner_interpreter.asm:387..463`) performs. `NEXT` is the dispatch chokepoint that was never taught about stubs. **There are TWO distinct dispatch root causes** the ADR must address, not one: (a) the DTC-threading defect above (`NEXT`'s blind `JP (HL)` into a stub); and (b) the cross-bank **sentinel-trampoline assumes a DOCOL/EXIT pair** — `w_EXECUTE_cf.cross_bank` pre-loads `DE = cross_bank_return` and relies on the target pushing it via DOCOL and popping it via EXIT, so `DOVAR`/`DOCON`/`VARIABLE`/code-word targets (which push data and `NEXT` directly, no R-stack frame) dereference the sentinel address as a thread cell → hang (surfaced by Probe-19.3-F). The fix for (b) may be subsumed by the (a) rework or may need its own trampoline-entry change; the ADR decides. This is an explicit **stabilization interlude epic** (own number + own envelope) per the Epic-11.5 / Epic-13.5 precedent.

**This epic leads with an ADR spike — no kernel edit until two decisions are locked.**

**User outcomes at epic close-out:**
- Marc (OG user) types `5 BANK! : MYWORD ... ;` with no manual `ALLOT` workaround, then calls `MYWORD` from a compiled definition in any bank — it dispatches correctly (intra-bank one extra `JP`; cross-bank via MMU swap + sentinel trampoline). This is the Epic-19 north-star UX, finally behavioural.
- The HW intra-bank-EXECUTE-into-slot-2 dispatch (Probe-19.2-F, which hangs on real MicroBeast) runs cleanly; `CATCH` around a cross-bank `EXECUTE` no longer reboots the kernel.

**Stories (authored FROM the locked ADR — provisional shape):**
- **Story 19.5.0 — ADR spike (zero binary delta).** Two decision records: (1) **sentinel-trampoline layout-fragility** root-cause + fix — why a +17–33 B kernel shift hangs the cross-bank EXIT chain under iz-cpm-banking (the gating prerequisite: no large rework can be *landed or verified* until this is understood); (2) **DTC-dispatch architecture** — choose A (inline `NEXTHL` discriminator, ~+250 B, hot-path T-state cost), B (shared `next_dispatch` subroutine, ~+130 B, +1 JP/step), or C (self-dispatching stub — zero `NEXT` cost, reopens Epic-18's locked 4-byte stub contract, can fold `EXECUTE`'s 3-way into the stub), with measured envelope + T-state evidence against NFR-P4-1/3.
- **Story 19.5.1 — trampoline stabilization.** Land the layout-fragility fix from the ADR so subsequent growth stops hanging the EXIT chain (unblocks H5 and any rework byte-cost).
- **Story 19.5.2 — dispatch rework.** Implement the chosen architecture; route stub-xt thread dispatch through the EXECUTE-equivalent 3-way logic (root cause (a)), AND fix the cross-bank trampoline so non-DOCOL targets — `DOVAR`/`DOCON`/`VARIABLE`/code-words — return correctly (root cause (b), Probe-19.3-F). Both must land for compiled-body banked `CREATE`/`DOES>`/`VARIABLE` to work.
- **Story 19.5.3 — compiled-body verification + bank-N HERE COLD-init (H5).** Re-enable + verify 19.2 AC4/AC5 + 19.3 AC3/DOES> compiled-body probes (remove the `EXECUTE`-explicit reword + the manual `ALLOT`); banked NFR-P4-8 (CATCH-cross-bank) variant.
- **Story 19.5.4 — HW investigation + epic close-out.** Real-MicroBeast intra-bank-into-slot-2 dispatch (first diagnostic: re-run Probe-18.3-A2 with a fixed-memory target to bisect slot-2-specific vs whole-`intra_bank`-path); full three-surface sweep; tag.

**FRs covered:** none new — completes the *behavioural* delivery of FR-P4-15 / FR-P4-16 / FR-P4-24 / FR-P4-25 that Epic 18/19 wired structurally but left blocked.

**NFRs codified:** NFR-P4-1 (Phase-2 envelopes — the DTC rework's hot-path cost is the load-bearing risk), NFR-P4-3 (cross-bank overhead ≤ 60 T-states + MMU), NFR-P4-8 (state integrity after error — banked CATCH variant), NFR-P4-11 (S9 hardware smoke — the Probe-19.2-F gap is the reason this epic exists).

**Standalone:** ✅ After Epic 19.5, compiled-body banked dispatch works end-to-end (the Epic-19 north-star UX, behaviourally). Epics 20–22 do not depend on it for *their* surfaces, but Epic 21 (`ABORT`/`QUIT` cross-bank unwind) benefits from the stabilized trampoline.

**Depends on:** Epic 19 (the bank-aware compiler mechanism whose compiled-body dispatch this epic unblocks).

---

**Epic 19.5 summary:** ADR-first stabilization interlude. 5 provisional stories (19.5.0 ADR spike → 19.5.1 trampoline stabilization → 19.5.2 DTC rework → 19.5.3 compiled-body verification + H5 → 19.5.4 HW + close-out); story shape is finalized BY the ADR. Own binary envelope (~+130–250 B depending on the A/B/C choice; not charged to Epic 19's ~300 B). Discharges all five Epic-19 architectural-debt anchors. Ships its own antforth 3.x point-release on close-out.

---

## Epic 20: Bank-aware FIND + `WORDS` + interpreter-loop attribution

**Goal:** Ship bank-aware lookup as antforth 3.x.4. After Epic 20, `FIND` walks wordlist chains across banks invisibly (the everyday FORTH lookup case incurs no MMU switch because system wordlists are tagged `bank=fixed`); `WORDS` traverses banks per wordlist's `bank` field; lookup-failure error messages name the source bank where appropriate. Epic 20 runs in parallel with Epic 19 once Epic 18 is in (no shared touch points; FIND lives in `src/dictionary.asm`/`src/wordlists.asm`, compiler lives in `src/compiler.asm`/`src/memory.asm`).

**User outcomes at epic close-out:**
- Marc (OG user) defines a word in bank 5; from bank 7 he calls `FIND` (or types the word at the REPL) and the lookup transparently traverses to bank 5's wordlist chain, returns the xt, restores his bank.
- Marc types `WORDS` and the listing covers every wordlist in the current search order across all banks; bank switches are invisible in the output (the user sees a single word list).
- A typo at the REPL produces a `<typo> ?` error that mentions the bank context where appropriate ("`<typo> ?` (looked in bank-5 wordlist FOO)") so Marc can disambiguate "I forgot to switch banks" from "I never defined that word".
- The everyday lookup case (FORTH wordlist resolution) incurs no MMU switch — system wordlists are tagged `bank=fixed` (-1) at kernel build time.
- antforth 3.x.4 is tagged with banner / README / memory-`description` aligned per S11 / NFR-P4-38.

**FRs covered:** FR-P4-27 (per-wordlist `bank` field), FR-P4-28 (FIND traversal), FR-P4-29 (`WORDS` traverses banks), FR-P4-30 (error messages name source bank).

**NFRs codified:** NFR-P4-6 (FIND batch-loading regression envelope ≤ 5–15 %); NFR-P4-12 (ANS Forth 1994 Core compliance — `FIND` continues to comply with §6.1.1550 / §16.6.1.1550 / §6.2.1985 semantics); NFR-P4-31 (S4 AC-composition). All 39 NFR-P4-N continue to hold.

**Architectural inputs:** Epic 17 (banks exist); Epic 18 (cross-bank dispatch so a found word in another bank can actually be executed); independent of Epic 19 (no shared kernel sites).

### Story 20.1: Per-wordlist `bank` field + `FIND` save / switch / walk / restore

As Marc (OG user) looking up a word that may live in any bank,
I want `FIND` to save the current bank, switch to the wordlist's bank only if the wordlist is non-fixed, walk the chain, and restore the saved bank on the way out,
So that lookups transparently traverse banks while the everyday FORTH-wordlist case (and all system wordlists) incurs no MMU switch.

**Acceptance Criteria:**

**Given** Phase-3 close-out has wordlist headers with no `bank` field and `FIND` operating on a single global dictionary state,
**When** Story 20.1 is dev-passed,
**Then** AC1 — `src/wordlists.asm` extends the wordlist-header layout with a `bank` field (per FR-P4-27): the field is a signed byte, with `-1` for fixed-memory marker; system wordlists (FORTH, ASSEMBLER) are tagged `bank = fixed` (-1) at kernel build time (the wordlist-header initialiser sets the field).
**And** AC2 — user wordlists default to the bank they were created in (per FR-P4-27): `WORDLIST` records the value of `BANK@` at creation time into the new wordlist's `bank` field.
**And** AC3 — `src/dictionary.asm`'s `w_FIND_cf` is extended per FR-P4-28: read the search-order's current wordlist's `bank` field; if it is `bank=fixed` or matches `BANK@`, walk the chain without MMU switch (the everyday case); else save `BANK@`, write the wordlist's bank to MMU slot 2, walk the chain, restore the saved bank before returning the result.
**And** AC4 — the FIND extension is implemented for the multi-vocabulary Search-Order code path (per Phase-2 Epic 12); each wordlist in the search order is checked in turn with its own bank context.
**And** AC5 (NFR-P4-6 batch-loading regression envelope) — a benchmark probe times INCLUDE-of-a-large-file against the Phase-3 close-out FIND baseline; assert ≤ 5–15 % regression; result captured in Dev Notes against the envelope.
**And** AC6 (NFR-P4-12 ANS compliance) — `FIND` continues to match ANS §6.1.1550 / §6.2.1985 semantics (no banking-induced semantic drift); the `docs/ans-forth-core-compliance.md` row for `FIND` is updated with a "Phase-4-bank-aware" annotation referencing this story.
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `5 BANK! : W5 100 ; 0 BANK! ' W5 BANK-OF .` returns `5 ok` (FIND traversed to bank 5 via wordlist `bank` field — assumes user wordlists default to creation-bank); (b) `' BANK@` (a fixed-memory word) returns its xt without an MMU switch — verified by a debug probe that captures MMU port writes during the FIND call; (c) lookup of a non-existent word `?WORD?` raises the standard `-13 undefined word` THROW unchanged from Phase-3 behaviour.
**And** AC8 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC7 (a)–(c) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~120 B for this story (per-wordlist `bank` field + FIND traversal extension); tracked against the Epic 20 ~200 B budget per Decision Impact Analysis.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (FORTH-wordlist lookup case unaffected because `bank=fixed` skips the MMU switch); `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-27 (per-wordlist `bank` field), FR-P4-28 (FIND traversal). **NFRs codified:** NFR-P4-6 (FIND batch-loading regression envelope).

### Story 20.2: `WORDS` traverses banks + lookup-failure error messages name source bank

As Marc (OG user) listing words across all wordlists in the search order or seeing a typo error,
I want `WORDS` to list the words across the current search order with bank switches invisible in the output, and lookup-failure error messages to name the source-bank context where appropriate,
So that I get a coherent view of the current dictionary and can disambiguate "forgot to switch banks" from "never defined that word" at typo time.

**Acceptance Criteria:**

**Given** Story 20.1 has shipped (per-wordlist `bank` field + bank-aware `FIND`),
**When** Story 20.2 is dev-passed,
**Then** AC1 — `src/wordlists.asm`'s `w_WORDS_cf` is extended per FR-P4-29: for each wordlist in the current search order, read the wordlist's `bank` field; save current bank; switch only if non-fixed; walk the chain printing names; restore saved bank after each wordlist completes.
**And** AC2 — bank switches are invisible in the `WORDS` output (per FR-P4-29 — the listing is a single flat stream of names; per-bank annotation is explicitly out of MVP scope and is a future option).
**And** AC3 (NFR-P4-6 batch regression envelope) — `WORDS` traversal across N user-bank-resident wordlists incurs ≤ 5–15 % overhead vs Phase-3 baseline (the multi-vocabulary `WORDS` traversal time).
**And** AC4 — `src/dictionary.asm` (or wherever the `<word> ?` error formatter lives) is extended per FR-P4-30: when a FIND failure occurs and the failed lookup walked a non-default-bank wordlist (any wordlist with `bank != BANK@` and `bank != -1`), the error message includes the bank context — e.g., `<typo> ? (looked in bank-5 wordlist FOO)` or a similarly-formatted attribution; if the failed lookup only touched fixed-memory wordlists or the current bank, the error message is unchanged from Phase-3 baseline.
**And** AC5 (CCD-3 source citation) — the WORDS + error-formatter extensions cite `docs/antforth-banking-redesign.md §<n>` per NFR-P4-20.
**And** AC6 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `5 BANK! : W5A ; : W5B ; 0 BANK! WORDS` lists W5A and W5B as part of the listing (assuming the bank-5 user wordlist is in the search order); (b) error-message probe: `5 BANK! WORDLIST CONSTANT FOO FOO >ORDER 0 BANK! TYPO-WORD` produces an error mentioning bank-5 attribution; (c) error-message-no-attribution probe: `0 BANK! TYPO-WORD` produces the standard Phase-3 error message unchanged (no banking context when only fixed/current-bank wordlists were walked).
**And** AC7 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC6 (a)–(c) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC8 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (WORDS extension + error-message attribution); tracked against the Epic 20 budget.
**And** AC9 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (FORTH-only error formatting unchanged for the no-bank-context case); `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-29 (`WORDS` traverses banks), FR-P4-30 (error messages name source bank).

### Story 20.3: Epic 20 close-out + antforth 3.x.4 tag

As Ant (project lead applying the Epic 20 close-out tag),
I want the user-visible version surface aligned (banner / README / memory-`description` all reading `3.x.4`), the full test surface clean across iz-cpm + banking-capable emulator + real MicroBeast, the banked-word stub-count metric updated per CCD-4 close-out, and the verdict-table walk recorded,
So that the bank-aware lookup surface (FIND / WORDS / error attribution) is shipped as antforth 3.x.4 with a clean integration test pass.

**Acceptance Criteria:**

**Given** Stories 20.1 + 20.2 have shipped,
**When** Story 20.3 is dev-passed,
**Then** AC1 (S11 / NFR-P4-38 user-visible version surface audit) — `src/antforth.asm` banner reads `antforth 3.x.4 — N banks available — ok`; `README.md` version reference is updated to `3.x.4`; the Phase-4-scope memory entry's `description` field reads `3.x.4`.
**And** AC2 (verdict-table walk per Story-13.5.6 precedent) — Story 20.3 Dev Notes include a verdict-table walk for all Epic-20 stories: 20.1 PASS / 20.2 PASS / 20.3 PASS with one-line evidence per story.
**And** AC3 (banked-word stub-count metric per CCD-4) — Story 20.3 Dev Notes capture the metric update; trend vs Story 19.4 baseline; assert against NFR-P4-4 × 1000-word target.
**And** AC4 (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no drift.
**And** AC5 (integration probe — the bank-aware-lookup story in one breath) — a single probe in `tests/banking_tests.fth` exercises the full Epic-20 surface: boot with defaults; create user wordlists in three different banks; `>ORDER` all three; `WORDS` produces a unified listing; a typo lookup against a non-current-bank wordlist produces the attributed error message; `' KNOWN-WORD BANK-OF .` from a third bank returns the correct bank index via the bank-aware FIND traversal.
**And** AC6 (full test surface sweep) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports all Epic-17 + 18 + 19 + 20 probes PASS; one full hardware-typed smoke batch covering Epic 20's bank-aware lookup surface PASSes on real MicroBeast per S9 / NFR-P4-11.
**And** AC7 (Epic 20 envelope check) — total Epic-20 binary delta is ≤ ~200 B per Decision Impact Analysis envelope; cumulative `wc -c build/antforth.com` is reported; any over-envelope outcome triggers sprint-change-proposal evaluation per NFR-P4-5.
**And** AC8 (tag applied) — `git tag v3.x.4` is applied to the close-out commit; tag is pushed to GitHub release.

**FRs covered:** none directly (close-out + integration verification). **NFRs codified:** NFR-P4-11 / NFR-P4-36 (S9); NFR-P4-21; NFR-P4-38 (S11); NFR-P4-39 (S12).

---

**Epic 20 summary:** 3 stories. Cumulative binary delta target ≤ ~200 B. Ships antforth 3.x.4. After close-out, the bank-aware lookup surface is observable end-to-end: `FIND` traverses banks invisibly, `WORDS` produces a unified listing, lookup failures name the source bank where appropriate, the everyday FORTH-wordlist lookup case incurs no MMU switch.

---

## Epic 21: `MARKER` / `FORGET` per-bank + `ABORT` / `QUIT` bank-state restore (S5)

**Goal:** Ship the bank-aware lifecycle plumbing as antforth 3.x.5. After Epic 21, `MARKER` and `FORGET` correctly track per-bank dictionary tail across all active banks (including reclaiming descriptor stubs from the fixed-memory stub allocator); `QUIT` re-asserts the saved current bank on re-entry to the outermost interpret loop; an `ABORT` mid-execution inside bank 7 returns the user to the bank they had typed at the REPL, not bank 7.

**User outcomes at epic close-out:**
- Marc (OG user) can place a `MARKER`, define throwaway words across multiple banks, and `FORGET <marker>` correctly restores each bank's `here`/`latest`/wordlist-heads AND reclaims the descriptor-stub allocator tail in fixed memory (per gap-analysis mitigation — the stubs allocated since the MARKER are reclaimed alongside the per-bank dictionary tails).
- Marc raises an `ABORT` (or hits a typo / divides by zero / triggers any THROW) mid-execution inside bank 7; the REPL returns him to bank 0 (his last interactive-`BANK!` choice) rather than stranding him in bank 7.
- An `INCLUDE`d `.FTH` file containing `BANK!` calls does NOT update the saved-bank cell — only top-level interactive `BANK!` does (per the F6 finding: interactive = `STATE @ 0=` AND outer-interpreter-depth = 1).
- antforth 3.x.5 is tagged with banner / README / memory-`description` aligned per S11 / NFR-P4-38.

**FRs covered:** FR-P4-31 (saved current-bank cell), FR-P4-32 (`QUIT` re-asserts saved bank), FR-P4-33 (`ABORT` bank-state).

**NFRs codified:** NFR-P4-7 (REPL survives cross-bank THROW — verified end-to-end via QUIT bank-restore); NFR-P4-8 (state integrity after error — bank-table[] entries not corrupted by mid-execution THROW); NFR-P4-32 (S5 — PARTIAL → HALT). All 39 NFR-P4-N continue to hold.

**Architectural inputs:** Epic 18 (sentinel-trampoline EXIT — uncaught THROW unwind across banks is a recursive trampoline walk per arch §"Coherence"); Epic 19 (per-bank dictionary state must be plumbed for MARKER/FORGET to track per-bank tails); arch finding F6 (interactive-`BANK!` recogniser semantics).

### Story 21.1: `MARKER` / `FORGET` per-bank dictionary tail + descriptor-stub allocator tail reclamation

As Marc (OG user) using `MARKER` to mark a checkpoint and `FORGET` to roll back,
I want `MARKER` to snapshot every active bank's `(here, latest, wordlist-heads)` triple AND the descriptor-stub allocator tail, with `FORGET` reverting both,
So that I can experiment across banks freely without leaking stub-allocator fixed-memory occupancy on rollback.

**Acceptance Criteria:**

**Given** Epic 19 has shipped (per-bank dictionary state plumbed; `:` allocates body in current bank + stub in fixed memory),
**When** Story 21.1 is dev-passed,
**Then** AC1 — `MARKER` is extended (in whichever source file currently houses MARKER, e.g. `src/structures.asm`) to snapshot every active bank's `(here, latest, wordlist-heads)` triple from `bank-table[]` into the MARKER's stored state; snapshot covers all banks present in the active list at MARKER-creation time.
**And** AC2 — `MARKER` additionally snapshots the descriptor-stub allocator tail (the next-free address in the fixed-memory stub region from Story 18.1's allocator); the snapshot is stored alongside the per-bank triples in the MARKER's state.
**And** AC3 — `FORGET` (called via the MARKER's invocation) restores every active bank's triple from the snapshot AND restores the descriptor-stub allocator tail; words defined in any bank since the MARKER are no longer reachable; their stubs are reclaimed (allocator-tail-rollback semantics).
**And** AC4 — if the active bank list changed between MARKER and FORGET (e.g., `+BANK` / `-BANK` was called), the FORGET behaviour for those bank changes is documented in source: bank-list changes are NOT rolled back by FORGET (FORGET only touches dictionary tails + stub allocator); the user-doc gotcha lands in Epic 22 polish.
**And** AC5 (gap-analysis mitigation per arch §"Gap Analysis") — the source comment explicitly references the architecture's gap-analysis note: "MARKER stores both tails — per-bank dictionary tail AND stub-allocator tail — and FORGET reverts both."
**And** AC6 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `MARKER ZZZ 5 BANK! : W5 1 ; 7 BANK! : W7 2 ; 0 BANK! ZZZ ' W5` raises `<W5> ? (looked in bank-5 …)` (W5 is forgotten); same for W7; (b) `MARKER ZZZ : FOO ;` then `ZZZ` is invoked; `' FOO` raises undefined-word; subsequent definitions allocate stubs from the reclaimed allocator-tail region (verified via stub-count probe — count drops back to pre-MARKER level); (c) cross-bank-MARKER survival: MARKER set in bank 5, defined word added in bank 7, FORGET via the bank-5 marker correctly reclaims bank-7's tail.
**And** AC7 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC6 (a)–(c) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC8 (CCD-3 source citation) — MARKER/FORGET extension cites `docs/antforth-banking-redesign.md §<n>` + the arch §"Gap Analysis" stub-reclamation note.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (per-bank snapshot storage + restore loop + allocator-tail snapshot/restore); tracked against the Epic 21 ~150 B budget per Decision Impact Analysis.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (single-bank MARKER/FORGET semantics preserved exactly for the bank-0 case); `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-40 (MARKER/FORGET correctness preserved across banks — via the Phase-1+2+3 functional-preservation umbrella; pre-Phase-4 MARKER/FORGET semantics continue to hold under the banked build). None of FR-P4-31..33 directly (those three are the saved-bank / QUIT / ABORT arm of Epic 21, owned by Story 21.2). **NFR codified:** NFR-P4-8 (bank-table[] state integrity after MARKER+FORGET cycles).

### Story 21.2: Saved-bank cell + interactive-`BANK!` recogniser + `QUIT` re-asserts saved bank + `ABORT` / `ABORT"` pass-through

As Marc (OG user) confident that `ABORT` mid-execution returns me to the bank I had typed at the REPL,
I want the kernel to track a "saved current bank" updated only by interactive `BANK!` from the outermost interpret loop, and `QUIT` to re-assert that bank on re-entry,
So that an `ABORT` inside a colon definition or inside an `INCLUDE`d file does not strand me in a wrong bank; and `INCLUDE`d `.FTH` files' `BANK!` calls do NOT pollute the saved-bank cell (F6 mitigation).

**Acceptance Criteria:**

**Given** Stories 17.1 (saved-bank UserArea cell already wired), 18.2 (sentinel-trampoline EXIT for cross-bank THROW unwind), and 19.1 (per-bank dictionary state) have shipped,
**When** Story 21.2 is dev-passed,
**Then** AC1 — `src/outer_interpreter.asm`'s top-level `BANK!` recogniser is extended to update the saved-bank UserArea cell ONLY when `BANK!` is invoked from interactive context (per FR-P4-31).
**And** AC2 (F6 mitigation — interactive recogniser semantics) — "interactive `BANK!`" is defined as: `STATE @ 0=` (interpret state) AND outer-interpreter-depth = 1 (not inside an `INCLUDE`d source frame per CCD-1's INCLUDE-TOP chain depth check). The depth check uses the existing INCLUDE-TOP chain from Phase-2 Epic 13 (no new mechanism required).
**And** AC3 — `src/outer_interpreter.asm`'s `w_QUIT_cf` is extended per FR-P4-32: on re-entry to the outermost interpret loop, read the saved-bank cell; if non-default, write the corresponding physical page to the MMU port for slot 2 and update `current-bank`; `IN-BANK`'s save/restore mechanism (FR-P4-4) is independent of this — `IN-BANK` operates within nested execution; this AC governs the outermost loop only.
**And** AC4 — `src/system.asm`'s `w_ABORT_cf` and `w_ABORT_QUOTE_cf` are verified per FR-P4-33: they unwind the data stack and return stack and re-enter `QUIT`, which then re-asserts the saved current bank per AC3. The unwind path leaves the saved-bank cell intact (the cell is in UserArea, not on the return stack).
**And** AC5 — uncaught-THROW unwind across cross-bank frames: a probe raises an uncaught THROW from inside a colon definition running in bank 7; the THROW unwind walks recursive `cross_bank_return` trampolines via Epic 18.2's mechanism, then `.throw_uncaught` re-enters `QUIT`, which re-asserts the user's last interactive bank. Verified end-to-end with the REPL prompt restoration.
**And** AC6 (REPL probes — `tests/banking_tests.fth`) — probes: (a) interactive REPL `5 BANK! ABORT`: REPL recovers, `BANK@ .` returns `5 ok`; (b) colon-defined `7 BANK!` inside an executing word followed by THROW: `BANK@ .` returns the pre-execution bank, not 7; (c) F6 verification — an `INCLUDE`d file `STARTUP.FTH-equivalent.fth` contains `5 BANK! : SOMETHING ;`; after `INCLUDE` completes, the saved-bank cell is unchanged from before the INCLUDE call; (d) hardware-mode interactive: type `7 BANK!` then trigger an asm-error THROW (-258..-272) from inside a banked CODE word; REPL recovers, `BANK@ .` returns `7 ok` (interactive `BANK!` to 7 IS reflected in the saved cell; the THROW unwind preserves it).
**And** AC7 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator; one hardware-typed probe batch covering AC6 (a)–(d) runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC8 (CCD-3 source citation) — `src/outer_interpreter.asm` and `src/system.asm` extensions cite `docs/antforth-banking-redesign.md §5.6` per NFR-P4-20; the F6 mitigation note cites the architecture's Findings F6 row.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~70 B for this story (interactive recogniser + QUIT bank-restore + ABORT pass-through verification); tracked against the Epic 21 budget.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (single-bank ABORT/QUIT semantics preserved exactly — the bank-0 case is the original Phase-3 behaviour); `make test-repl-banking` reports new probes PASS including the F6 INCLUDE-doesn't-pollute probe.

**FRs covered:** FR-P4-31 (saved current-bank cell), FR-P4-32 (QUIT re-asserts saved bank), FR-P4-33 (ABORT bank-state). **NFRs codified:** NFR-P4-7 (cross-bank THROW survivability — verified end-to-end); NFR-P4-8 (bank-table[] state integrity after mid-execution THROW). **Findings closed:** F6 (saved-bank-cell "interactive only" semantics verified by AC6 (c)).

### Story 21.3: Epic 21 close-out + antforth 3.x.5 tag

As Ant (project lead applying the Epic 21 close-out tag),
I want the user-visible version surface aligned (banner / README / memory-`description` all reading `3.x.5`), the full test surface clean across iz-cpm + banking-capable emulator + real MicroBeast, the banked-word stub-count metric updated per CCD-4 close-out, and the verdict-table walk recorded,
So that the bank-aware lifecycle surface (MARKER/FORGET per-bank + saved-bank restore on QUIT/ABORT) is shipped as antforth 3.x.5 with a clean integration test pass.

**Acceptance Criteria:**

**Given** Stories 21.1 + 21.2 have shipped,
**When** Story 21.3 is dev-passed,
**Then** AC1 (S11 / NFR-P4-38 user-visible version surface audit) — `src/antforth.asm` banner reads `antforth 3.x.5 — N banks available — ok`; `README.md` version reference is updated to `3.x.5`; the Phase-4-scope memory entry's `description` field reads `3.x.5`.
**And** AC2 (verdict-table walk per Story-13.5.6 precedent) — Story 21.3 Dev Notes include a verdict-table walk for all Epic-21 stories: 21.1 PASS / 21.2 PASS / 21.3 PASS with one-line evidence per story.
**And** AC3 (banked-word stub-count metric per CCD-4 + F2 mitigation) — Story 21.3 Dev Notes capture: cumulative stub-count after Epic 21; total descriptor-stub fixed-memory occupancy; assert against NFR-P4-4 × 1000-word target; note specifically that MARKER/FORGET cycle test exercised allocator-tail reclamation (Story 21.1 AC6 (b)).
**And** AC4 (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no drift.
**And** AC5 (integration probe — the lifecycle story in one breath) — a single probe in `tests/banking_tests.fth` exercises the full Epic-21 surface: `MARKER ZZZ 5 BANK! : W5 ; 7 BANK! : W7 ; 7 BANK! W5 ABORT` (an ABORT in bank 7 after a cross-bank call to W5); REPL recovery confirms `BANK@ .` returns the original interactive bank; `ZZZ` restores all per-bank dictionary tails and reclaims stubs; subsequent definitions resume cleanly.
**And** AC6 (full test surface sweep) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports all Epic-17 + 18 + 19 + 20 + 21 probes PASS under the banking-capable emulator; one full hardware-typed smoke batch covering Epic 21's lifecycle surface PASSes on real MicroBeast per S9 / NFR-P4-11.
**And** AC7 (Epic 21 envelope check) — total Epic-21 binary delta is ≤ ~150 B per Decision Impact Analysis envelope; cumulative `wc -c build/antforth.com` is reported; any over-envelope outcome triggers sprint-change-proposal evaluation per NFR-P4-5.
**And** AC8 (tag applied) — `git tag v3.x.5` is applied to the close-out commit; tag is pushed to GitHub release.

**FRs covered:** none directly (close-out + integration verification). **NFRs codified:** NFR-P4-11 / NFR-P4-36 (S9); NFR-P4-21; NFR-P4-38 (S11); NFR-P4-39 (S12).

---

**Epic 21 summary:** 3 stories. Cumulative binary delta target ≤ ~150 B. Ships antforth 3.x.5. After close-out, the bank-aware lifecycle surface is observable end-to-end: MARKER/FORGET correctly snapshots and reverts per-bank dictionary tails AND the stub-allocator tail; QUIT re-asserts the saved current bank on ABORT/THROW unwind; `INCLUDE`d files' `BANK!` calls do NOT pollute the saved-bank cell (F6 closed). After Epic 21, the user can never be stranded in the wrong bank after an interactive `ABORT`.

---

## Epic 22: Polish + Phase-4 close-out

**Goal:** Ship the Phase-4 close-out as antforth 3.x.6 (the final Phase-4 antforth 3.x point-release; exact final-version selection deferred to close-out time per project-lead direction). After Epic 22, `.BANKS` is final-formatted; the REPL prompt optionally shows the current bank; the cross-bank CODE-words disposition (per Story 16.4 §9.1 closure) is implemented; the F4 cross-bank-pointer-hazard user-docs entry exists; the three-test-surface harness sweep is clean across iz-cpm + banking-capable emulator + real MicroBeast; the verdict-table walk closes Phase 4.

**User outcomes at epic close-out:**
- Marc (OG user) calls `.BANKS` and sees a polished, well-aligned status table (no column-stability surprises; per-bank used/free reflects real `here` values now that Epic 19's per-bank state is live).
- Marc's REPL prompt optionally reads `[5] ok` (or similar) showing his current bank (the F4 bank-pointer-hazard implication is visible in the prompt — he can't accidentally type into the wrong bank without seeing it).
- Marc consults the user-docs entry "Cross-bank pointer hazards" and finds an example anti-pattern + the recommendation "do all your work in one bank per logical session, swap banks at well-defined boundaries" (F4 closed).
- The cross-bank CODE-words disposition is implemented per Story 16.4's §9.1 closure (whichever direction was chosen — yes-with-rule / no-fixed-only / Phase-5+ deferral).
- Phase 4 closes: the full antforth 3.x close-out tag is applied with the Phase-3 974-test baseline + new Phase-4 banking probes all clean across all three test surfaces; the verdict-table walk records every Epic-16..22 close-out.
- The Phase-4 retrospective is captured per Phase-3 precedent (one retrospective per epic at each close-out + one Phase-4 retrospective at the end).

**FRs covered:** FR-P4-6 (`.BANKS` final), FR-P4-42 (CODE-word source backward compat — cross-bank CODE-word disposition implemented). Phase-wide constraints FR-P4-40 (Phase-1+2+3 functional preserved), FR-P4-41 (974-PASS test baseline), FR-P4-43 (`BANK*` wordset additive) all verified at close-out.

**NFRs codified:** NFR-P4-4 (per-stub size — final cumulative measurement); NFR-P4-5 (banking infrastructure ≤ 8 KB cap — final cumulative measurement); NFR-P4-19 (test-first discipline — banking dual-track verified clean across all three surfaces); NFR-P4-21 (epic-level decoupling — antforth 3.x.6 final tag); NFR-P4-38 (S11). All 39 NFR-P4-N continue to hold.

**Architectural inputs:** Story 16.4 §9.1 (cross-bank CODE-words disposition); arch findings F2 (stub-cost growth — final measurement) + F4 (cross-bank pointer hazard user-docs entry).

### Story 22.1: `.BANKS` final formatting polish + per-bank used / free reflect real `here` values

As Marc (OG user) inspecting bank state with `.BANKS`,
I want a polished status table — column-stable, well-aligned, with per-bank used/free reflecting real `here` values now that Epic 19's per-bank state is live,
So that `.BANKS` is the canonical observability tool for banking — not a placeholder.

**Acceptance Criteria:**

**Given** Story 17.5 shipped `.BANKS` in minimal/working form (zero-used/full-free placeholders) and Epic 19 has made per-bank `HERE` real,
**When** Story 22.1 is dev-passed,
**Then** AC1 — `.BANKS` is updated in `src/banking.asm` per FR-P4-6 final form: per-bank used / free now reflect real `here` values from `bank-table[]` (used = `here - bank-base-address`; free = `bank-size - used`).
**And** AC2 — column widths are stable across all rows; numeric values right-align; current-bank marker (`*`) is left-aligned in its own column; total output fits in 80-column CP/M console (no wrap).
**And** AC3 — totals row at bottom sums per-bank used / free across all active banks; banked-word count + descriptor-stub fixed-memory occupancy are added as additional summary rows for CCD-4 metric visibility (per F2 mitigation).
**And** AC4 — `.BANKS` source comment removes the "Epic 17 minimal form" annotation; replaces with `; Phase-4 final form — see Story 22.1`.
**And** AC5 (REPL probes — `tests/banking_tests.fth`) — probes: (a) update Story 17.5's `.BANKS` probe to assert real per-bank used / free values after `5 BANK! : SOME-WORD ;` (used in bank 5 increases by the body byte-count); (b) totals row matches sum of per-row used / free; (c) banked-word count row matches `BANKS` × stub count.
**And** AC6 (probe surfaces + hardware smoke) — probes pass under banking-capable emulator; one hardware-typed `.BANKS` probe runs on real MicroBeast and visually inspects for column-stability + readability per S9 / NFR-P4-11.
**And** AC7 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~50 B for this story (formatting refinement + summary rows); tracked against the Epic 22 ~100 B budget per Decision Impact Analysis.
**And** AC8 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm; `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-6 (final form).

### Story 22.2: REPL prompt indicator (current-bank visibility) + F4 cross-bank-pointer-hazard user-docs entry

As Marc (OG user) wanting to see the current bank in my REPL prompt and consult a user-docs entry on cross-bank pointer hazards,
I want the REPL prompt optionally extended to show `[N] ok` where N is the current bank (suppressed if the user has not banked or is in bank 0), and a user-docs entry titled "Cross-bank pointer hazards" naming HERE / LATEST / wordlist-head / data-cell pointers as bank-sensitive,
So that I have visible feedback on the current bank during REPL work, and I can consult a single canonical anti-pattern reference when I write my first multi-bank application.

**Acceptance Criteria:**

**Given** Epic 21 has shipped (saved-bank cell + QUIT bank-restore working),
**When** Story 22.2 is dev-passed,
**Then** AC1 (REPL prompt indicator) — `src/outer_interpreter.asm`'s prompt-print logic is extended to optionally include the current-bank indicator: if `BANK@ != 0`, the prompt reads `[N] ok ` (where N is the logical bank index); if `BANK@ == 0`, the prompt is unchanged from Phase-3 (`ok `). The change is opt-in via a kernel-level flag word (e.g., `PROMPT-SHOW-BANK ON` / `OFF`) so users who prefer the Phase-3 prompt can disable; default disposition is captured per project-lead direction at story-draft time (likely OFF by default to preserve the Phase-3 visual baseline; per F4 mitigation, the user-docs entry recommends enabling for multi-bank work).
**And** AC2 (F4 mitigation — user-docs entry) — a `docs/banking-pointer-hazards.md` (or equivalent location — `docs/users-guide-banking.md` / `docs/banking-gotchas.md`; exact filename captured in story Dev Notes) is created with:
  - Title: "Cross-bank pointer hazards"
  - The pointers that are bank-sensitive: `HERE` / `LATEST` per FR-P4-26; data-cell PFA addresses from `CREATE` per FR-P4-25; raw allocator pointers; wordlist-head pointers held outside FIND.
  - Example anti-pattern: code that captures `HERE` in bank 5, switches to bank 7, writes via the captured pointer (writes garbage into bank 7's address space at bank 5's `here` offset).
  - Recommendation: "do all your work in one bank per logical session, swap banks at well-defined boundaries" (the redesign-doc's locked guidance per §5.4).
  - Cross-reference to `PROMPT-SHOW-BANK ON` for visual feedback.
**And** AC3 — the user-docs entry is linked from `README.md` (under a "Banking" section heading).
**And** AC4 (CCD-3 source citation) — the prompt-extension source comment cites the F4 mitigation + the user-docs file; the user-docs file's first paragraph cites `docs/antforth-banking-redesign.md §5.4`.
**And** AC5 (REPL probes — `tests/banking_tests.fth`) — probes: (a) `PROMPT-SHOW-BANK ON 5 BANK! .S` verifies the prompt shows `[5] ok`; (b) `0 BANK!` returns prompt to the no-bracket form (or `[0]` if the design disposition prefers always-show — captured at story draft time); (c) `PROMPT-SHOW-BANK OFF 5 BANK!` keeps the bare `ok` prompt.
**And** AC6 (hardware smoke) — one hardware-typed probe verifies the prompt format on real MicroBeast under each `PROMPT-SHOW-BANK` setting per S9 / NFR-P4-11.
**And** AC7 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~30 B for this story (prompt extension + flag word); tracked against the Epic 22 budget.
**And** AC8 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (default-OFF preserves Phase-3 prompt format exactly); `make test-repl-banking` reports new probes PASS; `make check-doc-sync` reports clean-pass with the new user-docs file recognised.

**FRs covered:** none directly (UX polish + F4 user-docs entry). **Findings closed:** F4 (cross-bank pointer hazard documented in user-docs).

### Story 22.3: Cross-bank CODE-words disposition implementation (per Story 16.4 §9.1 closure)

As Marc (OG user / Pete the hardware-peripheral developer) needing CODE words to follow the bank-aware dispatch chain,
I want the cross-bank CODE-words disposition implemented per the architecture decision recorded by Story 16.4 §9.1 closure,
So that user CODE-words behaviour matches the documented contract — whether that's "yes, banks can host CODE words" / "no, CODE words must live in fixed memory" / "deferred to Phase 5+ with explicit fallback".

**Acceptance Criteria:**

**Given** Story 16.4 §9.1 closed with a binding architecture decision on cross-bank CODE-words,
**When** Story 22.3 is dev-passed,
**Then** AC1 — the architecture decision is read from `architecture.md`'s §9.1 closure entry; the AC text below inherits the chosen disposition verbatim (acceptable outcomes: yes-with-rule / no-fixed-only / Phase-5+-deferred-with-fallback).
**And** AC2 (if disposition is "yes — banks can host CODE words with the following dispatch rule") — `src/compiler.asm`'s `w_CODE_cf` (the Phase-1/2 word-creator for CODE words) is extended: if the user is in a non-zero bank, the CODE body lands in the current bank's data space + a descriptor stub is allocated in fixed memory pointing at the body; `EXECUTE` of a banked CODE word goes through the standard Story-18.3 stub-dispatch path (no special-casing). FR-P4-42 byte-identical CODE-source compat is preserved for fixed-memory CODE words.
**And** AC3 (if disposition is "no — CODE words must live in fixed memory") — `src/compiler.asm`'s `w_CODE_cf` is extended to raise `ABORT" code?"` (or equivalent — exact spelling per architecture-decision text) if invoked from a non-zero bank; the source comment documents the rejection rationale.
**And** AC4 (if disposition is "Phase-5+ deferred with fallback") — Phase-4 leaves `w_CODE_cf` untouched (CODE words land in fixed memory regardless of which bank the user is in — the equivalent of forcing bank 0 for CODE definitions); a one-line user-docs entry documents the Phase-4 limitation; a `TODO(P5)` marker is added to the source.
**And** AC5 (FR-P4-42 byte-identical compat) — regardless of disposition, all existing pre-Phase-4 CODE-word source files assemble correctly under the banked build and produce byte-identical output when compiled into fixed memory (the same memory region they always landed in); a verification probe asserts this against the Phase-3 close-out CODE-word-source corpus.
**And** AC6 (CCD-3 source citation) — the disposition implementation cites `architecture.md` §9.1 closure verbatim per NFR-P4-20.
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — probes per disposition: (a) yes-with-rule — `5 BANK! CODE FOO ... END-CODE 0 BANK! FOO` exercises a cross-bank CODE word; (b) no-fixed-only — `5 BANK! CODE FOO` raises the abort message; (c) Phase-5+-deferred — `5 BANK! CODE FOO ... END-CODE` defines into fixed memory regardless of `BANK@` (verified by `' FOO BANK-OF .` returning `-1`).
**And** AC8 (probe surfaces + hardware smoke) — probes pass under banking-capable emulator; one hardware-typed probe batch covering AC7 runs on real MicroBeast per S9 / NFR-P4-11.
**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~50 B for this story (envelope depends on disposition: yes-with-rule is the largest at ~50 B; no-fixed-only is ~20 B; Phase-5+-deferred is ~10 B for the TODO comment); tracked against the Epic 22 budget.
**And** AC10 — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (existing CODE-word behaviour for the bank-0 / fixed-memory path is preserved exactly per AC5); `make test-repl-banking` reports new probes PASS.

**FRs covered:** FR-P4-42 (CODE-word source backward compat — cross-bank CODE-word disposition implemented). **Architectural input consumed:** Story 16.4 §9.1 (cross-bank CODE-words disposition).

### Story 22.4: Phase-4 close-out — three-test-surface sweep + verdict-table walk + antforth 3.x.6 (final) tag + Phase-4 retrospective

As Ant (project lead applying the Phase-4 close-out tag),
I want the full three-test-surface harness sweep clean across iz-cpm + banking-capable emulator + real MicroBeast, the cumulative binding-infrastructure measurements final-recorded against NFR-P4-4 / NFR-P4-5 envelopes, the verdict-table walk recording every Epic-16..22 close-out, and the Phase-4 retrospective captured per Phase-3 precedent,
So that Phase 4 closes cleanly with the antforth 3.x.6 (final) tag — the first feature phase since v2.0, the banked-RAM enablement promise delivered.

**Acceptance Criteria:**

**Given** Stories 22.1 + 22.2 + 22.3 have shipped, AND Epics 16–21 have all shipped (every close-out tag through 3.x.5 is applied),
**When** Story 22.4 is dev-passed,
**Then** AC1 (S11 / NFR-P4-38 user-visible version surface audit — final) — `src/antforth.asm` banner reads `antforth 3.x.6 — N banks available — ok` (or whichever final 3.x version is selected at close-out per project-lead direction; the version string is the Phase-4 close-out tag); `README.md` version reference is updated to match; the Phase-4-scope memory entry's `description` field reads the same.
**And** AC2 (verdict-table walk — full Phase 4) — Story 22.4 Dev Notes include a verdict-table walk for every Phase-4 story across all 7 epics: 16.1..16.4 / 17.1..17.6 / 18.1..18.5 / 19.1..19.4 / 20.1..20.3 / 21.1..21.3 / 22.1..22.4 — all PASS with one-line evidence per story.
**And** AC3 (cumulative banking-infrastructure measurement — F2 mitigation final) — final measurements captured: total banked-word count; total descriptor-stub fixed-memory occupancy; total banking-infrastructure fixed-memory occupancy (allocator + bank-table[] + trampoline + CL parser + 12 wordset-word bodies); all reported against NFR-P4-4 (≤ 5 KB at 1000-word target) and NFR-P4-5 (≤ 8 KB at 28-bank cap; ~6 KB at default 12 banks).
**And** AC4 (cumulative cross-bank dispatch latency — NFR-P4-2 / NFR-P4-3 final) — final benchmark probe confirms: `BANK!` ≤ 60 T-states + MMU port-write; cross-bank call ≤ 60 T-states + bank-switch; intra-bank call adds exactly one `JP` overhead vs flat per FR-P4-15.
**And** AC5 (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no drift between PRD, architecture, this epics document, banner, README, memory-`description` fields, and the user-docs entry from Story 22.2.
**And** AC6 (full three-test-surface sweep) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (Phase-3 close-out baseline preserved per FR-P4-41); `make test-repl-banking` reports the full Phase-4 banking probe corpus PASS under the banking-capable emulator (Epic 17 + 18 + 19 + 20 + 21 + 22 probes); one full hardware-typed smoke batch covering the entire Phase-4 user-facing surface (12 `BANK*` words + cross-bank `:` + cross-bank `EXECUTE` + cross-bank THROW + ABORT-bank-restore + .BANKS + REPL prompt indicator + cross-bank CODE per disposition) PASSes on real MicroBeast per S9 / NFR-P4-11 / NFR-P4-39.
**And** AC7 (Epic 22 envelope check — final) — total Epic-22 binary delta is ≤ ~100 B per Decision Impact Analysis envelope; cumulative `wc -c build/antforth.com` from Phase-3 close-out (24,995 bytes) is reported alongside the Phase-4 cumulative total; total Phase-4 banking-infrastructure delta against NFR-P4-5's ~6 KB at default 12 banks envelope is final-reported.
**And** AC8 (Phase-4 retrospective per Phase-3 precedent) — `_bmad-output/implementation-artifacts/phase-4-retro-<date>.md` is created following the Phase-3 epic-retro template (extracted lessons + standing-commitment hold check + open carry-forward items + final stub-count metric + final byte budget); per-epic retros for Epics 16–22 also created at each epic close-out (each epic's retro lands at its own Story-N.last close-out, not bundled into Story 22.4).
**And** AC9 (carry-forward catalogue — Phase-5+ inputs) — Phase-5+ candidates explicitly enumerated in the Phase-4 retro: multitasking (bank=1byte-of-TCB), locals wordset, ALLOCATE/per-bank heap (β), MicroBeast hardware vocabulary (E.1), SEE decompiler (E.4), TRAVERSE-WORDLIST (E.5), Z80 IN/OUT primitives (E.7), compilation to standalone .com binary (E.8), flat-build retention (deferred from Phase 4 MVP per redesign §4); each item carries a one-line "why deferred" entry per `docs/WISHLIST.md` cross-reference.
**And** AC10 (final tag applied) — `git tag v3.x.6` (or final-selected version) is applied to the close-out commit; tag is pushed to GitHub release; the Phase-4 close-out is announced per project tradition; Phase 4 ENDS.

**FRs covered:** FR-P4-40 (Phase-1+2+3 functional preserved — verified at full-sweep), FR-P4-41 (974-PASS test baseline — verified at full-sweep), FR-P4-43 (`BANK*` wordset additive — verified at full-sweep). **NFRs codified:** NFR-P4-4 (per-stub size — final cumulative); NFR-P4-5 (banking infra ≤ 8 KB — final cumulative); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic-level decoupling — antforth 3.x.6 final); NFR-P4-38 (S11); NFR-P4-39 (S12). **Findings final-closed:** F2 (stub-cost growth — final measurement against envelope).

---

**Epic 22 summary:** 4 stories. Cumulative binary delta target ≤ ~100 B. Ships antforth 3.x.6 (final Phase-4 tag — exact version selected at close-out). After close-out, Phase 4 ENDS with the banked-RAM enablement promise delivered: ~25 KB binary ceiling lifted, compiler-transparent banking shipped, full Phase-3 974-test baseline + new Phase-4 banking probes clean across all three test surfaces, all 6 redesign-doc open questions and all 6 architecture findings (F1–F6) closed, every standing commitment S1–S12 verified hold across Phase 4. **Phase 5+ unblocked.**
