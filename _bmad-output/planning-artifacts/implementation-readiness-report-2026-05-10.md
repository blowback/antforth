---
workflow: check-implementation-readiness
date: 2026-05-10
project: antforth
scope: Phase 4 entry — Epics 16–22
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
readinessVerdict: READY (with minor remediation recommended; non-blocking)
qualityFindings:
  critical: 0
  major: 3
  minor: 5
coverageStats:
  totalFRs: 43
  coveredFRs: 43
  coveragePct: 100
  totalNFRs: 39
  enforcedNFRs: 39
  totalStories: 28
  cumulativeBinaryEnvelopeBytes: 1550
prdMetrics:
  totalFRs: 43
  totalNFRs: 39
  capabilityGroups: 7
  regressionUmbrellaFRs: 4
  openQuestions: 5
documentsInScope:
  prd: prd.md
  architecture: architecture.md
  epics: epics-phase4-epics-16-22.md
  ux: N/A (kernel/CLI project — no UX layer)
referenceDocuments:
  - prd-phase3-epics-14-15.md
  - architecture-phase3-epics-14-15.md
  - epics-phase3-epics-14-15.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-05-10
**Project:** antforth

## Step 1 — Document Discovery

### Documents in Scope

| Type | File | Size | Modified |
|------|------|------|----------|
| PRD | `prd.md` | 90.7 KB | 2026-05-10 |
| Architecture | `architecture.md` | 96.8 KB | 2026-05-10 |
| Epics & Stories | `epics-phase4-epics-16-22.md` | 157.4 KB | 2026-05-10 |
| UX | N/A | — | kernel/CLI project, no UX deliverable |

### Reference / Historical Documents (Not Assessed Directly)

- `prd-phase{1,2,3}-*.md` — phase archives
- `architecture-phase{1,2,3}-*.md` — phase archives
- `epics-phase{1,2,3}-*.md` — phase archives
- `epic{6,7,8}-*.md` — phase-1-era spike specs

### Issues Identified

- No format duplicates (no shard/whole conflicts).
- UX absent by design — confirmed N/A.
- Phase-4 epics file is new (untracked in git as of this run).

### Resolution

Assessment will evaluate **Phase 4 implementation readiness (Epics 16–22)** against the consolidated `prd.md` and `architecture.md`, with phase-3 docs as carry-forward reference where Phase 4 stories explicitly inherit context.

## Step 2 — PRD Analysis

### Document Read

- **File:** `prd.md` (651 lines, modified 2026-05-10)
- **Scope:** Phase 4 — banked-RAM enablement (Epics 16–22, antforth 3.x)
- **Architectural anchor:** `docs/antforth-banking-redesign.md` (locked 2026-05-09)

### Functional Requirements Extracted

Phase-4 FRs use the `FR-P4-N` prefix. Total: **43 FRs** across 7 capability groups, plus 4 regression-umbrella FRs (40–43).

#### Banking Wordset (12 words)

- **FR-P4-1 (`BANK@`):** `( -- n )` returns current logical bank index. Available at REPL and inside colon defs.
- **FR-P4-2 (`BANK!`):** `( n -- )` switches current logical bank; swaps `(here, latest, wordlist-heads)` triple; `ABORT" bank?"` on unknown bank.
- **FR-P4-3 (`BANKS`):** `( -- n )` returns count of active banks; VALUE updated by `+BANK`/`-BANK`/`BANKS-CLEAR`.
- **FR-P4-4 (`IN-BANK`):** `( n xt -- )` saves current bank, switches, executes `xt`, restores. Kernel-blessed. CATCH-safe via standard `>R/R>`.
- **FR-P4-5 (`BANK-OF`):** `( xt -- n )` returns bank of word; `-1` for fixed memory. One-byte read from descriptor stub.
- **FR-P4-6 (`.BANKS`):** `( -- )` prints status table (index, page, marker, used/free, totals).
- **FR-P4-7 (`+BANK`):** `( page -- )` adds physical page; probe-on-add (write/read/restore); `ABORT" probe?"` on failure.
- **FR-P4-8 (`-BANK`):** `( page -- )` removes page; no-op if absent (no THROW).
- **FR-P4-9 (`BANKS-CLEAR`):** `( -- )` empties active list; subsequent `BANK!` ABORTs.
- **FR-P4-10 (`SET-BANK`):** `( page slot -- )` raw MMU port write; diagnostics only; no validation.
- **FR-P4-11 (`BANK-MAPPING-ON`):** `( -- )` enables MMU mapping. Auto-run in `COLD`.
- **FR-P4-12 (`BANK-MAPPING-OFF`):** `( -- )` disables MMU mapping. For CP/M warm-boot escape.

#### Cross-Bank Dispatch (descriptor-stub mechanism)

- **FR-P4-13:** Every banked word gets a 3–5-byte descriptor stub in fixed memory carrying `(target_bank, target_addr_in_bank)`. **Stub address IS the xt.** Fixed-memory words use `target_bank = -1`.
- **FR-P4-14:** `COMPILE,` always emits the stub address; no same-bank vs cross-bank distinction at compile time.
- **FR-P4-15:** Intra-bank dispatch = stub + 1 extra `JP` vs flat; no MMU port write.
- **FR-P4-16:** Cross-bank dispatch ≤ 60 T-states + MMU port-write time.
- **FR-P4-17:** xt is portable — stable across `BANK!`; passable on data stack across banks unmodified.

#### Cross-Bank EXIT (sentinel-trampoline)

- **FR-P4-18:** Cross-bank call pushes 3-cell return frame `(sentinel_addr, caller_bank, target_addr)` on R-stack; sentinel = address of `cross_bank_return` trampoline.
- **FR-P4-19:** Intra-bank call pushes 1 cell (standard ANS frame); only 1 sentinel compare overhead in `EXIT`.
- **FR-P4-20:** `cross_bank_return` trampoline lives in fixed memory; restores caller's bank and jumps to target_addr.
- **FR-P4-21:** Recursive cross-bank R-stack overflow raises standard `-5 RETURN-STACK-OVERFLOW`. `TODO(P4-resolve)` for documented-gotcha-vs-runtime-guard decision in architecture stage.

#### Bank-Aware Compiler

