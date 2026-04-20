# Sprint Change Proposal — Drop Lazy-Load Assembler (ASSEMBLER.FTH) Capstone

**Date:** 2026-04-20
**Author:** Ant (proposal produced via `bmad-bmm-correct-course`)
**Scope classification:** **Moderate-to-Major** — Phase-2 MVP acceptance gate changes; PRD, Architecture, Epics, and Sprint-Status artefacts all require edits; two stories deleted, two renumbered.

---

## Section 1: Issue Summary

**Problem statement.** The project lead has decided to retain the existing Z80-assembly implementation of the antforth assembler (`src/assembler.asm`) and to NOT migrate the ~168 opcode words to a separate `ASSEMBLER.FTH` Forth-source file that is lazy-loaded on first `CODE`.

**Context.** Epics 9–13 (antforth 2.0) were planned with a capstone demo — the "north-star demo" — in which a fresh-booted kernel had the `ASSEMBLER` wordlist empty, and the first `CODE` invocation transparently loaded `ASSEMBLER.FTH` from disk. That capstone tied together numeric prefixes (Epic 9), Core compliance (Epic 10), CATCH/THROW (Epic 11), Search-Order + `ASSEMBLER` wordlist (Epic 12), and File-Access (Epic 13) in one coherent scenario, and was the acceptance gate for tagging 2.0.

**Direction given.** Keep `src/assembler.asm` as-is. Do not create `examples/ASSEMBLER.FTH`. Do not wire a first-`CODE` auto-load hook. All other Phase-2 goals remain unchanged: numeric-literal prefixes, 100% ANS Core compliance, double-precision + pictured output, CATCH/THROW, Search-Order, File-Access.

**Evidence.** Direct instruction from project lead, 2026-04-20 — verbatim: *"I no longer wish to replace the current built-in assembler functionality with an ASSEMBLER.FTH file that is auto-loaded the first time the user enters a CODE word. Keep the existing (assembly language) implementation of the assembler. do not create ASSEMBLER.FTH. Do not auto-load it. All other goals remain the same."*

---

## Section 2: Impact Analysis

### Epic Impact

| Epic | Status | Impact |
|---|---|---|
| Epic 9 — Numeric prefixes | in-progress (9.1, 9.2 done; 9.3–9.6 backlog) | **None.** Assembler-source prefix reach (Story 9.5) still applies — the assembler is still a consumer of numeric prefixes, it's just the built-in kernel assembler rather than a Forth-source one. |
| Epic 10 — Core compliance to 100% | backlog | **None.** |
| Epic 11 — CATCH/THROW | backlog | **None.** |
| Epic 12 — Search-Order + ASSEMBLER wordlist | backlog | **Moderate.** Story 12.6 (ASSEMBLER wordlist + auto-activation) is still needed — the opcode words become reachable only inside `CODE`/`END-CODE`. Story 12.7 (`ASSEMBLER.FTH` authorship, full opcode migration) is **deleted**. Story 12.8 (benchmark gate) loses one of its inputs (kernel-size delta contribution from opcode migration). |
| Epic 13 — File-Access | backlog | **Moderate.** Stories 13.1–13.4 (file I/O sanity, core File-Access wordset, positioning, INCLUDE nesting) are unchanged. Story 13.5 (`ASSEMBLER-PATH` variable) is **deleted**. Story 13.6 (first-`CODE` lazy-load hook — north-star capstone) is **deleted**. Story 13.7 (Phase-2 release gate) loses its lazy-load latency measurement and north-star-demo acceptance test; the story survives as the Phase-2 regression + BDOS-audit + ROM-delta gate. |

### Artifact Conflicts