- **FR-P4-22:** Per-bank `(here, latest, wordlist-heads)` triples in fixed-memory `bank-table[]`; atomic swap on `BANK!`.
- **FR-P4-23:** `,` and `COMPILE,` write into current bank's `here`. Cross-bank `,` not exposed.
- **FR-P4-24:** `:` allocates body in current bank, descriptor stub in fixed memory, links into current `latest`. After `;`, xt = stub address.
- **FR-P4-25:** `CREATE`/`DOES>` cross-bank explicit; PFA stores doer-stub addr + data cell; compiler does not auto-redirect across banks.
- **FR-P4-26:** `HERE`/`LATEST` per-bank. Cross-bank pointer hazards are documented gotchas; no runtime guard (doc-and-pray per redesign doc §5.4).

#### Bank-Aware FIND

- **FR-P4-27:** Per-wordlist `bank` field. System wordlists (FORTH, ASSEMBLER) tagged `bank = -1` (fixed).
- **FR-P4-28:** `FIND` saves/switches/walks/restores bank. `bank = fixed` words incur no MMU switch.
- **FR-P4-29:** `WORDS` traverses banks per wordlist `bank` field; switches invisible in default output.
- **FR-P4-30:** Lookup-failure error messages name the source bank when wordlist has non-default `bank`.

#### ABORT/QUIT Bank-State Restore

- **FR-P4-31:** Outermost interactive `BANK!` updates kernel-internal "saved current bank" cell.
- **FR-P4-32:** `QUIT` re-asserts saved bank on re-entry to outermost interpret loop. `IN-BANK` semantics are independent (nested).
- **FR-P4-33:** `ABORT`/`ABORT"` unwinds stacks and re-enters `QUIT`, which restores saved bank.

#### Boot Configuration

- **FR-P4-34:** CL parser accepts `antforth <portal-page> <bank-list>` (e.g. `antforth 24 35-3f`).
- **FR-P4-35:** Default applied absent CL tail: `22 35-3F`.
- **FR-P4-36:** Probe-on-add during CL parsing; bad pages produce one-line warning and exclusion; parsing does not abort on single bad page.
- **FR-P4-37:** Boot banner shows active-bank count (e.g. `antforth 3.x — 12 banks available — ok`).
- **FR-P4-38:** `STARTUP.FTH` is NOT the boot-config mechanism (deliberate design rejection — bank availability needed at banner-print time).
- **FR-P4-39:** Default = 12 banks × 16 KB = 192 KB; max = 29 banks × 16 KB = 464 KB (trades VC buffer + RAM disk).

#### Backward Compatibility & Regression (phase-wide constraint)

- **FR-P4-40:** All Phase-1+2+3 functional behaviour preserved identically under every Phase-4 antforth 3.x point-release.
- **FR-P4-41:** Phase-3 close-out baseline (974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware) continues to pass; zero regressions = release blocker.
- **FR-P4-42:** Pre-Phase-4 CODE-word source assembles byte-identical when targeting same memory region; cross-bank CODE-word policy = architecture-stage open question.
- **FR-P4-43:** 12-word `BANK*` wordset is additive; no pre-Phase-4 word changes name/stack-effect/semantics; pre-Phase-4 `.FTH` files run unchanged (implicitly in bank 0 / portal page).

**Total FRs: 43** (FR-P4-1 through FR-P4-43)

### Non-Functional Requirements Extracted

NFRs use `NFR-P4-N` prefix. Total: **39 NFRs** across 6 categories. Phase 4 explicitly omits Security / Scalability / Accessibility categories (selective approach justified: single-user, offline, 8-bit, hardware-constrained).

#### Performance

- **NFR-P4-1:** Carries Phase-2 NFR1–NFR5 (prefix parse ≤~20 cycles; multi-vocabulary lookup ≤10% regression; uncaught CATCH ≤~15 cycles; ROM-footprint budget per epic; double-precision within ~20% of hand-rolled).
- **NFR-P4-2:** `BANK!` completes ≤ 60 T-states + MMU port-write.
- **NFR-P4-3:** Cross-bank call overhead ≤ 60 T-states + bank-switch time.
- **NFR-P4-4:** Descriptor stub ≤ 5 bytes; 1000-banked-words target ≤ 5 KB total.
- **NFR-P4-5:** Banking infrastructure ≤ 8 KB fixed memory at 28-bank cap (~6 KB at default 12).
- **NFR-P4-6:** Bank-aware FIND ≤ 5–15 % regression on batch loading; interactive sub-frame at 8 MHz.

#### Reliability

- **NFR-P4-7:** REPL survives any THROW including cross-bank THROWs; trampoline restores caller bank on unwind.
- **NFR-P4-8:** No internal data structure (incl. `bank-table[]`) left corrupted after THROW.
- **NFR-P4-9:** Filesystem error recovery — carries Phase-2 NFR8 / Phase-3 NFR-P3-5 unchanged.
- **NFR-P4-10:** 974-test baseline passes on every 3.x release candidate; single regression = release blocker.
- **NFR-P4-11:** S9 mid-epic hardware-smoke per binary-delta story; zero-binary-delta stories document exemption.

#### Compatibility & Standards Conformance

- **NFR-P4-12:** ANS Forth 1994 Core §-level defensible, 100% coverage maintained.
- **NFR-P4-13:** Forth 2014 §3.4.1.3 numeric-literal prefix syntax verbatim.
- **NFR-P4-14:** Extension discipline — `BANK*` words flagged per CCD-3 (`; antforth extension`) pointing at redesign doc.
- **NFR-P4-15:** CP/M 2.2 BDOS allow-list unchanged in Phase 4; BDOS calls work unchanged from banked code.
- **NFR-P4-16:** Pre-Phase-4 CODE-word source byte-identical when targeting same memory region.
- **NFR-P4-17:** `ans-forth-core-compliance.md` row-level auditable in ≤10 min by external implementor.

#### Maintainability

- **NFR-P4-18:** Readability over micro-optimisation; banking infra cites redesign doc §-numbers inline.
- **NFR-P4-19:** REPL-piped test coverage before "done" (S2); dual-tracked probes (banking emulator + iz-cpm + hardware).
- **NFR-P4-20:** Single-source-of-truth for standards refs per CCD-3; banking words cite redesign doc.
- **NFR-P4-21:** Each Phase-4 epic = independently shippable antforth 3.x point-release.
- **NFR-P4-22:** Story-template lints / HALT signals fire automatically.

#### Integration (CP/M and Platform)