| Artifact | Changes required |
|---|---|
| `prd.md` | Remove FR45–FR49 (System Extensibility & Self-Hosting subsection). Remove NFR3 (first-`CODE` lazy-load latency) and NFR22 (lazy-load default path). Revise NFR5 (kernel ROM footprint — net shrink target no longer achievable once opcodes stay resident and Phase-2 machinery is added; re-state as per-epic budget discipline without a "strictly smaller than pre-phase" gate). Remove "north-star demo" references from Executive Summary, Success Criteria, MVP section, User Journey 1, Journey Requirements Summary table, Measurable Outcomes table, MVP Feature Set table, Installation & Distribution, Runtime Model (post-2.0 boot flow), Implementation Considerations, and Risk Mitigation Strategy. Update FR total count 52 → 47. |
| `architecture.md` | Remove E13-D4 (`ASSEMBLER-PATH` USER variable) and E13-D5 (first-`CODE` lazy-load hook) decisions. Remove `src/lazy_load.asm` from project structure tree. Remove lazy-load data-flow diagram. Remove Finding 3 (`ASSEMBLER.FTH` size budget). Drop E12-D1 → E13-D5 and `ASSEMBLER.FTH` → Epic-13-capstone prerequisites. Remove FR45–49 / NFR3 / NFR22 coverage rows. Update Epic 12 touched-files note on `src/assembler.asm` (no more "remove opcodes" edit). Update Epic 13 touched-files (remove `src/lazy_load.asm`; remove `ASSEMBLER.FTH` shipping). Update build section (no `ASSEMBLER.FTH` in release disk image). Update Epic 13 hardware-validation step (no `ASSEMBLER.FTH` copy to device). |
| `epics.md` | Intro: remove Epic 12 ASSEMBLER.FTH / Finding 3 summary line. Remove FR45–49, NFR3, NFR22 from rollup. Remove `lazy_load.asm` from Files Touched. Remove `ASSEMBLER.FTH` from Disk Image reference. Remove E12 ASSEMBLER.FTH prereq and E13-D4/D5 dependency edges. Epic 12 overview: remove `ASSEMBLER.FTH` from title description. Epic 13 overview: rename from "File-Access with Lazy-Load Capstone" to "File-Access"; rewrite intro without capstone. **Delete Story 12.7 in full.** Rewrite Story 12.6 AC language that presumed Story 12.7 would later relocate opcodes. Adjust Story 12.8 ROM-delta AC. **Delete Story 13.5 in full.** **Delete Story 13.6 in full.** Rewrite Story 13.7 — drop lazy-load latency measurement and north-star-demo acceptance test; keep FS-stress + BDOS audit + ROM-delta accounting + full Phase-2 regression gate. Renumber remaining stories in Epic 12 (12.8 → 12.7) and Epic 13 (13.7 → 13.5) for contiguity (no implementation work has been started on any of these stories — renumbering is safe). |
| `sprint-status.yaml` | Remove `12-7-assembler-fth-authorship-full-migration-of-all-opcodes`. Rename `12-8-...` → `12-7-...`. Remove `13-5-assembler-path-user-variable-and-path-resolver`. Remove `13-6-first-code-lazy-load-hook-north-star-capstone`. Rename `13-7-epic-13-lazy-load-latency-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4` → `13-5-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4`. |
| `product-brief-antforth-2026-04-14.md` | Historical planning artefact. Lazy-load narrative in the Phase-2 goals and "mo's afternoon" climax remains as the record of the *plan-as-it-stood-on-2026-04-14*. **No edits** — this proposal document supersedes it for subsequent planning. |
| `implementation-readiness-report-2026-04-14.md` | Historical. Will be regenerated when the next implementation-readiness check is run. No edits. |

### Technical Impact

- `src/assembler.asm` — **no changes in this phase**. Continues to hold all 168+ opcode words. Epic 12 Story 12.6 wires the existing words under a freshly-created `ASSEMBLER` wordlist struct and adds the `CODE`/`END-CODE` search-order activation/deactivation around them. No opcode word definitions move.
- `examples/ASSEMBLER.FTH` — **not created**.
- `src/lazy_load.asm` — **not created**.
- No changes to the MicroBeast release disk image workflow beyond shipping a single `ANTFORTH.COM`.
- **NFR5 consequence.** Pre-phase Epic-8 baseline is the reference for kernel size. Phase-2 additions (double-cell arithmetic primitives, pictured-output buffer + words, CATCH/THROW machinery + exception-frame chain, per-wordlist hash layout + Search-Order, FCB pool + File-Access wordset) will grow the kernel. The old NFR5 ("strictly smaller than pre-phase baseline") assumed these additions would be offset by removing ~168 opcodes. With opcodes retained, the net effect is kernel growth. NFR5 is revised to a per-epic tracking discipline without an absolute net-negative target — the budget is maintained, the gate is relaxed.

---

## Section 3: Recommended Approach

### Path forward: **Direct Adjustment** (PRD + Architecture + Epics + Sprint-Status surgically edited, no rollback, no MVP review)

**Rationale.**

- **No implementation work to roll back.** Epic 12 and Epic 13 are both `backlog`; no stories have been started. The only in-flight work is Epic 9, which is entirely unaffected. Rollback (Option 2) has nothing to roll back.
- **MVP review (Option 3) is unnecessary.** The two headline Phase-2 goals — 100% ANS Core compliance and on-device source development via CP/M — are both fully preserved. The only thing being removed is a capstone *demonstration* that tied them together through an orthogonal mechanism (lazy-load). All 11 Core-compliance FRs, all 13 File-Access FRs, all 7 exception FRs, all 9 vocabulary FRs, all 9 numeric-prefix FRs, and all 3 regression FRs are unchanged.
- **Timeline / risk improve.** Epic 12 loses its single largest risk (Story 12.7 "ASSEMBLER.FTH authorship — research project, not a task" was flagged Medium-likelihood × High-impact in the PRD risk table). Epic 13 loses the lazy-load hook, the path resolver, and the associated 3-second NFR. Both epics become smaller and more mechanical.
- **Kernel-size trade-off is the user's call.** The only goal that genuinely regresses is NFR5 (net kernel shrink). The project lead's direction implicitly accepts this — the guidance was "all other goals remain the same" and NFR5 was predicated on an eliminated mechanism. NFR5 is revised to maintain per-epic tracking discipline without the net-negative gate.

**Effort estimate (Phase-2 net):** **Savings**, not cost.
- Epic 12: −1 story (12.7), smaller Story 12.6, smaller Story 12.8 (renumbered to 12.7) — net ~30–40% less Epic-12 work.
- Epic 13: −2 stories (13.5, 13.6), simpler Story 13.7 (renumbered to 13.5) — net ~30% less Epic-13 work.
- PRD/Architecture/Epics edits: ~1–2 hours of document surgery.

**Risk.** Low. No implementation rework. Edits are mechanical (deletions + small rewrites). Adjacent Phase-2 stories are unaffected. Real risk is documentation drift — mitigated by editing all four cross-referencing documents in the same pass.

**Timeline impact.** Phase-2 completes sooner (2 stories eliminated, 1 simplified). 2.0 release still gated on 100% Core compliance, CATCH/THROW, Search-Order, and File-Access — all of which are intact.

### Alternatives considered and rejected

- **Option 2: Rollback.** Nothing to roll back — all affected stories are still `backlog`.
- **Option 3: MVP review.** Not warranted — no core Phase-2 goal is being withdrawn, only the capstone demonstration.
- **Keep Story 12.7 as optional.** Rejected — the project lead was explicit ("do not create ASSEMBLER.FTH").
- **Keep `ASSEMBLER-PATH` variable for future re-introduction.** Rejected — YAGNI; the variable has no consumer without the lazy-load hook.

---

## Section 4: Detailed Change Proposals

### 4.1 PRD (`_bmad-output/planning-artifacts/prd.md`)

#### 4.1.1 Executive Summary — remove north-star paragraph

**OLD** (lines 58–63):

```
The phase pursues two mutually reinforcing goals:

1. **100% ANS Forth Core compliance** — [...]
2. **On-device source development via the CP/M filesystem** — [...]

The phase's acceptance criterion is a single capstone demo (the "north-star demo"): a fresh-booted kernel in which the assembler opcodes are *absent* from the dictionary, until the user's first `CODE` triggers a transparent on-demand load of `ASSEMBLER.FTH` from the current drive (or from the path in `ASSEMBLER-PATH` if overridden). That demo exercises every piece of new infrastructure built during the phase — numeric literal prefixes, Core gap words, CATCH/THROW, multi-vocabulary Search-Order, and File-Access — in one coherent story. Shipping it tags the 2.0 release.
```

**NEW:**

```
The phase pursues two mutually reinforcing goals:

1. **100% ANS Forth Core compliance** — driving from the current ~86% to full coverage, the headline credibility win for prospective users of the project
2. **On-device source development via the CP/M filesystem** — unblocking the edit / test / persist cycle directly on the MicroBeast hardware, the personal success moment for the project's primary persona

The phase ships as antforth 2.0 when both goals are met and all inter-epic infrastructure (numeric literal prefixes, Core gap words, CATCH/THROW, multi-vocabulary Search-Order + `ASSEMBLER` wordlist, File-Access) is operational and exercised by REPL-piped Forth test scripts against a real MicroBeast. The built-in Z80 assembler (Epics 4 / 4.3.5 / 4.4) is retained unchanged in Phase 2 and is simply wired under the new `ASSEMBLER` wordlist.
```

Rationale: removes the north-star capstone framing; preserves both goals and the acceptance surface.

#### 4.1.2 What Makes This Special — remove self-hosting insight bullet

**OLD** (line 69):

```
- **Core insight driving this phase:** Forth's self-hosting nature, combined with on-device file access, lets the kernel ROM get *smaller* as the system gets *more capable* — each feature moved out of ROM into Forth source on disk is another thing users can inspect, modify, and extend. antforth 2.0 is the first release where this direction of travel is visible in the product itself.
```

**NEW:** *(delete this bullet entirely)*

Rationale: the specific mechanism (lazy-load of `ASSEMBLER.FTH`) is gone; no other Phase-2 work moves code from ROM to disk. The direction-of-travel claim would be aspirational without a concrete instantiation in this phase.

#### 4.1.3 Success Criteria — User Success (OG)

**OLD** (line 87):

```
- User defines `CODE` words using the inline assembler without noticing that it is now lazy-loaded from disk (the load pause is imperceptible or single-second order on first use, zero on subsequent uses within a session)
```

**NEW:**

```
- User defines `CODE` words using the inline assembler; opcode words are visible only inside `CODE`/`END-CODE` thanks to the `ASSEMBLER` wordlist auto-activation, and invisible outside (no accidental opcode-word collisions with user words)
```

#### 4.1.4 Success Criteria — Technical Success bullets

**OLD** (line 116):

```
- **North-star demo passes end-to-end:** assembler opcodes absent from the fresh-boot dictionary; first `CODE` triggers transparent on-demand load of `ASSEMBLER.FTH` from the current drive (or `ASSEMBLER-PATH` override); subsequent CODE-word definitions assemble identically to pre-phase behaviour
```