- **NFR-P4-23:** Char-based BDOS console I/O only (functions 1, 2, 6, 9).
- **NFR-P4-24:** CP/M 2.2 file path syntax (drive + 8.3).
- **NFR-P4-25:** No MicroBeast peripheral hardware words in kernel (E.1 deferred); `BANK*` is the exception (memory-model primitive, not peripheral).
- **NFR-P4-26:** **ISR-from-fixed-memory-only invariant.** No banked code reachable from any interrupt vector; ISR firing mid-`BANK!` is safe.
- **NFR-P4-27:** `CALL 0005h` from any bank lands in fixed-memory BDOS; no bank-switching glue around BDOS calls.

#### Process Discipline (S1–S12 standing commitments)

- **NFR-P4-28 through NFR-P4-39:** Codify S1–S12 (12 standing commitments) as Phase-4 quality attributes — adversarial CR (S1), REPL-piped tests (S2), real-byte-count estimation (S3), AC-composition validation (S4), PARTIAL→HALT (S5), helpers-not-just-leaves grep (S6), EXX-hygiene per raise site (S7), pre-existing-not-discharge (S8), per-story hardware-smoke (S9, also NFR-P4-11), workflow>memory>prompt (S10), version-surface audit (S11), hardware-typed probe discipline incl. TIB-128 lint (S12).

**Total NFRs: 39** (NFR-P4-1 through NFR-P4-39)

### Additional Requirements / Constraints

- **Architecture-stage open questions** (PRD does **not** lock these — assigned to Phase-4 Architecture or Epic-16 spike stories):
  1. CODE-words-in-banks dispatch policy (Epic 22 ambiguity).
  2. CL parser edge cases (no args, bad token, reverse range, dup, probe-fail, empty surviving list).
  3. Bank-state-table cap (29 entries) — ABORT-on-`+BANK`-past-cap policy.
  4. Stub size pinning (3 vs 4–5 bytes); affects 1000-word-target cost calc.
  5. Recursive cross-bank R-stack overflow — documented gotcha vs runtime guard.
- **Phase-4 prework gate (Epic 16.3):** banking-capable emulator vendor selection. iz-cpm does not bank; dual-track strategy required before Epic-17 story-writing.
- **Out of MVP scope (explicit):** flat-build retention deferred to Phase 5+; Phase-4 stories must not slow down to preserve flat-build compatibility.
- **CCP eviction policy:** +2 KB Page-3 headroom; BDOS + BIOS stay resident.

### PRD Completeness Assessment

**Initial assessment — passing on a first read.** Areas of strength:

- FRs are testable (every FR has an observable outcome: REPL probe, hardware probe, byte-identical output, error path, port-write trace, return value).
- Regression FR (FR-P4-40..43) gives a single umbrella for "Phase-1+2+3 still holds" rather than restating prior FRs — avoids drift.
- Architecture-stage open questions explicitly flagged at PRD altitude with `TODO(P4-arch)` discipline; PRD does not lock them.
- NFR selective-omission (Security/Scalability/Accessibility) justified inline rather than silently skipped.
- Standing commitments S1–S12 are codified as NFRs (NFR-P4-28..39), not just process notes.
- Per-FR group → epic mapping (in §Project Scoping) traces every banking capability to its delivering epic.

**Watch-items (will be re-examined in Step 3 epic-coverage and Step 5 quality review):**

- FR-P4-13 names the (γ) descriptor-stub mechanism — borderline implementation directive vs xt-contract surface. PRD asserts altitude-OK because stub-address = xt is user-visible (FR-P4-17). Acceptable, but Step 5 should confirm the architecture document carries the implementation depth.
- FR-P4-21 is partially open ("TODO(P4-resolve)" deferred to architecture). Step 3 needs to verify this is captured by an Epic-16 spike story.
- 5 architecture-stage open questions listed in §Implementation Considerations — Step 3 / Step 5 needs to verify each is owned by a concrete Epic-16 story.
- Defaults "12 banks" / "192 KB" appear in many places; consistency check needed against architecture document and epics file (Step 5).
- FR-P4-3 says `BANKS` is a `VALUE`. Step 5 should confirm this isn't an over-specification at PRD altitude (matters if implementation prefers a function).

## Step 3 — Epic Coverage Validation

### Document Read

- **File:** `epics-phase4-epics-16-22.md` (1151 lines, 7 epics, **28 stories**)
- Epics doc contains its own canonical `## FR Coverage Map` table (lines 194–241) and every story states `**FRs covered:**` inline.
- Cross-checked by walking every story's explicit FR list against the PRD FR set FR-P4-1..43.

### Epic-Level Story Inventory

| Epic | Title | Stories | Cumulative binary delta | Ships |
|---|---|---|---|---|
| 16 | Prework — memory map / emulator pick / design lock | 4 (16.1–16.4) | 0 B (planning only) | (no tag — gate) |
| 17 | Bank primitives + CL configuration | 6 (17.1–17.6) | ≤ ~400 B | antforth 3.x.1 |
| 18 | Stub mechanism (γ) + cross-bank EXIT (S1 b) + BANK-OF + IN-BANK | 5 (18.1–18.5) | ≤ ~400 B | antforth 3.x.2 |
| 19 | Bank-aware compiler `:` / `,` / `COMPILE,` / `CREATE` / `DOES>` | 4 (19.1–19.4) | ≤ ~300 B | antforth 3.x.3 |
| 20 | Bank-aware FIND + WORDS + interpreter-loop attribution | 3 (20.1–20.3) | ≤ ~200 B | antforth 3.x.4 |
| 21 | MARKER/FORGET per-bank + ABORT/QUIT bank-state restore (S5) | 3 (21.1–21.3) | ≤ ~150 B | antforth 3.x.5 |
| 22 | Polish + Phase-4 close-out | 4 (22.1–22.4) | ≤ ~100 B | antforth 3.x.6 (final) |
| **Total** | | **28** | **≤ ~1550 B** | |

Cumulative envelope ~1550 B is well within the NFR-P4-5 ≤8 KB cap and the +2 KB CCP-eviction headroom.

### FR Coverage Matrix (PRD → Story)