**NEW:** *(delete bullet)*

**OLD** (line 119):

```
- **Kernel ROM footprint decreases** by the end of Epic 13 relative to the pre-phase baseline — the system concretely demonstrates the "kernel shrinks, capability grows" direction of travel
```

**NEW:**

```
- **Kernel ROM footprint tracked per-epic** with a strict per-epic budget; any growth is justified against the Phase-2 capability added in that epic (see NFR5)
```

Rationale: retaining the assembler opcodes and adding doubles / pictured / CATCH / Search-Order / File-Access mechanically grows the kernel. Budget discipline is preserved; the net-negative gate is not.

#### 4.1.5 Measurable Outcomes table

**OLD** (lines 131, 133):

```
| Assembler opcodes in kernel ROM | Baked in | Lazy-loaded from disk on demand |
| [...]
| Kernel ROM footprint | Current size | Strictly smaller |
```

**NEW:**

```
| Assembler opcodes | Baked into kernel dictionary | Baked into kernel, reachable under `ASSEMBLER` wordlist inside `CODE`/`END-CODE` |
| [...]
| Kernel ROM footprint | Current size | Tracked per-epic; per-epic budgets maintained |
```

#### 4.1.6 MVP section — remove north-star clause

**OLD** (line 140):

```
The **antforth 2.0** release (end of Epic 13) is the MVP for this phase. It ships when all items listed under *Technical Success* above pass as acceptance criteria. Any subset that excludes the north-star demo (lazy-loaded assembler end-to-end) does not constitute MVP delivery — partial compliance without the capstone demo leaves the infrastructure unjustified.
```

**NEW:**

```
The **antforth 2.0** release (end of Epic 13) is the MVP for this phase. It ships when all items listed under *Technical Success* above pass as acceptance criteria — specifically: 100% ANS Core compliance, CATCH/THROW with full internal-error migration, Search-Order + `ASSEMBLER` wordlist auto-activation (with all pre-phase CODE sources assembling unchanged), File-Access operational against CP/M 2.2, numeric-literal prefixes system-wide, and all Epic 1–8 regressions intact.
```

#### 4.1.7 Journey 1 — full rewrite (removes lazy-load narrative)

**OLD** (lines 172–182): the "First `CODE` After 2.0" journey is entirely about the lazy-load revelation.

**NEW:** A rewritten journey that demonstrates the on-device development workflow without the lazy-load mechanism. Uses `INCLUDE` for a source file, `CODE` for an inline opcode definition (opcodes visible thanks to wordlist auto-activation), and `SAVE-SOURCE` for persistence. Climax is the edit/test/persist cycle on the device itself, not the first-`CODE` disk blink.

```
### Journey 1 — Mo's On-Device Session (OG, happy path)

**Opening scene.** Mo has been building and hacking on 8-bit machines for thirty years. She helped eight other people on the MicroBeast forum build their own kits. She's been following antforth's development on the project's Discord and downloaded the 2.0 release this morning. She boots it cold on her MicroBeast.

**Rising action.** The banner reads `antforth 2.0 — ok`. Second nature: she types `HEX`, then `: BLINK 0xF0 @ 1 XOR 0xF0 ! ;`. Hits return. `ok`. She types `BLINK BLINK BLINK` and sees the LED on the bench flick three times. No disk activity — the opcode definitions live in the kernel as they always have, but now they're only visible inside `CODE`/`END-CODE` thanks to the `ASSEMBLER` wordlist's auto-activation. Outside a `CODE` block, her user words can't collide with opcode names anymore.

**Climax.** She loads her own work-in-progress driver from B: with `INCLUDE B:SPRITES.FTH`, picks up where she left off yesterday. Edits a word at the REPL — `MARKER -OLD`, redefines, tests. It works. Saves the updated source back to B: with `SAVE-SOURCE`. Tomorrow she'll `INCLUDE` it again. The machine is finally a development environment, not a relic.

**Resolution.** Later in the afternoon, a bug in her ring-buffer code surfaces. Instead of the ABORT that would have wiped her session on pre-2.0 antforth, she wraps the failing word in `CATCH`, gets a clean error code back, fixes the issue, re-tests — all without losing her dictionary. Errors are survivable.

**Requirements surfaced:** Epic 9 (hex prefixes in her CODE definition), Epic 11 (CATCH for error survivability), Epic 12 (`ASSEMBLER` wordlist auto-activation, no opcode leakage outside `CODE`/`END-CODE`), Epic 13 (`INCLUDE` / `SAVE-SOURCE` for on-device edit/test/persist).
```

#### 4.1.8 Journey Requirements Summary table

**OLD** (line 231):

```
| Transparent lazy-load of ASSEMBLER.FTH on first CODE | ✓ | | | | Epic 13 (capstone) |
```

**NEW:** *(delete row)*

#### 4.1.9 Installation & Distribution

**OLD** (line 263):

```
- **Installation:** copy `.COM` (and, post-2.0, `ASSEMBLER.FTH`) to the same CP/M drive (typically A: ROM or B: ramdisk) via whatever file-transfer mechanism the user has available (serial transfer, EPROM programmer, SD-card adapter, etc.). The `.COM` and `.FTH` must live on the same drive unless the user sets `ASSEMBLER-PATH` explicitly.
```

**NEW:**

```
- **Installation:** copy `ANTFORTH.COM` to a CP/M drive (typically A: ROM or B: ramdisk) via whatever file-transfer mechanism the user has available (serial transfer, EPROM programmer, SD-card adapter, etc.). Single-file install.
```

#### 4.1.10 Runtime Model — Boot flow

**OLD** (lines 269–270):

```
- **Boot flow (pre-2.0):** `.COM` loaded by CP/M → banner → REPL prompt. Full assembler opcodes baked into the dictionary from ROM
- **Boot flow (post-2.0):** `.COM` loaded by CP/M → banner → REPL prompt. Assembler opcodes absent from the dictionary; on first `CODE`, the system resolves the `ASSEMBLER-PATH` variable (defaulting to `ASSEMBLER.FTH` on the current drive, per BDOS function 25), opens the file via `INCLUDED`, and populates the `ASSEMBLER` wordlist transparently
```

**NEW:**

```
- **Boot flow:** `.COM` loaded by CP/M → banner → REPL prompt. Assembler opcodes baked into the kernel dictionary, reachable under the `ASSEMBLER` wordlist (auto-activated inside `CODE`/`END-CODE`). Unchanged across pre-2.0 and 2.0.
```

#### 4.1.11 Implementation Considerations

**OLD** (line 290):

```
- **ROM-size budget:** strict. Each epic must track kernel size delta and justify increases; Epic 13's lazy-load pattern is expected to *reduce* kernel size net-of-additions
```

**NEW:**

```
- **ROM-size budget:** strict per-epic. Each epic logs its kernel-size delta and justifies increases against the Phase-2 capability added. Phase-2 additions will grow the kernel relative to the Epic-8 baseline; size-reduction opportunities are spawned as dedicated follow-up stories (Epic-6 precedent).
```

#### 4.1.12 Risk Mitigation — technical risks table

**OLD** (line 354):

```
| `ASSEMBLER.FTH` authorship (Epic 12) turns out to be a research project, not a task | Medium | High | Epic 12 has a dedicated story for this; if that story runs long, fall back to hand-migration story-by-story rather than build-time extraction |
```

**NEW:** *(delete row)*

**OLD** (line 356):

```
| Kernel ROM footprint grows despite lazy-load — 2.0 ends up bigger than 1.x | Low | Medium | Per-epic ROM-size budget; quarterly size-reduction opportunities spawned as their own stories (as happened in Epic 6) |
```

**NEW:**

```
| Kernel ROM footprint grows materially from Phase-2 additions without offset opportunities | Medium | Low | Per-epic ROM-size budget; size-reduction opportunities spawned as dedicated stories (Epic-6 precedent); the Phase-2 additions are strictly ANS-Core-compliance + standards-grounded capability, not optional features |
```

#### 4.1.13 MVP Feature Set table

**OLD** (lines 318–319):

```
| **Epic 12** | `WORDLIST`, [...]; `ASSEMBLER` wordlist auto-activation; `ASSEMBLER.FTH` authored | Fourth — the lazy-load capstone requires both Search-Order and an `ASSEMBLER.FTH` source file to exist |
| **Epic 13** | Full File-Access wordset; `INCLUDE` / save to B:; **capstone: kernel boots without assembler, lazy-loads `ASSEMBLER.FTH` from the current drive (or `ASSEMBLER-PATH`) on first `CODE`** | Fifth — consumes everything above; the capstone demo tags 2.0 |
```

**NEW:**

```
| **Epic 12** | `WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY`, `FORTH-WORDLIST`; `ASSEMBLER` wordlist created with all built-in opcodes registered; `ASSEMBLER` auto-activation inside `CODE` / `END-CODE`; all pre-phase CODE source files assemble unchanged | Fourth — consumes the exception infrastructure from Epic 11; delivers the vocabulary/namespace capability called out in Mo's and Pete's journeys |
| **Epic 13** | Full File-Access wordset; `INCLUDE` / `SAVE-SOURCE` against B: ramdisk and A: ROM; Phase-2 regression gate; BDOS-function-allow-list audit; ROM-delta accounting | Fifth — consumes everything above; tags antforth 2.0 on pass |
```

#### 4.1.14 Functional Requirements — remove System Extensibility & Self-Hosting subsection

**OLD** (lines 437–445):

```
### System Extensibility & Self-Hosting (Epic 13 capstone)

- **FR45:** [...]
- **FR46:** [...]
- **FR46a:** [...]
- **FR46b:** [...]
- **FR47:** [...]
- **FR48:** [...]
- **FR49:** [...]
```