| FR | Capability | Delivered by | Status |
|---|---|---|---|
| FR-P4-1 | `BANK@` | Story 17.2 | ✓ Covered |
| FR-P4-2 | `BANK!` | Story 17.2 | ✓ Covered |
| FR-P4-3 | `BANKS` | Story 17.2 | ✓ Covered |
| FR-P4-4 | `IN-BANK` (kernel-blessed, CATCH-safe) | Story 18.5 | ✓ Covered |
| FR-P4-5 | `BANK-OF` | Story 18.4 | ✓ Covered |
| FR-P4-6 | `.BANKS` | Story 17.5 (minimal) → Story 22.1 (final) | ✓ Covered |
| FR-P4-7 | `+BANK` (probe-on-add) | Story 17.3 | ✓ Covered |
| FR-P4-8 | `-BANK` | Story 17.3 | ✓ Covered |
| FR-P4-9 | `BANKS-CLEAR` | Story 17.3 | ✓ Covered |
| FR-P4-10 | `SET-BANK` (diagnostic raw MMU write) | Story 17.3 | ✓ Covered |
| FR-P4-11 | `BANK-MAPPING-ON` (auto-on in COLD) | Story 17.1 | ✓ Covered |
| FR-P4-12 | `BANK-MAPPING-OFF` | Story 17.1 | ✓ Covered |
| FR-P4-13 | Per-word descriptor stub (γ); stub addr = xt | Story 18.1 (stub-size pin via 16.4 §9.5) | ✓ Covered |
| FR-P4-14 | `COMPILE,` always emits stub address | Story 18.3 (initial) → Story 19.1 (final) | ✓ Covered |
| FR-P4-15 | Intra-bank dispatch ≤ 1 `JP` overhead | Story 18.3 | ✓ Covered |
| FR-P4-16 | Cross-bank dispatch ≤ 60 T + MMU | Story 18.3 | ✓ Covered |
| FR-P4-17 | xt portability across `BANK!` | Story 18.1, Story 18.3 | ✓ Covered |
| FR-P4-18 | Sentinel-tagged 3-cell return frame | Story 18.2 | ✓ Covered |
| FR-P4-19 | Intra-bank zero-overhead path | Story 18.2 | ✓ Covered |
| FR-P4-20 | `cross_bank_return` trampoline | Story 18.2 | ✓ Covered |
| FR-P4-21 | Recursive cross-bank R-stack overflow → `-5 THROW` | Story 18.2 (per 16.4 §9.6 closure) | ✓ Covered |
| FR-P4-22 | Per-bank `(here, latest, wordlist-heads)` | Story 17.1 (shell) → Story 19.1 (full plumbing) | ✓ Covered |
| FR-P4-23 | Per-bank `,` and `COMPILE,` | Story 19.1 | ✓ Covered |
| FR-P4-24 | `:` lands body in current bank | Story 19.2 | ✓ Covered |
| FR-P4-25 | `CREATE`/`DOES>` cross-bank explicit | Story 19.3 | ✓ Covered |
| FR-P4-26 | `HERE`/`LATEST` per bank | Story 19.1 | ✓ Covered |
| FR-P4-27 | Per-wordlist `bank` field | Story 20.1 | ✓ Covered |
| FR-P4-28 | `FIND` save/switch/walk/restore | Story 20.1 | ✓ Covered |
| FR-P4-29 | `WORDS` traverses banks | Story 20.2 | ✓ Covered |
| FR-P4-30 | Lookup-failure error names source bank | Story 20.2 | ✓ Covered |
| FR-P4-31 | Saved current-bank cell (interactive `BANK!` only) | Story 21.2 (F6 mitigation via STATE@0= + INCLUDE-TOP depth=1) | ✓ Covered |
| FR-P4-32 | `QUIT` re-asserts saved bank | Story 21.2 | ✓ Covered |
| FR-P4-33 | `ABORT`/`ABORT"` bank-state | Story 21.2 | ✓ Covered |
| FR-P4-34 | CL parser `antforth <portal> <list>` | Story 17.4 (edge cases per 16.4 §9.3 closure) | ✓ Covered |
| FR-P4-35 | CL parser defaults `22 35-3F` | Story 17.4 | ✓ Covered |
| FR-P4-36 | CL parser probe-on-add | Story 17.4 | ✓ Covered |
| FR-P4-37 | Banner shows bank count | Story 17.4 | ✓ Covered |
| FR-P4-38 | `STARTUP.FTH` NOT the config mechanism | Story 17.4 (architectural rejection captured in source comment) | ✓ Covered |
| FR-P4-39 | 12 banks default / 29 banks max | Story 17.4 | ✓ Covered |
| FR-P4-40 | Phase-1+2+3 functional preserved | Phase-wide (verified at every epic close-out; final at Story 22.4) | ✓ Covered |
| FR-P4-41 | 974-PASS test baseline holds | Phase-wide (release blocker per AC on every story; final at Story 22.4) | ✓ Covered |
| FR-P4-42 | Pre-Phase-4 CODE-word source byte-identical | Story 22.3 (cross-bank CODE-word disposition per 16.4 §9.1 closure) | ✓ Covered |
| FR-P4-43 | `BANK*` wordset additive | Phase-wide (verified at Story 22.4 full-sweep) | ✓ Covered |

### NFR Coverage Spot-Check

NFRs are typically codified at epic-summary level rather than at single stories, since they govern repeated behaviour. Spot-check confirms each NFR has a named enforcement point:

| NFR | Enforced at | Status |
|---|---|---|
| NFR-P4-1 (Phase-2 perf envelopes) | Story 19.1 AC8 (intra-bank `,`/`C,` ≤5% regression) | ✓ |
| NFR-P4-2 (BANK! ≤60 T) | Story 17.2 AC5 (first measure) | ✓ |
| NFR-P4-3 (cross-bank ≤60 T+MMU) | Story 18.3 AC3 (first measure), Story 22.4 AC4 (final) | ✓ |
| NFR-P4-4 (stub ≤5 B; ≤5 KB at 1000-word target) | Story 18.1 AC6 (per-stub), Story 19.4 / 22.4 (cumulative) | ✓ |
| NFR-P4-5 (banking infra ≤8 KB) | Per-story envelopes per epic; Story 22.4 AC3 (final cumulative) | ✓ |
| NFR-P4-6 (FIND batch ≤5–15% regression) | Story 20.1 AC5 | ✓ |
| NFR-P4-7 (REPL survives cross-bank THROW) | Story 18.3 AC6, Story 21.2 AC5 | ✓ |
| NFR-P4-8 (state integrity incl. bank-table[]) | Story 19.2 AC6, Story 21.1 AC9 (MARKER/FORGET integrity) | ✓ |
| NFR-P4-9 (filesystem error recovery) | Phase-2/3 carry-forward; verified via 974-PASS baseline | ✓ |
| NFR-P4-10 (974-PASS regression guarantee) | Every story AC; release blocker | ✓ |
| NFR-P4-11 (S9 hardware smoke per binary-delta story) | Every binary-delta story AC | ✓ |
| NFR-P4-12 (ANS Core compliance) | Story 20.1 AC6 (FIND row update) | ✓ |
| NFR-P4-13 (Forth 2014 §3.4.1.3) | Phase-3 carry-forward (no Phase-4 delta) | ✓ |
| NFR-P4-14 (banking-word CCD-3 source flags) | Every banking-word story AC | ✓ |
| NFR-P4-15 (BDOS allow-list unchanged) | Phase-wide invariant; no story adds BDOS function | ✓ |
| NFR-P4-16 (CODE-word source byte-identical) | Story 22.3 AC5 | ✓ |
| NFR-P4-17 (compliance-doc auditability) | CCD-P3-1 row schema carry-forward; banking rows added per story | ✓ |
| NFR-P4-18 (banking code readability) | Per-story source-comment discipline | ✓ |
| NFR-P4-19 (REPL-piped tests as default; dual-track) | Story 16.3 (vendor pick); per-story probe annotations | ✓ |
| NFR-P4-20 (single-source-of-truth for refs) | Per-story CCD-3 citations | ✓ |
| NFR-P4-21 (per-epic point-release) | Every epic-close-out story (17.6 / 18.5 / 19.4 / 20.3 / 21.3 / 22.4) | ✓ |
| NFR-P4-22 (story-template discipline) | Inherent process invariant; checked at every story draft | ✓ |
| NFR-P4-23 (terminal I/O portability) | Phase-wide invariant | ✓ |
| NFR-P4-24 (CP/M 2.2 file paths) | Phase-wide invariant | ✓ |
| NFR-P4-25 (no peripheral HW in kernel; banking exception) | Phase-wide invariant; explicit exception declared | ✓ |
| NFR-P4-26 (ISR from fixed memory only) | Story 16.1 (verified vs MicroBeast IM 2 vector); phase-wide invariant | ✓ |
| NFR-P4-27 (BDOS calls unchanged from banked code) | Phase-wide invariant; verified in Story 16.1 page survey | ✓ |
| NFR-P4-28..39 (S1–S12 standing commitments) | Every story AC + every epic close-out retro | ✓ |

### Coverage Statistics

- **Total PRD FRs:** 43
- **FRs covered in epics:** 43 (100%)
- **FRs uncovered:** 0
- **Total PRD NFRs:** 39
- **NFRs enforced via stories:** 39 (100%)

### Missing Requirements

**None.** All 43 FR-P4-N and all 39 NFR-P4-N are accounted for.

### Sequencing Soundness Spot-Check

| Architectural input | Resolved by | Consumed by |
|---|---|---|
| §9.1 cross-bank CODE-words disposition | Story 16.4 AC5 | Story 22.3 |
| §9.3 CL parser edge-case policy | Story 16.4 AC4 | Story 17.4 AC5 |
| §9.4 `+BANK` past-cap policy | Story 16.4 AC3 | Story 17.3 AC2 |
| §9.5 stub-size pin (3/4/5 B) | Story 16.4 AC1 | Story 18.1 AC1 (per-stub size) |
| §9.6 cross-bank R-stack overflow disposition | Story 16.4 AC2 | Story 18.2 AC6 (FR-P4-21) |
| Banking-capable emulator vendor pick | Story 16.3 | Every binary-delta story (probe surface annotation) |
| CCP eviction hardware verification | Story 16.1 | Story 17.1 AC2 (memory-map edit consumes the +2 KB) |

All five open questions are owned by Epic-16 spike stories and consumed by named downstream stories. The PRD's "watch-item" from Step 2 (FR-P4-21 partial open) is resolved by the 16.4→18.2 chain.

### Additional Findings (positive)

- **No orphan stories.** Every story either delivers an FR directly, codifies an NFR, or closes a named architectural finding (F1–F6) or carry-forward item.
- **Phase-wide constraints (FR-P4-40/41/43) enforced both per-epic and at the final Story 22.4 full-sweep** — no risk of "passed individually, fail at integration."
- **Per-epic envelopes sum within NFR-P4-5 budget** with margin: ~1550 B cumulative vs ~6 KB target at 12 banks, well under the ≤8 KB worst-case cap.
- **CCD-4 close-out discipline** (banked-word stub-count metric) starts at Story 18.5 and is captured every epic close-out through 22.4 — F2 mitigation operational from the first cross-bank dispatch landing.

### Watch-Items (carried into Step 5)

- **Conditional-AC pattern in Story 22.3** is unusual: AC2 / AC3 / AC4 branch on which disposition Story 16.4 §9.1 chose. This is acceptable (the architecture decision is the binding input) but Step 5 quality review should confirm Story 22.3 is unblocked at story-draft time once 16.4 resolves.
- **Story 21.1 covers no direct FR** — it is shaped as gap-analysis mitigation (MARKER/FORGET per-bank + stub-allocator-tail reclamation). Its contribution to FR-P4-40 (Phase-1+2+3 preserved across banks) is real but implicit. Step 5 should confirm the story-AC text makes the FR-40 linkage explicit.
- **Story 18.3 wires FR-P4-14 only initially**; final integration lives in Story 19.1. The dependency is correctly modelled but Step 5 should confirm Story 18.3's AC2 wording is unambiguous about the initial-vs-final boundary.

## Step 4 — UX Alignment

### UX Document Status

**Not Found — and not required.**

- Discovery (Step 1) confirmed: no `*ux*.md` whole or sharded under `_bmad-output/planning-artifacts/`.
- Reference search for UI-related terms in `prd.md` and `architecture.md`: zero hits on "wireframe", "screen", "page", "widget", "stylesheet", "responsive"; "REPL prompt" appears as expected for a CLI tool.

### Is UX/UI Implied?

**No — explicitly excluded.**

The PRD contains an explicit justification for the absence of UX deliverables. Quoted from `prd.md`:

> "antforth is distributed as a **CP/M 2.2 `.COM` executable** that runs on the MicroBeast Z80 retrocomputer. It is simultaneously (a) an implementation of the ANS Forth 1994 / Forth 2014 programming language and (b) a self-hosted interactive development environment. It has no external build chain, no package dependency graph, no network surface, and no multi-user runtime."