**NEW:** *(delete subsection heading and all five FR entries — FR45 through FR49)*

Subsequent FR numbering: FR50 → FR45, FR51 → FR46, FR52 → FR47. Total FR count 52 → 47.

Self-validation summary bullet (line 460) updated: "if the system satisfies all 52 FRs [...] 2.0 ships" → "if the system satisfies all 47 FRs [...] 2.0 ships" and remove the "north-star demo passes" phrase.

#### 4.1.15 NFR3 — delete

**OLD** (line 470): the NFR3 "First-`CODE` lazy-load latency" paragraph.

**NEW:** *(delete)*. Renumber NFR4 → NFR3, NFR5 → NFR4, NFR6 → NFR5.

#### 4.1.16 NFR5 (becomes NFR4) — revise

**OLD:**

```
- **NFR5: Kernel ROM footprint.** antforth 2.0 kernel ROM size is **strictly smaller** than the pre-phase (post-Epic-8) baseline. Each epic logs its delta; net-of-all-epics delta is negative. This is the concrete expression of "kernel shrinks, capability grows."
```

**NEW:**

```
- **NFR4: Kernel ROM footprint budget.** Each Phase-2 epic logs its kernel-size delta and justifies any increase against the capability delivered. Net-of-Phase-2 delta is expected to be positive (the new Phase-2 capabilities — double-cell + pictured output, exception wordset, Search-Order, File-Access — all add code that was not in the Epic-8 baseline). Size-reduction opportunities are spawned as dedicated follow-up stories rather than gated per epic.
```

#### 4.1.17 NFR22 — delete

**OLD** (line 501): NFR22 "Lazy-load default path" paragraph.

**NEW:** *(delete)*. Renumber NFR23 → NFR22.

### 4.2 Architecture (`_bmad-output/planning-artifacts/architecture.md`)

#### 4.2.1 Decisions E13-D4 and E13-D5 — delete

Delete the entire "E13-D4: `ASSEMBLER-PATH` USER variable" decision and the entire "E13-D5: First-CODE lazy-load hook" decision including their rationale / alternatives / cross-cutting references. E13-D4 and E13-D5 section IDs are retired.

#### 4.2.2 Phase-2 FR/NFR coverage section

Remove FR45 / FR46 / FR46a / FR46b / FR47 / FR48 / FR49 / NFR3 / NFR22 rows from coverage tables. Update NFR count references accordingly. In the "Decision Impact Analysis" text remove the "E13-D4 → E13-D5" and "E12 ASSEMBLER.FTH → Epic-13 capstone" dependency edges.

#### 4.2.3 Project Structure tree

Remove the `src/lazy_load.asm` entry and the `examples/ASSEMBLER.FTH` entry. Remove the `# [edit] Epic 12 — remove opcodes, move to ASSEMBLER.FTH` comment on the `src/assembler.asm` line — this file is unchanged in Phase 2 except for the wordlist-activation hook added by Story 12.6. Remove the `# [edit] Epic 13 — add ASSEMBLER.FTH to the release disk image builder` comment on the `disk/` entry.

#### 4.2.4 Touched-files table

Epic 12 row: remove "`examples/ASSEMBLER.FTH`" from primary artefacts and remove "`src/assembler.asm` (move opcodes to ASSEMBLER.FTH Forth source)" from touched files. Epic 12 primary artefacts become: `src/wordlists.asm`; `tests/{wordlist,assembler_wordlist}_tests.fth`. Touched files: `src/dictionary.asm` (multi-vocab); `src/hash.asm` (per-wordlist bucket array); `src/assembler.asm` (add `CODE`/`END-CODE` auto-activation hooks only — no opcode migration).

Epic 13 row: remove `src/lazy_load.asm` from primary artefacts; remove `src/assembler.asm` from touched files; remove "ship ASSEMBLER.FTH in release disk image" from touched files. Epic 13 primary artefacts become: `src/file_access.asm`; `tests/file_access_tests.fth`. Touched files: `src/io.asm` (factor BDOS helpers).

#### 4.2.5 Data flow diagram — lazy-load capstone

Delete the "Data flow — lazy-load capstone" sub-section in its entirety (the ASCII flow diagram from `lazy_load.asm` checks, `ASSEMBLER-PATH` resolution, `INCLUDED` call, through Epic 12 wordlist activation).

#### 4.2.6 Build section

Remove "(and, post-Epic 12) `ASSEMBLER.FTH`" parenthetical from the `make` description. Remove "`+ ASSEMBLER.FTH`" from the real-hardware validation step.

#### 4.2.7 Finding 3 — delete

Remove the entire "Finding 3 — NFR3 (lazy-load ≤ 1s) has no ASSEMBLER.FTH size budget" analysis subsection and its resolution entry in the findings summary.

#### 4.2.8 Integration points summary

Remove "**Kernel-vs-Forth source boundary.** Epic 13's lazy-load shifts assembler opcodes from kernel ROM to Forth source on disk. [...]" commentary — no such shift in Phase-2 anymore.