> "Visual design / store compliance / browser support — explicitly skipped per CSV `skip_sections` for both `developer_tool` (`visual_design;store_compliance`) and `iot_embedded` (`visual_ui;browser_support`)."

> "**IDE integration** — the REPL IS the IDE; syntax highlighting / completion are out of scope."

The single user-experience surface that exists — the REPL prompt — is governed by:

- **FR-P4-37** (boot banner shows bank count) → owned by Story 17.4
- **Story 22.2** (optional REPL prompt indicator `[N] ok`) → opt-in flag `PROMPT-SHOW-BANK ON/OFF`, default OFF to preserve Phase-3 visual baseline
- **F4 user-docs entry** (cross-bank pointer hazards) → owned by Story 22.2 AC2

These two user-experience touch-points are integrated into the epics file with explicit ACs (banner format string verified per-tag under S11 / NFR-P4-38; prompt indicator behaviour tested under both `PROMPT-SHOW-BANK` settings).

### Alignment Issues

**None.** PRD, architecture, and epics agree:

- PRD §"User Journeys" §"Scope Note on User Types" explicitly states "antforth is a single-user interactive REPL running on personal retrocomputer hardware" with no admin / support / moderator / API-consumer categories applicable.
- Architecture document carries forward the same single-user-REPL framing.
- Epics file's user-outcome bullets (Marc the OG user; the Newb; Pete the hardware-peripheral developer) are framed around terminal-character interactions, not visual UX.

### Warnings

**None.**

The absence of a UX document is **expected and justified** for this project type. The PRD's classification (`developer_tool_embedded` + skip-sections `visual_design;store_compliance` / `visual_ui;browser_support`) is internally consistent and the journey narratives confirm a CLI / REPL-only surface.


## Step 5 — Epic Quality Review

Adversarial review against create-epics-and-stories standards (user-value focus, independence, dependency hygiene, AC quality). The Phase-4 epics file is generally disciplined; findings below are real concerns, not nitpicks. Coverage gaps from Step 3 are not re-flagged here.

### Epic Structure Validation

#### A. User-Value Focus

| Epic | User-facing outcome | Verdict |
|---|---|---|
| 16 | None (prework). Story 16.1–16.4 ship hardware-verification transcripts, doc supersession, emulator vendor pick, architecture decisions. | 🟠 Major-noted (see Finding Q1 below) |
| 17 | User types `5 BANK!` at REPL and bank index changes; boot banner reports bank count; `+BANK`/`-BANK` mutate at runtime. | ✓ User-valuable |
| 18 | User invokes `IN-BANK` / `BANK-OF`; cross-bank `EXECUTE` round-trip works at REPL. | ✓ User-valuable |
| 19 | `5 BANK! : MYWORD ... ;` defines into bank 5 transparently — the north-star UX. | ✓ User-valuable (highest-leverage epic) |
| 20 | `WORDS` traverses banks invisibly; typo errors name source bank. | ✓ User-valuable |
| 21 | ABORT mid-execution does not strand the user in the wrong bank; MARKER/FORGET works across banks. | ✓ User-valuable |
| 22 | `.BANKS` polished; optional REPL prompt indicator `[N] ok`; F4 user-docs entry. | ✓ User-valuable |

#### B. Epic Independence

| Epic | Depends on | Verdict |
|---|---|---|
| 16 | (gate epic — depends on Phase-3 close-out only) | ✓ Independent |
| 17 | Epic 16 outputs (emulator vendor pick + CCP-eviction transcript + §9.3/§9.4 closures) | ✓ Backward only |
| 18 | Epic 17 (`BANK@` / `BANK!`) | ✓ Backward only |
| 19 | Epic 18 (stub allocator + cross-bank EXECUTE) | ✓ Backward only |
| 20 | Epic 17 + 18 (parallel-able with Epic 19) | ✓ Backward only; parallelism documented |
| 21 | Epic 17, 18, 19 (trampoline + per-bank dict state) | ✓ Backward only |
| 22 | All others (close-out / polish) | ✓ Backward only |

**No forward dependencies found.** Dependency graph is a clean DAG with Epic 22 as the unique sink.

### Story-Level Validation

#### Story Sizing

- Per-story byte envelopes: ~30 B (Story 18.4 `BANK-OF` one-byte read) to ~200 B (Story 17.4 CL parser). Median ~80 B.
- Per-story AC count: 6–11 ACs (median ~9). Heavy but appropriate for kernel work with hardware-smoke + version-audit + envelope-check rituals.
- Each story has a single clear deliverable expressible as a one-sentence user outcome.
- No "epic-sized story" (stories that should have been split): closest is Story 17.4 (CL parser, banner, defaults, probe-on-add — all in one story) but the AC enumeration is clean and these elements are tightly coupled.

#### AC Quality Spot-Check

Each story uses an explicit `Given / When / Then ... And` BDD shape with numbered ACs. Spot-check sample:

- **Story 17.2** AC1–AC9: each AC is grep-able for verification (e.g., AC5: "measures `BANK!` completing in ≤ 60 Z80 T-states + the MMU port-write time"; AC6: explicit REPL transcript expected return values). ✓
- **Story 18.2** AC1–AC10: each AC pinpointed to a kernel file (`src/inner_interpreter.asm` w_EXIT_cf), with concrete pre/post-conditions. ✓
- **Story 21.2** AC2: "interactive `BANK!` is defined as `STATE @ 0=` AND outer-interpreter-depth = 1" — concrete, testable, addresses F6 mitigation explicitly. ✓

#### Within-Epic Dependencies

Spot-checked: every story states `Given <prior story> has shipped` in its precondition row. Sequencing is monotonic-forward inside each epic.

### Dependency-Hygiene Verdict

- Architectural inputs (Story 16.4 §9.1/§9.3/§9.4/§9.5/§9.6) flow forward to consuming stories (17.3/17.4, 18.1/18.2, 22.3). All consuming stories explicitly state which §-closure they inherit.
- Test-surface dependencies: Story 16.3 must close before Epic 17+ probes can specify their surface. The dependency is explicit and ordered first.
- CCP eviction: verified in Story 16.1; consumed in Story 17.1 AC2. ✓
- No story references a future story for its dependencies (all references are backward).

### Greenfield vs Brownfield

Phase-4 is brownfield against the v2.0 + Phase-3-close-out baseline. Architecture and epics correctly omit:

- Initial project setup story (the v2.0 working tree IS the starter)
- Dev-environment configuration (tool-versions carry forward; one extension for the banking emulator vendor)
- CI/CD scaffolding (existing `make` targets carry forward; new `make test-repl-banking` target added in Story 16.3)

Brownfield-specific patterns ARE present and correctly placed:

- Integration points: kernel-file edit list enumerated in epics file under "From Architecture" (`src/inner_interpreter.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/memory.asm`, `src/system.asm`, `src/outer_interpreter.asm`, `src/exception.asm`, `src/antforth.asm`).
- Compatibility/migration: FR-P4-40/41/43 + NFR-P4-10 (974-PASS regression) + NFR-P4-16 (CODE-word byte-identical) enforce backward compatibility at every epic close-out.

### Findings (by severity)

#### 🔴 Critical Violations

**None.** No technical-only epic; no forward dependencies; no story without a meaningful deliverable.

#### 🟠 Major Issues

**Q1. Epic 16 is a planning-only epic with no user-facing deliverable.**

- Strict create-epics-and-stories doctrine treats "Setup", "Infrastructure", "Memory-map survey" as red flags.
- Epic 16's four stories ship: hardware-verification transcript (16.1), doc supersession (16.2), emulator vendor pick + Makefile edit (16.3), five architecture-decision rows (16.4).
- Mitigating context (acceptable):
  - Phase-4 is a feature phase in a kernel project; the design-lock and emulator vendor pick are genuinely load-bearing inputs to every downstream story. Skipping the prework would force every Epic-17+ story to inherit unresolved-design-input risk.
  - The epics file pre-empts this concern explicitly: "Epic 16 ships planning + design-lock artifacts that are valuable on their own (downstream-Phase architects can re-litigate these decisions with the records in hand). It does not require Epic 17+ to function."
  - Hardware verification of CCP eviction (Story 16.1) and emulator vendor pick (Story 16.3) are observable, dated, archived deliverables — not "I worked on this" hand-waves.
- **Verdict:** acceptable for this brownfield/kernel context. Note in final assessment that Epic 16 is a prework gate by design, not a user-value epic, and its standalone-claim is technically accurate but rhetorical.

**Q2. Story 22.3 has conditional ACs that branch on Story 16.4 §9.1's resolution.**

- Story 22.3 AC2/AC3/AC4 read "if disposition is yes…", "if disposition is no…", "if disposition is Phase-5+-deferred…" — three mutually-exclusive AC variants.
- The pattern is unusual: a dev-agent reading 22.3 in isolation must consult `architecture.md` §9.1 closure before they can identify which AC variant applies.
- Mitigating context: this is the standard `*Architectural input consumed*` pattern documented across the file (Story 17.3 AC2 inherits §9.4; Story 17.4 AC5 inherits §9.3; Story 18.1 AC1 inherits §9.5; Story 18.2 AC6 inherits §9.6). Story 22.3 is the only one with branching outcomes rather than a single inherited parameter — but the branching is legitimate because §9.1 has three valid architecture outcomes whereas §9.3–§9.6 each have one.
- **Recommendation:** when Story 22.3 reaches story-draft time, the dev-agent should narrow the AC to the single chosen variant in a story-spec edit (per `bmad-bmm-create-story` workflow). The current form is acceptable as a pre-architecture-closure provisional spec.

**Q3. NFR-P4-3 envelope (cross-bank call overhead ≤ 60 T-states + MMU port-write) may be tight.**

- Reading the dispatch path: stub decode (~10–15 T) + three return-stack PUSHes for the sentinel frame (~33 T at 11 T each for PUSH HL/DE/BC) + indirect jump to body (~10 T) = ~53–58 T excluding MMU port-write.
- The envelope is `≤ 60 T-states + MMU port-write time`, which puts the non-MMU portion right at the edge.
- Story 18.3 AC3 measures this envelope on first cross-bank dispatch; any over-envelope outcome triggers sprint-change-proposal per NFR-P4-5.
- **Verdict:** measurement discipline is correct; envelope is achievable but unlikely to have headroom. Note as a performance-risk item for Story 18.3 close-out.

#### 🟡 Minor Concerns

**Q4. Story 21.1 covers no direct FR.**

- The story header reads `**FRs covered:** none of FR-P4-31..33 directly (this story is the MARKER/FORGET arm of Epic 21, gap-analysis-mitigation-shaped)`.
- Story 21.1 IS user-valuable (MARKER/FORGET per-bank reliability) and traces to FR-P4-40 (Phase-1+2+3 functional preserved) via the implicit "MARKER works across banks the way it worked in flat memory" interpretation.
- **Recommendation:** add `FR-P4-40 (MARKER/FORGET correctness preserved across banks)` to Story 21.1's FR-covered list to make the link explicit. Cosmetic; does not block implementation.

**Q5. Story 17.6 (and other close-out stories) commits to `antforth 3.x.1` as the banner string literal, but PRD says "Phase 4 ships antforth 3.x point-releases" — version pattern, not literal.**

- Story 17.6 AC5 says: "banner string reads `antforth 3.x.1 — N banks available — ok`".
- If the actual close-out tag is `3.1.0` or `3.0.1`, the banner string in AC5 needs an update.
- The epics file uses `3.x.1` through `3.x.6` throughout; these read as placeholders.
- **Recommendation:** narrow the version-string literal at story-draft time (post-architecture-closure) per the close-out PR convention; the current `3.x.N` shape is fine as a pre-draft placeholder.

**Q6. Story 16.3 has no fallback if all banking-capable emulator candidates fail the three pinned criteria.**

- AC2 says "a single vendor is picked"; AC1 says criteria are (a) MMU port model match, (b) pipe-ability, (c) bank-visibility.
- If zero candidates satisfy all three, the story cannot dev-pass and Epic 17+ remains blocked indefinitely.
- Mitigating context: the redesign-doc §8.1 names this gate explicitly as a project-lead responsibility; if the criteria yield zero candidates, the project lead would invoke `bmad-bmm-correct-course` per existing escalation patterns. The risk is real but the escalation path exists.
- **Recommendation:** none required — this is a known critical-path with documented mitigation. Note in final assessment as a known schedule risk.

**Q7. Per-story AC count is heavy (median ~9 ACs).**

- Each AC ties to a concrete artifact (kernel file edit, REPL probe, hardware transcript, envelope measurement, source-comment cite). Heavy ACs are appropriate for kernel/test work but increase per-story review time and reduce velocity flexibility.
- **Verdict:** Phase-3 retro evidence (974-PASS clean close-out across 50+ stories with this AC density) shows the discipline scales. No change recommended.