Remove "Lazy-load hook location and `ASSEMBLER-PATH` variable type (blocks Epic 13 capstone)" from the unresolved-then-resolved decisions log.

### 4.3 Epics (`_bmad-output/planning-artifacts/epics.md`)

#### 4.3.1 Intro bullet list

**OLD** (line 7):

```
  - 'Epic 12: ASSEMBLER.FTH authorship becomes a named story with ≤8 KB soft size budget + hand-migration fallback path (Architecture Finding 3; PRD risk table).'
```

**NEW:** *(delete bullet)*

#### 4.3.2 Intro paragraph

**OLD** (line 26):

```
The phase delivers two mutually reinforcing goals — **100% ANS Forth Core compliance** and **on-device source development via the CP/M filesystem** — culminating in the north-star demo (fresh-booted kernel lazy-loads `ASSEMBLER.FTH` on first `CODE`), which tags the 2.0 release.
```

**NEW:**

```
The phase delivers two mutually reinforcing goals — **100% ANS Forth Core compliance** and **on-device source development via the CP/M filesystem**. The built-in Z80 assembler is retained unchanged and is wired under a new `ASSEMBLER` wordlist in Epic 12. The 2.0 release is tagged when the Phase-2 regression gate (Story 13.5, formerly 13.7) passes against a real MicroBeast.
```

#### 4.3.3 FR/NFR roll-up

- Remove FR45 / FR46 / FR46a / FR46b / FR47 / FR48 / FR49 rows from the FR→Epic rollup (around lines 224–228).
- Remove NFR3 and NFR22 from any NFR→Epic listings.

#### 4.3.4 Files Touched

Remove `src/lazy_load.asm` from line 152. Remove `examples/ASSEMBLER.FTH` from line 156.

#### 4.3.5 Dependencies

Remove "E12-D1 (per-wordlist hash layout) prerequisite to E13-D5 (lazy-load hook)" and "E13-D4 (ASSEMBLER-PATH sentinel) prerequisite to E13-D5 (first-CODE hook)" from the dependency list (around lines 173–174). Remove "E12's ASSEMBLER.FTH artefact prerequisite to Epic 13 capstone" from line 261.

#### 4.3.6 Epic 12 overview

**OLD** (line 249 title + description): title `Multi-Vocabulary Search-Order & ASSEMBLER Wordlist`, description includes `ASSEMBLER.FTH` authorship and `≤ 8 KB` soft budget.

**NEW:** title unchanged; description rewritten to remove `ASSEMBLER.FTH` / soft budget / hand-migration fallback language. Delivers Search-Order wordset plus `ASSEMBLER` wordlist creation with the existing opcode words registered and auto-activation around `CODE`/`END-CODE`. Shippable as antforth 1.12.

#### 4.3.7 Epic 13 overview

**OLD** (line 253): title `File-Access with Lazy-Load Capstone`, description includes the lazy-load capstone as the 2.0 gate.

**NEW:** title `File-Access`. Description: Full ANS File-Access wordset (`OPEN-FILE`, `CLOSE-FILE`, `READ-FILE`, `WRITE-FILE`, `FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`, `DELETE-FILE`, `CREATE-FILE`, `INCLUDE`, `INCLUDE-FILE`, `INCLUDED`) operational against CP/M 2.2 BDOS, integrated with Epic 11 exception semantics for error paths. Closes with the Phase-2 release gate — full regression of Epics 1–12, BDOS-function-allow-list audit, kernel ROM-delta accounting, and MicroBeast hardware validation. Passing the gate tags antforth 2.0.

#### 4.3.8 Epic sequencing paragraph

**OLD** (line 261):

```
Epic 9 → Epic 10 → Epic 11 → Epic 12 → Epic 13, per Architecture §Decision Impact Analysis. Dependencies: CCD-1 prerequisite to Epic 11 and Epic 13; E11-D1 prerequisite to E13-D2; E12-D1 prerequisite to E13-D5; E12's ASSEMBLER.FTH artefact prerequisite to Epic 13 capstone. Each epic independently shippable as an `antforth 1.x` release per NFR19.
```

**NEW:**

```
Epic 9 → Epic 10 → Epic 11 → Epic 12 → Epic 13, per Architecture §Decision Impact Analysis. Dependencies: CCD-1 prerequisite to Epic 11 and Epic 13; E11-D1 prerequisite to E13-D2. Each epic independently shippable as an `antforth 1.x` release per NFR19 (now NFR18).
```

#### 4.3.9 Story 12.6 — revise AC language

In the AC that reads "at this story's completion it is still populated with opcode words built into the kernel (Story 12.7 moves them to `ASSEMBLER.FTH`)" (around line 1097): replace with "at this story's completion the `ASSEMBLER` wordlist is populated with the opcode words defined in `src/assembler.asm`; the opcodes remain kernel-resident for the life of Phase 2 — no relocation to a Forth-source file is planned." Correspondingly remove the NFR15 / Story 12.8 reference to "full coverage in Story 12.8" if Story 12.8 is renumbered (see below).