**Q8. Test-surface sweep ceremony cost is real.**

- Every binary-delta story runs probes on iz-cpm + banking-capable emulator + real MicroBeast hardware. Median story-close-out ceremony is meaningful.
- This is a documented Phase-3 carry-forward discipline (S9), not new ceremony. The project lead has accepted the trade-off explicitly.
- **Verdict:** velocity-risk note, not a defect.

### Best-Practices Compliance Checklist (per Epic)

| Check | E16 | E17 | E18 | E19 | E20 | E21 | E22 |
|---|---|---|---|---|---|---|---|
| Delivers user value (or prework-justified) | 🟠 prework | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Functions independently (backward-only deps) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Stories appropriately sized | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No forward dependencies | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Database/state created when needed (kernel-state per-bank lazy alloc) | N/A | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Clear acceptance criteria | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Traceability to FRs maintained | ✓ | ✓ | ✓ | ✓ | ✓ | 🟡 21.1 | ✓ |

### Quality Verdict

**No 🔴 critical violations. 3 🟠 major issues, all with mitigating context (Q1, Q2, Q3). 5 🟡 minor concerns (Q4–Q8). All findings have documented mitigation or recommended remediation; none block implementation entry.**

The epics file is unusually disciplined: explicit `FRs covered`, `NFRs codified`, `Architectural inputs consumed`, `Findings closed` rows per story; explicit `Standalone: ✓` claims with rationale per epic; phase-wide constraints enforced both per-epic and at integration. This is a quality bar above typical mid-PRD-fidelity story-spec files.

## Summary and Recommendations

### Overall Readiness Status

**READY** — with minor remediation recommended (not blocking).

### Headline Verdict

The Phase-4 entry artifacts (`prd.md`, `architecture.md`, `epics-phase4-epics-16-22.md`) are in unusually good shape. Every FR-P4-N is covered, every NFR-P4-N has a named enforcement point, the architecture's five open questions are owned by Epic-16 spike stories, the dependency graph is a clean DAG, and the per-epic byte envelopes sum within the NFR-P4-5 fixed-memory cap with margin.

The findings below are **real** (not nitpicks) but **none block implementation entry**. Phase 4 can proceed to Epic 16 story execution immediately.

### Findings Inventory

| Severity | Count | Items |
|---|---|---|
| 🔴 Critical | 0 | — |
| 🟠 Major (mitigated) | 3 | Q1 (Epic 16 prework), Q2 (Story 22.3 conditional ACs), Q3 (NFR-P4-3 envelope tight) |
| 🟡 Minor | 5 | Q4 (Story 21.1 FR link), Q5 (3.x.N version placeholder), Q6 (Story 16.3 emulator fallback), Q7 (heavy AC count), Q8 (test-surface ceremony cost) |

### Critical Issues Requiring Immediate Action

**None.** No critical issue blocks Epic 16 story execution.

### Recommended Next Steps

#### Before starting Epic 16 (zero blocking, recommended)

1. **Add FR-P4-40 explicit link to Story 21.1.** Edit `epics-phase4-epics-16-22.md` Story 21.1 `**FRs covered:**` row to read `FR-P4-40 (MARKER/FORGET correctness preserved across banks — via Phase-1+2+3 functional-preservation umbrella)`. One-line edit; closes Q4.

2. **No edit needed for Q5 (version placeholder).** Story-draft-time narrowing (at `bmad-bmm-create-story` invocation) is the right mechanism per Phase-3 precedent. The current `3.x.N` shape is correct as a pre-draft placeholder.

3. **Acknowledge Q6 in Story 16.3 Dev Notes.** Suggest adding a one-line "if no candidate satisfies all three criteria, escalate via `bmad-bmm-correct-course` per project-lead direction" sentence to Story 16.3's Dev Notes section when the story is drafted.

#### During Epic 16 execution

4. **Story 16.4 §9.1 resolution should land before Story 22.3 is drafted.** Tracking note: when Story 16.4 closes, follow up with a one-line edit to Story 22.3's AC block narrowing the conditional ACs to the single chosen disposition variant.

#### During Epic 18 execution

5. **Story 18.3's NFR-P4-3 envelope measurement is a watch-item.** ~60 T-states excluding MMU is tight. Per Story 18.3 AC3, any over-envelope outcome triggers sprint-change-proposal — the mitigation path exists. Plan extra investigation budget for this story.

#### Phase-wide (no immediate action)

6. **Test-surface sweep ceremony cost (Q8) and AC density (Q7)** are documented Phase-3 carry-forward disciplines. No remediation recommended; track velocity and flag at the Epic-17 retro if the cadence becomes load-bearing.

### What Worked Well (Positive Signals)

- **Coverage discipline.** 43/43 FRs and 39/39 NFRs traced to delivering stories. No orphan FRs.
- **Architectural-input flow.** Every "TODO(P4-arch)" item from PRD has a named Epic-16 spike story; every Epic-17+ story consuming an arch decision cites the §-closure verbatim.
- **Phase-wide regression discipline.** FR-P4-40/41/43 enforced at both per-epic close-out and final Story 22.4 full-sweep.
- **Per-epic envelope hygiene.** Cumulative ~1550 B vs ~6 KB target at default 12 banks; comfortable margin.
- **Dependency DAG.** Zero forward references; Epic 20 parallel-able with Epic 19 noted explicitly.
- **Brownfield pattern fidelity.** No starter-template story; integration-point file list enumerated; backward-compat FRs (40/41/42/43) present as phase-wide constraints.
- **Standing-commitments (S1–S12)** codified as NFR-P4-28..39 — process discipline embedded as testable attributes, not separate process docs.

### Final Note

This assessment identified **0 critical, 3 major (mitigated), 5 minor** findings across the 5 review steps. **No finding blocks Phase 4 implementation entry.** The PRD, architecture, and Phase-4 epics document are mutually-consistent, internally-coherent, and traceably mapped FR-by-FR.

Recommended action: proceed to Epic 16 story execution. The one-line edit recommended for Story 21.1 (Q4) and the watch-item for Story 18.3 (Q3) are the only items worth surfacing before Dev work begins; everything else is observable during execution per the established Phase-3 retro / verdict-table discipline.

---

**Assessor:** Claude (Implementation-Readiness review per BMAD `check-implementation-readiness` workflow)
**Date:** 2026-05-10
**Workflow version:** BMAD bmm 6.0.4