#### 4.3.10 Story 12.7 — delete

Delete the entire "### Story 12.7: `ASSEMBLER.FTH` authorship — full migration of all opcodes" section including all its ACs (around lines 1115–1150).

#### 4.3.11 Story 12.8 (becomes 12.7) — revise

Remove the sub-point (around line 1177) that reads "a material reduction is measured — all 168+ ASSEMBLER opcodes have moved out of `src/assembler.asm` into `examples/ASSEMBLER.FTH` per Story 12.7". Replace with "the Epic-12 kernel-size delta is positive (Search-Order + wordlist auto-activation machinery adds code; no offsetting migration) and is justified line-by-line against the Search-Order capability delivered." Renumber heading `### Story 12.8:` → `### Story 12.7:`.

#### 4.3.12 Story 13.5 — delete

Delete the entire "### Story 13.5: `ASSEMBLER-PATH` USER variable + path resolver" section (around lines 1335–1365).

#### 4.3.13 Story 13.6 — delete

Delete the entire "### Story 13.6: First-`CODE` lazy-load hook (north-star capstone)" section (around lines 1367–1405).

#### 4.3.14 Story 13.7 (becomes 13.5) — revise

Renumber heading `### Story 13.7:` → `### Story 13.5:`. Rewrite the story title to drop "lazy-load latency" — new title: `### Story 13.5: Epic 13 FS stress, BDOS audit, ROM delta + antforth 2.0 release gate (CCD-4)`. Remove the NFR3 lazy-load-latency measurement AC. Remove the "north-star demo as an executable test (per `tests/lazy_load_tests.fth`)" AC. Keep: filesystem-error stress suite (NFR9), BDOS-function-allow-list audit (NFR14), ROM delta accounting for the phase as a whole (NFR4, formerly NFR5), and the full Epic 1–12 regression pass on real MicroBeast hardware.

### 4.4 Sprint status (`_bmad-output/implementation-artifacts/sprint-status.yaml`)

Replace the Epic 12 and Epic 13 blocks (lines 141–160) with:

```yaml
  epic-12: backlog
  12-1-wordlist-struct-hash-parameterisation-and-forth-wordlist-bootstrap: backlog
  12-2-wordlist-and-search-wordlist: backlog
  12-3-search-order-infrastructure: backlog
  12-4-compilation-wordlist-control: backlog
  12-5-only: backlog
  12-6-assembler-wordlist-and-auto-activation-in-code-end-code: backlog
  12-7-epic-12-benchmark-code-backward-compat-suite-and-regression-gate-ccd-4: backlog
  epic-12-retrospective: optional

  epic-13: backlog
  13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer: backlog
  13-2-core-file-access-wordset: backlog
  13-3-file-positioning: backlog
  13-4-source-input-nesting-include-top-chain-discipline: backlog
  13-5-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4: backlog
  epic-13-retrospective: optional
```

(Old 12-7 deleted, old 12-8 renumbered to 12-7. Old 13-5 and 13-6 deleted, old 13-7 renumbered to 13-5.)

---

## Section 5: Implementation Handoff

**Scope classification:** **Moderate** — backlog reorganisation across PRD / Architecture / Epics / Sprint-Status, no implementation rework, two stories deleted, two stories renumbered.

**Handoff plan** (single-developer project — all roles are the project lead):

1. **Product lead (Ant) — approve this proposal.** *(Gating step.)*
2. **Apply PRD edits** per §4.1 — `_bmad-output/planning-artifacts/prd.md`.
3. **Apply Architecture edits** per §4.2 — `_bmad-output/planning-artifacts/architecture.md`.
4. **Apply Epics edits** per §4.3 — `_bmad-output/planning-artifacts/epics.md`.
5. **Apply Sprint-Status edits** per §4.4 — `_bmad-output/implementation-artifacts/sprint-status.yaml`.
6. **Update `auto memory` entry** `project_phase2_scope.md` to reflect the revised scope (assembler stays kernel-resident; Epics 12 and 13 simpler; NFR5 relaxed to per-epic discipline).
7. **Continue Epic 9** without changes — Story 9.3 is next up per sprint status, and numeric-prefix reach into the assembler source (Story 9.5) still applies.

**Success criteria for this course-correction:**

- All five documents edited consistently — no remaining reference to `ASSEMBLER.FTH`, `ASSEMBLER-PATH`, `lazy_load.asm`, FR45–FR49, NFR3, or NFR22 outside the archived planning artefacts.
- Epic 12 has 7 stories (was 8). Epic 13 has 5 stories (was 7). Total Phase-2 stories: 32 (was 35).
- Sprint-status.yaml YAML parses cleanly and sprint-status commands reflect the new numbering.
- `bmad-bmm-check-implementation-readiness` run against the revised docs reports no orphan FRs, no orphan stories, no dangling decision IDs.
