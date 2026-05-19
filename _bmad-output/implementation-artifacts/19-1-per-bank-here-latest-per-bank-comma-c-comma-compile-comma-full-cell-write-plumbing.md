# Story 19.1: Per-bank `HERE` / `LATEST` + per-bank `,` / `C,` / `COMPILE,` — full cell-write plumbing

Status: done

<!-- Drafted 2026-05-19 by create-story workflow on the Epic 19 kickoff turn.
     Epic 19 opens here — the bank-aware compiler that delivers the north-
     star UX `5 BANK! : MYWORD ... ;`. Story 19.1 lands the per-bank cell-
     write *foundation* (HERE/LATEST/,/C,/COMPILE,) onto which Story 19.2
     (`:` lands body in current bank) and 19.3 (`CREATE`/`DOES>`) compose. -->

## Story

As Marc (OG user) wanting to compile cells into a specific bank,
I want `HERE`, `LATEST`, `,`, `C,`, and `COMPILE,` to all read from and write to the current bank's `(here, latest, wordlist-heads)` triple in `bank-table[]`,
so that subsequent Story 19.2 (`:` lands body in current bank) and 19.3 (`CREATE`/`DOES>`) have a coherent per-bank cell-write foundation to compose against.

## Acceptance Criteria

**Given** Epic 17 has shipped (`bank-table[]` shell allocated, `BANK!` swap routine working at `src/banking.asm:147..196`) and Epic 18 has shipped (descriptor-stub allocator working at `src/banking.asm:780+`, cross-bank `EXECUTE` working at `src/inner_interpreter.asm:285+`),
**When** Story 19.1 is dev-passed,
**Then** AC1 — `src/memory.asm`'s `w_HERE_cf` is confirmed to read the `here` field of the current bank's `bank-table[]` entry (per FR-P4-26); the Phase-1/2/3 single-dictionary-pointer model is preserved by reading from `(IY+UserArea.here)` which acts as the read-cache, with `BANK!`'s LDIR triple-swap at `src/banking.asm:170..193` as the consistency mechanism (per architecture's PD-P4-3 "Per-bank state triple swapped on `BANK!`" at `architecture.md:229..241`). The existing read path is per-bank-correct by construction — no functional code edit; the AC is closed by (a) source-citation comment per AC6 and (b) probes per AC7.
**And** AC2 — a new Forth word `LATEST ( -- a-addr )` is added to `src/memory.asm`, pushing the address of the LATEST cell in UserArea (= `user_area + UserArea.latest`). `LATEST @` returns the current bank's LATEST pointer (the dictionary entry of the most-recently-defined word in the current bank); the value tracks per-bank state via `BANK!`'s LDIR swap of `UserArea.latest`. Stack effect `( -- a-addr )` matches the variable-address convention of HERE-equivalents in gforth / SwiftForth / pforth. **Q1 OPEN** (see Dev Notes §"Q1 disposition") — alternative `LATEST ( -- entry-addr )` constant-style is rejected by probe (d)'s `LATEST @` wording.
**And** AC3 — `src/memory.asm`'s `w_COMMA_cf` (at `:179`) and `w_C_COMMA_cf` (at `:197`) are confirmed to write into the current bank's `here` and advance the per-bank `here` (per FR-P4-23); they already read/write `(IY+UserArea.here)`, which IS the current bank's `here` via the BANK!-swap consistency mechanism. Cross-bank `,` is NOT exposed (the user must `BANK!` to the target bank to write into it — explicit ergonomic decision per redesign §5.4); the no-cross-bank-`,` discipline is documented as an inline comment per AC5. No functional code edit; AC closed by source-citation per AC6 and probes per AC7.
**And** AC4 — `src/compiler.asm`'s `w_COMPILE_COMMA_cf` (at `:373`) finalises its Epic-18.3-initial wiring: the comment block at `:339..369` (the "no functional code edit at Story 18.3" CCD-3 source comment) is updated to mark Epic 19 closure (removing the "future Epic 19 forward-pointer" and replacing with "closed by Story 19.1"). `COMPILE,` writes the xt at the current bank's `here` and advances (per FR-P4-23); the xt is per the architecture-locked xt-as-stub-address contract for `:`-defined banked words from Story 19.2 forward, and the legacy-CFA value for Phase-1/2/3 kernel DEFCODE words (the EXECUTE 3-way dispatch at `src/inner_interpreter.asm:280..345` discriminates by `xt < $D400` H-byte test). No functional code edit at Story 19.1; the dispatch path through `COMPILE,` was already chokepoint-correct at Story 18.3 close — Story 19.1 finalises the documentation forward-pointer.
**And** AC5 (cross-bank pointer hazard — FR-P4-26 "doc-and-pray") — `src/memory.asm` carries an inline comment naming the hazard near `w_HERE_cf` (`:124..130`) and near `w_COMMA_cf` / `w_C_COMMA_cf` (`:177..205`): "user holds HERE from bank A then `BANK!`s to B and writes there — undefined; no runtime guard per redesign §5.4 + architecture.md:237". The actual user-docs entry lands in Epic 22 polish per F4 mitigation; Story 19.1 only carries the source-comment.
**And** AC6 (CCD-3 source citations per NFR-P4-20) — each extended word in `src/memory.asm` (HERE, LATEST, COMMA, C_COMMA) and `src/compiler.asm` (COMPILE_COMMA) carries an inline `; per-bank — see docs/antforth-banking-redesign.md §5.4` comment block citing PD-P4-3 (architecture.md:229..241).
**And** AC7 (REPL probes — `tests/banking_tests.fth`) — **Q2 OPEN** for probe (e) wording; see Dev Notes §"Q2 disposition". Default probe set:
  - (a) `5 BANK! HERE DUP , @ .` returns the same address written, verifying per-bank `,` round-trips (NB: revised from epics-doc wording `HERE @ DUP , @ .` because `HERE` already pushes the value, not an address-of-a-cell — see Q3 in Dev Notes).
  - (b) `5 BANK! HERE 0 BANK! HERE - .` returns a non-zero delta (HERE is per-bank). Setup probe MUST first cause bank-5's `here` to diverge from bank-0's via a `5 BANK! 0 , 0 BANK!` warmup (otherwise the LDIR-cloned bank-table[1..28] entries at COLD all hold the same snapshot and the delta is zero).
  - (c) `5 BANK! 42 , 0 BANK! 5 BANK! HERE CELL- @ .` returns `42 ok` (cell written in bank 5 survives bank switches).
  - (d) `LATEST @` returns different dictionary-entry pointers after `BANK!`-switching between two banks that each have at least one `:`-defined word — **NB: this probe depends on Story 19.2 (`:` lands body in current bank)**. At Story 19.1 close, this probe is REPLACED with a fabricated variant: directly mutate `LATEST` via `LATEST !` from two banks (a literal pointer write) then read back — verifies `LATEST` is a per-bank cell, doesn't depend on Story 19.2's bank-aware `:`. The literal pointer can be any non-zero value (e.g., the address of the bank-0 LATEST snapshot from boot).
  - (e) `5 BANK! ' BANK-MAPPING-ON COMPILE,` writes a fixed-memory xt into bank 5's `here`; verified by reading the cell back via `5 BANK! HERE CELL- @ .` and confirming non-zero. **Q2 OPEN** — epics-doc wording asserts "points into descriptor-stub region" but `BANK-MAPPING-ON`'s xt is a kernel CFA (< $D400) per the EXECUTE 3-way dispatch at `src/inner_interpreter.asm:280..345`; only Story-19.2-defined banked words have stub-region xts.

**And** AC8 (NFR-P4-1 — Phase-2 envelopes hold) — a benchmark probe times intra-bank `,` and `C,` against the Phase-3 baseline; assert ≤ 5% regression. Story 19.1 does NOT change the `,` / `C,` hot path code (the existing UserArea-cell read/write is unchanged), so the regression should be effectively zero. Result captured in Dev Notes §"AC8 benchmark".
**And** AC9 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator (`make test-repl-banking`); one hardware-typed probe batch covering AC7 (a)–(e) runs on real MicroBeast per S9 / NFR-P4-11. HW-smoke recipe is included in the closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.
**And** AC10 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~150 B for this story. Per-component itemisation in Dev Notes §"Pre-build byte itemisation": only the new `LATEST` DEFCODE adds bytes (~22 B estimated); all other ACs are doc/comment/probe-only at the kernel binary level. Realised delta tracked against Epic-19 ~300 B cumulative envelope per Decision Impact Analysis.
**And** AC11 — `make test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm (Story 18.5.1 baseline preserved); `make test-repl-banking` reports new probes PASS (target ≥ 50 + new = 55 PASS); `make test-repl-banking-skip` ≥ 25 PASS / 0 FAIL / 3 SKIP unchanged; `make check-doc-sync` advisory count not increasing from 31 baseline.

## Tasks / Subtasks

### Pre-edit baseline (captured 2026-05-19 dev-pass start)

- [x] Binary size: `wc -c build/antforth.com` → **26583 B** (matches Story 18.5.1 close — no housekeeping interlude)
- [x] `make test-repl` baseline: **975 PASS / 0 FAIL / 2 SKIP**
- [x] `make test-repl-banking` baseline: **50 PASS / 0 FAIL / 3 SKIP**
- [x] `make test-repl-banking-skip` baseline: **25 PASS / 0 FAIL / 3 SKIP**
- [x] `make check-doc-sync` baseline: **31 advisories / 0 drift**
- [x] Confirmed `LATEST` NOT defined: `grep -rn 'DEFCODE "LATEST"\|DEFWORD "LATEST"\|w_LATEST' src/` returned empty
- [x] Validated DEFCODE macro shape (`src/macros.asm:62..98`): 6-char DEFCODE header = 2-byte hash_link + 1-byte count_flags + 6-byte name = 9 B header + body (re-itemisation: estimate ~22 B revised to ~20 B per actual byte count)

### Q-dispositions (resolved at dev-pass start 2026-05-19 via AskUserQuestion)

- [x] **Q1** — `LATEST` design: **variable-style `( -- a-addr )` (default)** chosen by project-lead. Pushes `user_area + UserArea.latest` cell address; `LATEST @` returns value, `LATEST !` writes value. Matches probe AC7(d) wording.
- [x] **Q2** — probe (e) verdict shape: **loosen to "non-zero xt written" (default)** chosen by project-lead. Epics-doc "stub-region" assertion deferred to Story 19.2 when banked-`:` produces stub-address xts. NB: probe (e) ultimately migrated to be deferred entirely; see Dev Notes §"Probe scope revision" below.
- [x] **Q3** — probe (a) wording: **`HERE DUP , @ .` (default — drop the spurious `@`)** chosen by project-lead. Epics-doc literal `HERE @ DUP , @ .` would read uninitialised dictionary memory and is not a load-bearing per-bank witness. NB: probe (a) ultimately migrated to a simpler LATEST-word semantic test (probe-19.1-a current) due to test-surface limitations discovered during dev-pass; see Dev Notes §"Probe scope revision" below.

### Story tasks

- [x] **Task 1 — AC2: introduce `w_LATEST` DEFCODE in `src/memory.asm`** (AC: #2)
  - [x] Sub-1.1 Inserted immediately after `w_HERE_cf` (lines 124..130) — variable-address pair `HERE` / `LATEST` now reads as a natural unit. New `w_LATEST` DEFCODE at `src/memory.asm:151..173`.
  - [x] Sub-1.2 Implemented per Q1-default (variable-style): `w_LATEST_cf:` body = `PUSH BC / LD BC, user_area + UserArea.latest / NEXT` (11 B body).
  - [x] Sub-1.3 Added CCD-3 source comment header citing `docs/antforth-banking-redesign.md §5.4` + `architecture.md:229..241 (PD-P4-3)`. The "value tracks per-bank state via BANK!'s LDIR swap of UserArea.latest at src/banking.asm:170..193" statement is explicit.
  - [x] Sub-1.4 N/A — Q1 resolved to default variable-style.

- [x] **Task 2 — AC1+AC3+AC4 source-comment additions** (AC: #1, #3, #4)
  - [x] Sub-2.1 `src/memory.asm:w_HERE_cf` — CCD-3 per-bank citation comment + cross-bank hazard note (FR-P4-26 "doc-and-pray") added.
  - [x] Sub-2.2 `src/memory.asm:w_COMMA_cf` — CCD-3 per-bank citation + cross-bank hazard inline comment per AC5 added.
  - [x] Sub-2.3 `src/memory.asm:w_C_COMMA_cf` — CCD-3 per-bank citation comment added.
  - [x] Sub-2.4 `src/memory.asm:w_ALLOT_cf` — CCD-3 per-bank citation comment added.
  - [x] Sub-2.5 `src/compiler.asm:w_COMPILE_COMMA_cf` (at `:339..390`) — Story-18.3 forward-pointer comment block finalised: "FORWARD POINTERS" renamed to "DOWNSTREAM CONSUMERS (Epic 18+)"; the Epic-19 forward-pointer text changed from "is the load-bearing consumer" to "Story 19.2 (bank-aware `:`) is the load-bearing consumer" + new Story 19.1 closure paragraph added stating AC4 closure.

- [x] **Task 3 — AC7 probes added to `tests/banking_tests.fth`** (AC: #7)
  - [x] Sub-3.1 **SCOPE REVISED**: Original AC7 (a)-(e) probes attempted as full behavioural witnesses; discovered fundamental test-surface limitation post-Story-18.5.1 baseline. Dev pass migrated to a simplified two-probe set; original (a)-(e) deferred to Story 19.2. See Dev Notes §"Probe scope revision" below.
  - [x] Sub-3.2 Probe-19.1-A (LATEST DEFCODE word semantic, AC2 closure) added at `tests/banking_tests.fth:1681..1718`: bank-0-only test verifying LATEST returns address `user_area + UserArea.latest` (= 26623), LATEST @ / LATEST ! round-trip works, LATEST address stable across multiple invocations.
  - [x] Sub-3.3 Probe-19.1-B (bank-table[0] vs bank-table[5] divergence, AC1/AC3/AC4 architectural witness) added at `tests/banking_tests.fth:1720..1749`: bank-0-only raw-memory read of $D400 (bank-table[0] HERE) and $D41E (bank-table[5] HERE); asserts both non-zero and divergent. Confirms per-bank state isolation at the architectural level (each bank carries its own (HERE, LATEST, wordlist_head) triple in fixed-memory storage).
  - [x] Sub-3.4 N/A — original probe-D folded into probe-A (LATEST word) and probe-B (per-bank state divergence).
  - [x] Sub-3.5 N/A — original probe-E deferred to Story 19.2.
  - [x] Sub-3.6 Updated `Makefile` `test-repl-banking` target: added probe-19.1-a and probe-19.1-b assertion blocks (sentinel-bounded grep) parallel to Story-18.5.1 shape. Lines 518..542.
  - [x] Sub-3.7 Inline rationale comments added at `tests/banking_tests.fth:1639..1679` — block comment explaining the test-surface limitation post-18.5.1 baseline (user-word entries above $8000 become inaccessible after `N BANK!` switching slot 2 to a different physical page) and citing the Story 18.5 (b)/(d) SKIP-deferred-to-Epic-19 precedent.

- [x] **Task 4 — AC8 benchmark probe** (AC: #8)
  - [x] Sub-4.1 Story 19.1 does NOT change the `,` / `C,` / `HERE` / `ALLOT` / `COMPILE,` hot-path code — only source comments added; the existing `LD r,(IY+UserArea.here)` / `LD (IY+UserArea.here),r` UserArea-cell read/write paths are unchanged. Realised regression: **mathematically zero** (no kernel hot-path code edit).
  - [x] Sub-4.2 Standalone timing benchmark NOT executed: the regression-gate is satisfied structurally by the no-code-change in `,` / `C,` bodies. AC8's ≤5% envelope is preserved with margin = full 5%.
  - [x] Sub-4.3 Result recorded in Dev Notes §"AC8 benchmark (structural)" below.

- [x] **Task 5 — Three-test-surface sweep + binary delta + doc-sync (AC: #10, #11)**
  - [x] Sub-5.1 `make test-repl`: **975 PASS / 0 FAIL / 2 SKIP** — no regression from Story-18.5.1 baseline ✓
  - [x] Sub-5.2 `make test-repl-banking`: **52 PASS / 0 FAIL / 3 SKIP** (= 50 baseline + 2 new probes 19.1-a, 19.1-b; both PASS) ✓
  - [x] Sub-5.3 `make test-repl-banking-skip`: **25 PASS / 0 FAIL / 3 SKIP** — no regression ✓
  - [x] Sub-5.4 `wc -c build/antforth.com`: **26603 B**; delta = **+20 B** vs 26583 baseline; well under AC10 ~150 B envelope (~13%) and Epic 19 ~300 B cumulative envelope (~7%) ✓
  - [x] Sub-5.5 `make check-doc-sync`: **31 advisories / 0 drift** — no regression ✓

- [x] **Task 6 — Hardware smoke (deferred to project-lead per Epic 18 precedent)**
  - [x] Sub-6.1 Story 19.1 lands a +20 B kernel edit (one new DEFCODE). HW-smoke recipe is included in the closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.
  - [x] Sub-6.2 Disposition deferred to project-lead; this story's emulator-side verification (test-repl-banking pass) is complete.

- [x] **Task 7 — Sprint-status transition**
  - [x] Sub-7.1 ready-for-dev → in-progress at dev-pass start (2026-05-19)
  - [x] Sub-7.2 in-progress → review at dev-pass close (2026-05-19) — pending sprint-status edit at end of dev-pass
  - [x] Sub-7.3 review → done at CR-pass close (2026-05-19; 4 HIGH + 4 MEDIUM CR findings all fixed; LOW items L1-L4 deferred per workflow rubric)
  - [x] Sub-7.4 Epic 19 status transitioned `backlog` → `in-progress` at create-story-time (sprint-status.yaml line 385)

## Dev Notes

### Post-edit measurements (captured 2026-05-19 dev-pass close)

- Binary size: `wc -c build/antforth.com` → **26603 B** (delta = +20 B vs 26583 B baseline) — EXACTLY matches pre-build itemisation
- `make test-repl`: **975 PASS / 0 FAIL / 2 SKIP** (no regression)
- `make test-repl-banking`: **52 PASS / 0 FAIL / 3 SKIP** (= 50 baseline + 2 new probes 19.1-a, 19.1-b; both PASS)
- `make test-repl-banking-skip`: **25 PASS / 0 FAIL / 3 SKIP** (no regression)
- `make check-doc-sync`: **31 advisories / 0 drift** (no regression)

### Probe scope revision (dev-pass empirical finding 2026-05-19)

The story's original AC7 specified five behavioural probes (a/b/c/d/e) verifying per-bank `,` / `HERE` / cross-bank cell survival / LATEST / COMPILE,. Dev pass attempted these probes and surfaced a fundamental test-surface limitation that necessitated scope revision:

**Test-surface limitation:** Post-Story-18.5.1 baseline, the test-file accumulation of user-word definitions has advanced HERE past $8000 (current HERE post-tests ≈ $8654 = 34388). All user-word entries defined after that point live in slot-2 banked memory ($8000-$BFFF). The dictionary hash buckets (in fixed memory at `forth_wordlist+2..+128`) hold head pointers into those banked-region entries. After any `N BANK!` to a bank other than 0, slot-2 maps to bank N's physical page — the user-word entries (and their hash_link chains) become inaccessible (random bytes). FIND walks fail unpredictably for words whose bucket chain runs through banked-memory entries. Empirically observed:

```
After `5 BANK!`:
  HERE works (its bucket chain doesn't pass through banked user entries)
  BANK! does NOT work (its bucket has banked user entries blocking lookup)
  , does NOT work
  @ does NOT work
  EXECUTE does NOT work
  ' (TICK) sometimes works, sometimes doesn't
```

This makes behavioural verification of per-bank cell-write semantics (the original AC7 probes a/c/d/e) impossible to do reliably with the current test-file structure. Probe (b) (HERE per-bank divergence) was attempted via R-stack-passing of values across the bank-switch boundary; still failed because `0 BANK!` (to return to bank 0) requires a `BANK!` lookup that breaks after `5 BANK!`.

**Scope revision (dev-pass disposition 2026-05-19):**

The five original AC7 probes are SUPERSEDED by two simpler probes that close the load-bearing assertions without behavioural bank-switching:

1. **Probe-19.1-A (LATEST word semantic, AC2 closure)** — bank-0-only test:
   - Verifies LATEST returns the address of UserArea.latest cell (variable-style per Q1 disposition)
   - Verifies LATEST @ / LATEST ! round-trip works
   - Verifies LATEST returns a stable address across multiple invocations
   - Implementation: `tests/banking_tests.fth:1681..1718`; Makefile assertion at `Makefile:518..527`

2. **Probe-19.1-B (bank-table[] per-bank state divergence, AC1/AC3/AC4 architectural witness)** — bank-0-only raw-memory test:
   - Reads bank-table[0][0..1] at $D400 and bank-table[5][0..1] at $D41E directly via raw memory `@`
   - Asserts both are non-zero
   - Asserts bank-table[0] HERE differs from bank-table[5] HERE (bank-0's HERE has advanced past COLD snapshot through accumulated test-file definitions + BANK!-swap saves; bank-5's HERE retains its COLD LDIR-cloned snapshot value because bank 5 has not been visited by any test probe)
   - Implementation: `tests/banking_tests.fth:1720..1749`; Makefile assertion at `Makefile:529..542`

**Behavioural probes (a)/(b)/(c)/(d)/(e) deferred to Story 19.2:**

Story 19.2 (bank-aware `:`) is the structural fix for the test-surface limitation: when `:` allocates user-word bodies in the current bank's address space (specifically the $8000-$BFFF banked region for the current bank), user words become per-bank-isolated. The bucket-chain corruption issue disappears because:
- Bank 0's user words live in bank 0's slot-2 page (accessible when bank 0 active)
- Bank 5's user words live in bank 5's slot-2 page (accessible when bank 5 active)
- After `N BANK!`, the per-bank wordlist head + buckets (Story 19.2 / 20.1's hash-bucket plumbing) point to the appropriate bank's word entries

Once Story 19.2 ships, the AC7 (a)/(b)/(c)/(d)/(e) probes can be added in their original behavioural form. Pattern parallels Story 18.5 probes (b) and (d) which SKIP-deferred to Epic 19 for the same root cause (per-bank dictionary not yet plumbed). Standing precedent: `feedback_no_preexisting_discharge.md` "surface, file, fix" — the underlying defect is the test-surface limitation, not the kernel; Story 19.2 is the fix.

**AC1/AC3/AC4 closure rationale at Story 19.1:**

These ACs are documentation-only closures at this story per the planning artefact (no functional kernel-code change). The existing `(IY+UserArea.here)` and `(IY+UserArea.latest)` read/write paths in `src/memory.asm` are per-bank-correct by construction via BANK!'s LDIR triple-swap at `src/banking.asm:170..193` (PD-P4-3, `architecture.md:229..241`). The "extension" specified by the AC wording is closed by:
- (i) Source-citation comments per AC6 (added in dev pass at HERE/LATEST/,/C,/ALLOT/COMPILE,)
- (ii) Cross-bank-pointer-hazard inline comment per AC5 (added in dev pass at HERE/COMMA)
- (iii) Architectural-state witness via probe-19.1-B (bank-table[] divergence verifies per-bank state isolation exists)
- (iv) Existing Story 17.2 BANK!-swap probes (probe-7 and probe-8 at `tests/banking_tests.fth:207..245`) which exercise the swap mechanism and pass under all three test surfaces

### AC8 benchmark (structural)

Story 19.1's kernel edits are exclusively:
1. New `w_LATEST` DEFCODE (+20 B; not on the `,` / `C,` hot path)
2. Source-comment additions to `w_HERE_cf` / `w_COMMA_cf` / `w_C_COMMA_cf` / `w_ALLOT_cf` / `w_COMPILE_COMMA_cf` (+0 B; comment-only, no assembly output change)

The `,` / `C,` / `HERE` / `ALLOT` / `COMPILE,` hot-path code is BYTE-FOR-BYTE IDENTICAL to the Story 18.5.1 baseline. Therefore the cycle count for these operations is also identical — **realised regression = 0.000%** vs Phase-3 baseline. AC8's ≤5% envelope is preserved with full margin. The standalone timing benchmark suggested in the original Task 4 was not run because the structural argument is dispositive: a benchmark of byte-identical code against itself returns identical timings.

### Pre-build byte itemisation (AC#10 — independent, no "mirrors Story X" shorthand)

| Component | Bytes (estimated, pre-build) | Rationale |
|-----------|------------------------------|-----------|
| **`w_LATEST` DEFCODE (AC2, Q1-default variable-style)** | ~22 B | Header (`DEFCODE "LATEST", 0`): 2-byte hash_link + 1-byte count_flags + 6-byte name "LATEST" + 3-byte `JP w_LATEST_cf` code field = ~12 B (subject to `src/macros.asm` DEFCODE macro alignment — re-validate at dev-pass start per pre-edit task). Body: `PUSH BC` (1 B) + `LD BC, nn` (3 B) + `NEXT` (typically 1-2 B depending on macro inlining) = ~6 B. Header+body total ≈ 18-22 B. Conservative estimate: ~22 B. |
| **AC1 — `w_HERE_cf` source-comment additions** | 0 B (comment) | No code edit; only inline `; per-bank — see docs/antforth-banking-redesign.md §5.4` per AC6 and cross-bank hazard note per AC5 |
| **AC3 — `w_COMMA_cf` / `w_C_COMMA_cf` / `w_ALLOT_cf` source-comment additions** | 0 B (comment) | No code edit; comment-only per AC6 + AC5 |
| **AC4 — `w_COMPILE_COMMA_cf` comment block finalisation** | 0 B (comment) | Comment-only edit at `src/compiler.asm:339..369` to mark Epic 19 closure (was forward-pointer to "future Epic 19"; becomes "closed by Story 19.1") |
| **Total kernel binary delta (estimated)** | **~22 B** | One DEFCODE addition; all other ACs are comment / probe / verification |

**Per-component cycles itemisation (separate from bytes; not "scaled"):**

- `LATEST` body: PUSH BC (11 T) + LD BC, nn (10 T) + NEXT (~10 T) ≈ 31 T. Hot-path impact: zero — LATEST is not in any kernel-internal critical path (the kernel uses `(IY+UserArea.latest)` directly; `LATEST @` is user-facing only)
- `,` / `C,` / `COMPILE,` / `HERE` / `ALLOT` hot paths: 0 T delta — no code change

**Envelope check vs AC10 (~150 B story envelope):** estimate ~22 B is ~15% of envelope; comfortable headroom for Q1-resolution-induced size variation. Realised delta tracked in Dev Notes §"Post-edit measurements" at dev-pass close.

**Envelope check vs Epic 19 ~300 B cumulative envelope:** Story 19.1 consumes ~22 B / 300 B ≈ 7%; leaves ~278 B for Stories 19.2 (~80 B target per epics-doc), 19.3 (~70 B), 19.4 (close-out, 0 B kernel).

### Q1 disposition — `LATEST` word design (AC2)

**Default (chosen pre-dev-pass): variable-style `LATEST ( -- a-addr )` pushes the address of the LATEST cell.**

**Rationale:**
- Probe AC7(d) wording `LATEST @` requires LATEST to push an address that `@` can dereference
- Matches gforth / SwiftForth / pforth idiom for HERE-equivalent variable-style words
- Symmetric with HERE's existing `( -- addr )` semantic (HERE pushes the *value* — a pointer to free dictionary space; LATEST as variable-address pushes the *cell address* — `@` then reads the value). This is a slight asymmetry but the variable-address pattern is what `LATEST !` ergonomics (interactive dictionary surgery) needs
- Bytes: ~22 B inclusive

**Alternative (rejected pre-dev-pass): constant-style `LATEST ( -- entry-addr )` pushes the dictionary-entry pointer directly.**

**Why rejected:**
- Breaks probe AC7(d)'s `LATEST @` — would require probe rewording to just `LATEST` (no `@`)
- Cannot be modified via `LATEST !` — interactive dictionary surgery (uncommon but standard Forth tradition) becomes harder
- Slightly cheaper (~21 B inclusive: same header, body becomes `LD BC, (user_area + UserArea.latest)` = 4 B vs `LD BC, user_area + UserArea.latest` = 3 B — wait, the indirect read is actually ~1 B *larger*, not smaller, because it reads the cell at compile time vs computing the address — re-check at dev-pass start)

**Open for project-lead disposition at dev-pass start.** If resolved to constant-style, AC7(d) probe wording must be updated to remove the `@` and Dev Notes byte itemisation re-stated.

### Q2 disposition — probe (e) verdict shape (AC7(e))

**Default (chosen pre-dev-pass): loosen to "non-zero xt written" — assert the written cell holds the xt of `BANK-MAPPING-ON` (a kernel CFA in fixed memory), not specifically a stub-region address.**

**Rationale:**
- Epics-doc wording asserts the cell "points into descriptor-stub region", but `BANK-MAPPING-ON` (or any kernel DEFCODE word) has its xt = CFA in $0100-$D3FF per the Story-18.3 EXECUTE 3-way dispatch design (`src/inner_interpreter.asm:280..345` — H-byte test `CP $D4 / JR C, .legacy_dispatch`)
- The "stub-region xt" assertion only becomes meaningful for Story-19.2-defined banked words (which `:` will stub-allocate)
- At Story 19.1 close, no banked words exist that could be `' word` quoted to get a stub-address xt — the only stub-region xts are those hand-built by Story 18.5's iron-spike or the cross-bank-call iron-spike tests, which require explicit `stub_allocate` invocation
- Loosening to "non-zero xt written + cell-survives-bank-switch" preserves the load-bearing assertion (COMPILE, writes per-bank) without requiring Story 19.2's stubs

**Alternative-1 (rejected): defer probe (e) to Story 19.2** — clean but breaks AC7's "verifies the foundation" composition; AC4 closure deserves a witness in this story.

**Alternative-2 (rejected): hand-allocate a stub via `(stub-allocate)` (FORTH name TBD; the Forth-callable wrapper at `src/banking.asm:798..823`)** — feasible but adds probe complexity for marginal gain.

**Open for project-lead disposition at dev-pass start.** Default loosening is the path of least surprise.

### Q3 disposition — probe (a) wording correction (AC7(a))

**Default (chosen pre-dev-pass): probe-a body becomes `5 BANK! HERE DUP , @ .` (remove the `@` after the first HERE).**

**Rationale:**
- Epics-doc wording `5 BANK! HERE @ DUP , @ .` is malformed under the current HERE semantics: `w_HERE_cf` (`src/memory.asm:124..130`) pushes the VALUE of HERE (= a dictionary pointer), not the address of the HERE cell. `HERE @` would dereference the dictionary pointer, reading the byte at HERE — which is uninitialised garbage at the start of a fresh probe. The probe as worded would write garbage into HERE, not the HERE pointer itself
- The intended probe is "write HERE's value into HERE's address, then read back" — `HERE DUP , @` is the correct stack-shuffle: HERE (value=p) / DUP (p p) / , (consumed cell stored at HERE-pre-bump; HERE becomes p+2; TOS=p, stack:p) / @ (read cell at p, which is the cell just stored = original p before the bump). Wait this is also subtly wrong: after `,`, HERE has advanced to p+2; `@` reads the cell at p (the just-written cell) = p (the value DUP'd before `,`). So `5 BANK! HERE DUP , @ .` prints p (the HERE value before the `,` bump). Probe passes if it prints a non-zero pointer.
- Actually re-reading once more: `HERE` pushes p; `DUP` makes (p p); `,` consumes top p, writes p at the cell at HERE-current-position (= p), advances HERE to p+2; remaining stack: (p); `@` consumed p, reads cell at p (= the just-written p); prints p. So probe correctness: it prints the value that was written, which is the HERE value at the start of the probe.

**The literal probe-a wording is therefore: `5 BANK! HERE DUP , @ .` — minus the spurious `@` after the first HERE.**

**Open for project-lead disposition at dev-pass start.** If project-lead prefers the epics-doc literal wording verbatim, the probe should be marked SKIP-with-rationale (the literal wording reads uninitialised dictionary memory and is not a load-bearing per-bank witness).

### Source tree components to touch

- `src/memory.asm` — primary: add `w_LATEST` DEFCODE (Q1-default ~22 B); add per-bank CCD-3 source comments to HERE, COMMA, C_COMMA, ALLOT per AC5/AC6
- `src/compiler.asm` — comment-only: finalise the `w_COMPILE_COMMA_cf` block at `:339..369` to mark Epic 19 closure per AC4
- `tests/banking_tests.fth` — add Probe-19.1-A through -E after the existing 18.5.1 block (current tail at line 1637); per `feedback_tib_size_inline_comments.md` keep lines ≤ TIB_SIZE=128; per Story 17.5.2 lesson use colon-body wraps for any probe that uses IF/ELSE/THEN
- `Makefile` — add probe assertions to `test-repl-banking` target parallel to the Story-18.5.1 18.5.1-a/-b shape
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status transitions per Task 7
- Optional (if Q1/Q2/Q3 dispositions diverge from defaults): re-update this story's Dev Notes with the chosen dispositions before the kernel edit begins

### Architecture references — load-bearing for this story

- **PD-P4-3** (`architecture.md:229..241`) — "Per-bank state triple swapped on `BANK!`" — the architecturally-locked decision that establishes the active state cell as the read-cache and `BANK!` swap as the consistency mechanism
- **FR-P4-22, FR-P4-23, FR-P4-26** (`epics-phase4-epics-16-22.md:218..226`) — per-bank dictionary state + per-bank `,` and `COMPILE,` + per-bank `HERE` / `LATEST` functional requirements
- **NFR-P4-1** (`architecture.md:759`-ish via PRD) — Phase-2 envelopes hold; ≤ 5% regression on intra-bank `,` / `C,` hot path
- **NFR-P4-5** — Phase-4 cumulative ROM cap (≤8 KB per redesign §7); Story 19.1's ~22 B is within both the Story envelope (~150 B AC10) and the Epic 19 cumulative envelope (~300 B per Decision Impact Analysis)
- **NFR-P4-20** — CCD-3 source-citation discipline (every banking-touching kernel site cites redesign-doc §)

### Testing standards summary

- Probes use the `_p19-1*` variable-name disambiguation pattern (Story 18.4 CR-M1 precedent)
- Probes are SENTINEL-BOUNDED with `---probe-19.1-X-start---` / `---probe-19.1-X-end---` markers (Story 18.4/18.5 precedent)
- VARIABLE-stash for witnesses where applicable (`_p18-5e` precedent at `tests/banking_tests.fth:1500..1515`)
- Probe-line lengths MUST stay ≤ TIB_SIZE=128 per `feedback_tib_size_inline_comments.md`
- Top-level IF/ELSE/THEN MUST be wrapped in a colon body to avoid -14 THROW per Story 17.5.2 / `feedback_no_preexisting_discharge.md` Lesson 13-B
- Three-test-surface sweep at close per Story 16.3 convention
- Hardware-smoke recipe in closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule

### Project Structure Notes

- Story 19.1 is the Epic 19 kickoff story (per `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:763`); epic transitions backlog → in-progress at create-story time per `instructions.xml` step 1
- The story sits between the Story 18.5.1 close (which extended CATCH/THROW for i*x deeper-cell preservation, +106 B kernel; the 26,583 B binary baseline this story inherits) and Story 19.2 (which builds bank-aware `:` on top of this story's per-bank cell-write foundation)
- The story is unusual among Phase-4 stories in that the *named* AC1/AC3/AC4 work is documentation-only (the existing UserArea-cell-as-read-cache path is per-bank-correct by construction via BANK!'s LDIR swap). The substantive code-edit work is the single new `LATEST` DEFCODE for AC2. This means the story is binary-thin and the realised delta should sit at the low end of the AC10 envelope (~22 B realised vs ~150 B envelope = ~15%)
- Sprint-status row `19-1-per-bank-here-latest-per-bank-comma-c-comma-compile-comma-full-cell-write-plumbing` is in the canonical `epic-19:` block (line 386); transitions handled at Task 7

### Detected conflicts or variances

- **epics-phase4-epics-16-22.md:773 AC1** says "extend w_HERE_cf to read from bank-table[]" but the existing implementation already does this via the UserArea-cache mechanism + BANK!'s LDIR swap. The AC wording is technically accurate (the read IS from bank-table[] via the swap) but the implication of a code change is misleading. The story handles this by closing AC1 with documentation + probes rather than code edit.
- **epics-doc AC2** says "extend w_LATEST_cf likewise" but no such word exists today. Story introduces `LATEST` as a new Forth word per Q1-default.
- **epics-doc AC7(e)** asserts COMPILE, of a kernel xt "points into descriptor-stub region" — incorrect per the Story-18.3 EXECUTE 3-way dispatch design which distinguishes legacy CFA (xt < $D400) from stub-region (xt ≥ $D400). Q2 default loosens the probe.
- **epics-doc AC7(a)** literal wording `5 BANK! HERE @ DUP , @ .` is malformed (reads uninitialised dictionary memory). Q3 default corrects to `5 BANK! HERE DUP , @ .`.
- **epics-doc AC7(b)** assumes HERE-divergence between banks at first-visit-time, but at COLD all 29 bank-table entries are LDIR-clones of bank-0 per the Story-17.4 CR fix (`src/antforth.asm:184..197`). Probe-19.1-B explicitly warms up bank-5's `here` via an initial `,` before measuring the delta.
- **epics-doc AC7(d)** assumes `:`-defined words exist in two banks, but bank-aware `:` is Story 19.2 work. Probe-19.1-D uses `LATEST !` directly (verifying LATEST is a per-bank cell) rather than depending on bank-aware `:`.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:763..785`] — Story 19.1 AC source
- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:747..761`] — Epic 19 goal, FRs, NFRs, dependencies
- [Source: `_bmad-output/planning-artifacts/architecture.md:229..241`] — PD-P4-3 per-bank state triple architectural decision
- [Source: `_bmad-output/planning-artifacts/architecture.md:386..402`] — PD-P4-13 bank-table[] cap policy (29 entries; tangentially relevant for sizing context)
- [Source: `_bmad-output/planning-artifacts/architecture.md:767..774`] — Phase-4 file-touch surface (Epic 19 row points at src/memory.asm)
- [Source: `_bmad-output/planning-artifacts/architecture.md:835..842`] — Epic 19 requirements-to-structure mapping
- [Source: `docs/antforth-banking-redesign.md` §5.4] — per-bank `(here, latest, wordlist-heads)` triple semantics; cross-bank pointer hazards "doc-and-pray" disposition
- [Source: `src/memory.asm:124..130`] — w_HERE_cf existing implementation
- [Source: `src/memory.asm:177..189`] — w_COMMA_cf existing implementation
- [Source: `src/memory.asm:195..205`] — w_C_COMMA_cf existing implementation
- [Source: `src/memory.asm:162..171`] — w_ALLOT_cf existing implementation (touches UserArea.here)
- [Source: `src/compiler.asm:339..383`] — w_COMPILE_COMMA_cf with Story-18.3 CCD-3 comment block (the Epic 19 forward-pointer Task 2 finalises)
- [Source: `src/banking.asm:147..196`] — BANK! triple-swap LDIR cascade (the consistency mechanism that makes UserArea-cell read per-bank-correct)
- [Source: `src/banking.asm:780..823`] — stub_allocate kernel helper + `(stub-allocate)` Forth wrapper (consumed by Story 19.2's bank-aware `:`)
- [Source: `src/antforth.asm:144..197`] — COLD-start bank-table init: zero-init, UserArea seed, snapshot live triple into bank-table[0], LDIR-clone to bank-table[1..28]
- [Source: `src/inner_interpreter.asm:280..345`] — EXECUTE 3-way dispatch (legacy CFA / intra-bank stub / cross-bank stub); the H-byte test `CP $D4` discriminator
- [Source: `_bmad-output/implementation-artifacts/18-5-1-defwords-ix-preservation-on-caught-throw.md`] — prior story; CATCH/THROW i*x deeper-cell preservation closure; binary baseline 26,583 B
- [Source: `_bmad-output/implementation-artifacts/17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix.md`] — Story 17.5.2 lesson: top-level IF/ELSE/THEN throws -14; probes that use conditionals MUST wrap in colon bodies (relevant for the bench probe in AC8)
- [Source: `_bmad-output/implementation-artifacts/16-3-banking-capable-emulator-vendor-selection-make-test-repl-banking-integration.md`] — three-test-surface convention
- [Source: ANS Forth 1994 §6.1.0150 `,`, §6.1.1700 `HERE`, §6.1.0860 `C,`] — single-cell write / dictionary-pointer-read / single-byte-write semantics
- [Source: ANS Forth 1994 §6.2.0945 `COMPILE,`] — runtime compile-xt semantic
- [Source: `feedback_no_preexisting_discharge.md`] — "surface, file, fix" — handles the AC1/AC3/AC4 wording-vs-reality variances above
- [Source: `feedback_tib_size_inline_comments.md`] — TIB_SIZE=128 constraint on probe lines
- [Source: `feedback_post_hw_smoke_steps_at_review.md`] — STRONG rule on HW-smoke recipe in closing chat message
- [Source: `feedback_no_claude_coauthor.md`] — STRONG rule: no Claude co-author trailer in commit messages
- [Source: `feedback_kernel_ldir_estimate_overshoot.md`] — LDIR/IX-rstack estimate × 1.25 ± 10% (NOT triggered here — Story 19.1 has no LDIR work; included for completeness in case Q1/Q2 dispositions introduce LDIR shapes)
- [Source: `project_epic17_envelope.md`] — Phase-4 binary-delta empirical ~2.4× spec target pattern (NOT triggered here at ~22 B Q1-default; included as sanity-check anchor)
- [Source: `project_phase4_scope.md`] — Phase 4 in-progress through Epic 22; Epic 18 closed at v3.0.2; Epic 19 next (v3.0.3 at Story 19.4 close-out)
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`] — B.2 / Lesson 13.5-C "mirrors prior arm" HALT (no shorthand byte-budget rationale used in this story); B.4 / PD-2 figure-drift discipline (all cited line:column figures re-validated against source at draft time on 2026-05-19); ADV review separation (ACs do not enumerate adversarial review)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context)

### Debug Log References

Three iterative probe-design attempts during dev-pass before settling on the simplified two-probe shape:

1. **Initial probe set (build #1, attempt at 5 behavioural probes)**: All probes used `: _p19-1X-body ... 5 BANK! ... ;` colon-body wrap. **Failure mode**: dictionary-corruption when bank 5 active. Each colon body's thread cells live at HERE in $8000+; when the body executes `5 BANK!`, slot-2 switches pages, NEXT fetches the next thread cell from now-banked-out memory → garbage → crash or undefined-word errors. Variables defined while bank 0 active are unfindable in bank 5's wordlist chain (BANK!'s LDIR-cloned wordlist_head holds COLD snapshot, no user words). Bucket chain walks for kernel words traverse user-word entries in $8000+ which become garbage after bank-switch.

2. **Second iteration (R-stack-passing pattern)**: Moved bank-switching to TOP LEVEL (not inside colon bodies); used R-stack to pass witnesses across the bank-switch boundary; check colon bodies run only in bank 0 context. **Failure mode**: Kernel-word lookups STILL fail after `5 BANK!` because the hash-bucket-head pointers (in fixed memory) point to user-word entries in banked $8000+ memory; bucket-chain walks read garbage when bank 5 active. Empirically: HERE works (its bucket chain happens to be clean), but BANK!, @, EXECUTE, , all fail after `5 BANK!`. This makes any meaningful work in bank 5 impossible to verify via REPL probes.

3. **Final scope revision**: Simplified to two bank-0-only probes (Probe-19.1-A LATEST word semantic, Probe-19.1-B bank-table[] divergence). AC7 (a)/(b)/(c)/(d)/(e) deferred to Story 19.2 (bank-aware `:`) per the test-surface limitation diagnosis. Pattern parallels Story 18.5 probes (b)/(d) SKIP-deferred-to-Epic-19. Build #4: 26603 B (+20 B vs baseline); all three test surfaces clean (975/0/2 + 52/0/3 + 25/0/3); check-doc-sync 31/0.

The test-surface limitation is a real architectural finding that should inform future Phase-4 story planning: behavioural per-bank probes are structurally unreliable in the current iz-cpm-banking + accumulated-test-file state until Story 19.2 ships bank-aware `:`. Worth recording as a feedback memory.

### Completion Notes List

- **AC2 (LATEST word) — CLOSED**: New `w_LATEST` DEFCODE at `src/memory.asm:165..170` (preceded by CCD-3 comment block at :146..164). Variable-style `( -- a-addr )` chosen at Q1 disposition. Body = `PUSH BC / LD BC, user_area+UserArea.latest / NEXT` (11 B body). Header = 9 B (hash_link + count_flags + 6-byte name "LATEST"). Total = 20 B (matches pre-build itemisation exactly). Verified via Probe-19.1-A: LATEST returns address 26623 (= user_area+6), LATEST @ / LATEST ! round-trips 12345 successfully, LATEST returns stable address across multiple invocations. **Per-bank-tracking sub-claim** (the AC2 wording "LATEST tracks per-bank state via BANK!'s LDIR swap") is closed by *architectural inheritance* from PD-P4-3 (same closure path as AC1/AC3/AC4): the cell at `user_area + UserArea.latest` is swapped by BANK!'s LDIR triple-swap at `src/banking.asm:170..193`, not by any Story-19.1 code edit. Probe-19.1-A does not exercise the per-bank-tracking path (bank-0-only test); the per-bank claim is documentation-only at this story, behavioural witness deferred to Story 19.2 + a fresh-test-fixture strategy per Dev Notes §"Probe scope revision".

- **AC1 (HERE per-bank) — CLOSED via documentation + architectural witness**: `w_HERE_cf` source comment added at `src/memory.asm:120..137` (immediately above the existing `w_HERE` / `w_HERE_cf` at :138..144) citing PD-P4-3 (architecture.md:229..241), redesign §5.4, and the LDIR triple-swap mechanism at src/banking.asm:170..193 as the consistency mechanism. No functional code change. Architectural witness via Probe-19.1-B: bank-table[0] HERE and bank-table[5] HERE both non-zero (confirms COLD's snapshot + LDIR-clone at antforth.asm:144..197 propagated the per-bank triple infrastructure). NB: the divergence form of the witness (`bt0 != bt5`) was dropped at CR review (2026-05-19 H2/H3) — that form depends on test-history pollution and would FAIL on a fresh-boot.

- **AC3 (`,` and `C,` per-bank) — CLOSED via documentation**: `w_COMMA_cf` source comment added at `src/memory.asm:218..231` (preceding `w_COMMA` / `w_COMMA_cf` at :232..244). `w_C_COMMA_cf` source comment + cross-bank hazard note added at `src/memory.asm:246..256` (preceding `w_C_COMMA` / `w_C_COMMA_cf` at :258..268). Cross-bank pointer hazard (FR-P4-26 "doc-and-pray") inline comment added per AC5. ALLOT also annotated at `src/memory.asm:198..206` (preceding `w_ALLOT_cf` at :207..216) for completeness (same per-bank-via-swap discipline). No functional code change — UserArea.here read/write path is per-bank-correct by construction.

- **AC4 (COMPILE, per-bank) — CLOSED**: `w_COMPILE_COMMA_cf` comment block at `src/compiler.asm:339..390` finalised. The Story-18.3 "future Epic 19" forward-pointer text revised to "closed by Story 19.1 — per-bank cell-write plumbing"; the downstream consumer reference to Story 19.2 (bank-aware `:`) preserved as future-pointer. No functional code change.

- **AC5 (cross-bank pointer hazard inline comment) — CLOSED**: Inline comments added near HERE (`src/memory.asm:133..136`), COMMA (`:226..230`), and C_COMMA (`:250..253`, added at CR review 2026-05-19 H4) in `src/memory.asm` documenting the "doc-and-pray" hazard per FR-P4-26.

- **AC6 (CCD-3 source citations) — CLOSED**: All five touchpoints (HERE, LATEST, COMMA, C_COMMA, ALLOT in memory.asm; COMPILE_COMMA in compiler.asm) carry per-bank citations to `docs/antforth-banking-redesign.md §5.4` and `architecture.md:229..241 (PD-P4-3)`.

- **AC7 (probes) — PARTIALLY CLOSED**: Two simplified probes (19.1-a, 19.1-b) ship; AC7 (a)/(b)/(c)/(d)/(e) deferred to Story 19.2 per test-surface limitation (see Dev Notes §"Probe scope revision"). Probes pass under iz-cpm-banking emulator surface; Makefile assertions wired parallel to Story-18.5.1 probe-a/-b shape. **Probe-19.1-B robustness fix (CR review 2026-05-19 H2/H3)**: the original probe asserted `bt0-here != bt5-here` (per-bank divergence), but that property is test-history-dependent (requires earlier `5 BANK!`+compile+`0 BANK!` cycles in the test surface) and would FAIL on a fresh-boot where COLD's LDIR-clone makes all 29 entries identical. The divergence assertion was dropped; the probe now asserts only `bt0 != 0` and `bt5 != 0` (LDIR-clone witness — confirms COLD's snapshot + LDIR-clone of bank-table[0] → bank-table[1..28]). The behavioural divergence witness remains a Story-19.2 deferral. **NB on the deferral path**: Story 19.2 alone is not sufficient to land AC7 (a)–(e) — the existing test-surface accumulation (HERE past $8000) will still bucket-corrupt user-word lookups after `N BANK!`. New behavioural probes will need a fresh-test-fixture strategy (e.g., run them in a separate test target that loads only banking_tests.fth on a clean COLD, or quarantine them with a per-bank reset) in addition to 19.2's bank-aware `:`.

- **AC8 (NFR-P4-1 envelope) — CLOSED structurally**: `,` / `C,` / `HERE` / `ALLOT` / `COMPILE,` hot-path code byte-identical to Story 18.5.1 baseline; realised regression = 0.000% (no kernel hot-path edit).

- **AC9 (hardware smoke) — CLOSED**: HW-smoke recipe was run on real MicroBeast 2026-05-19 (transcript `~/Downloads/beastty-20260519-143614.bin`); all assertions PASS (Probe-19.1-A on hardware, per-bank HERE/`,` behavioural witness via HW-fresh-boot variant using bank 1, binary-identity confirmation via banner "bytes free" count). See Change Log entry "2026-05-19 (HW-smoke close)" for full transcript and per-AC mapping. HW-smoke recipe included in closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.

- **AC10 (binary delta) — CLOSED**: +20 B realised vs ~22 B pre-build estimate (within ±10% itemisation tolerance); well under AC10 ~150 B story envelope (~13% used). Epic-19 cumulative envelope: 20 B / 300 B = ~7% consumed.

- **AC11 (test surface preservation) — CLOSED**: `make test-repl` 975/0/2 unchanged; `make test-repl-banking` 50/0/3 → 52/0/3 (+2 new probes); `make test-repl-banking-skip` 25/0/3 unchanged; `make check-doc-sync` 31/0 unchanged.

- **Test-surface limitation finding (post-dev-pass)**: The accumulated test-file state pushes HERE past $8000, causing bank-switching to break dictionary lookups due to bucket-chain corruption (user-word entries in banked $8000+ region). This is a known limitation that Story 19.2's bank-aware `:` will structurally fix. Recommend recording as feedback memory: behavioural per-bank probes require Story 19.2's per-bank dictionary plumbing as a prerequisite.

### File List

- `src/memory.asm` — modified: added `w_LATEST` DEFCODE at lines 165..170 (preceded by CCD-3 comment block at 146..164); added CCD-3 per-bank citation comments to `w_HERE_cf` (comment 120..137, code 138..144), `w_ALLOT_cf` (comment 198..206, code 207..216), `w_COMMA_cf` (comment 218..231, code 232..244), `w_C_COMMA_cf` (comment 246..257, code 258..268). Cross-bank-pointer-hazard inline comments per AC5 at HERE (133..136), COMMA (226..229), and C_COMMA (253..256; C_COMMA hazard note added at CR review 2026-05-19 H4). [Line numbers refreshed at CR review 2026-05-19 per M1.]
- `src/compiler.asm` — modified: `w_COMPILE_COMMA_cf` comment block at lines 336..380 finalised — the Story-18.3 "FORWARD POINTERS" subhead renamed "DOWNSTREAM CONSUMERS (Epic 18+)"; Epic-19 forward-pointer text revised to "closed by Story 19.1"; Story 19.2 downstream-consumer reference preserved; per-bank citation paragraph added. `w_COMPILE_COMMA` label at :381, `w_COMPILE_COMMA_cf` at :383.
- `tests/banking_tests.fth` — modified: Story 19.1 probe block added at lines 1639..1757. Includes intro/scope block comment (1639..1675), Probe-19.1-A (1677..1712), Probe-19.1-B (1714..1757; rationale comment revised at CR review 2026-05-19 H2/H3 to drop the test-history-dependent divergence assertion; magic decimal pointers replaced with `$D400`/`$D41E` hex per M4).
- `Makefile` — modified: `test-repl-banking` target gains probe-19.1-a (lines 518..530) and probe-19.1-b (lines 531..547; pass-message + comment refreshed at CR review 2026-05-19 H3) assertion blocks parallel to the Story-18.5.1 18.5.1-a/-b shape.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — modified: `epic-19` transitioned `backlog` → `in-progress` (line 385); `19-1-per-bank-here-latest-per-bank-comma-c-comma-compile-comma-full-cell-write-plumbing` transitioned `backlog` → `ready-for-dev` (at create-story-time) → `in-progress` (at dev-pass start) → `review` (at dev-pass close).
- `_bmad-output/implementation-artifacts/19-1-per-bank-here-latest-per-bank-comma-c-comma-compile-comma-full-cell-write-plumbing.md` — modified: Status `ready-for-dev` → `review`; all Tasks/Subtasks checkboxes marked `[x]`; Dev Notes updated with post-edit measurements + probe scope revision; Dev Agent Record + File List + Change Log filled in.

### Change Log

- 2026-05-19 (create-story): Story drafted via create-story workflow on Epic 19 kickoff turn. Three Q-dispositions surfaced (LATEST design, probe (e) shape, probe (a) wording) for project-lead resolution at dev-pass start. Epic 19 status auto-transitioned `backlog` → `in-progress` per instructions.xml step 1.
- 2026-05-19 (dev-pass start): Pre-edit baselines captured (matched Story 18.5.1 close; no housekeeping interlude). Q1/Q2/Q3 resolved to defaults via AskUserQuestion: variable-style LATEST, loosened probe-e, corrected probe-a wording.
- 2026-05-19 (dev-pass): Task 1 (`w_LATEST` DEFCODE) + Task 2 (source-comment additions) landed. Build clean; +20 B kernel delta exact to estimate.
- 2026-05-19 (dev-pass — probe design iteration): Three attempts at AC7 (a)/(b)/(c)/(d)/(e) probes surfaced fundamental test-surface limitation (bucket-chain corruption when bank-switching with HERE in banked $8000+ region). Probe scope revised to two bank-0-only probes: LATEST word semantic (Probe-19.1-A) + bank-table[] divergence architectural witness (Probe-19.1-B). Behavioural probes (a)/(b)/(c)/(d)/(e) deferred to Story 19.2 per Story 18.5 (b)/(d) SKIP-precedent.
- 2026-05-19 (dev-pass close): Three-test-surface sweep clean (975/0/2 + 52/0/3 + 25/0/3). Binary +20 B (within ±10% itemisation tolerance). Doc-sync 31/0 advisory count preserved. Status transitioned `in-progress` → `review`.
- 2026-05-19 (CR review): Adversarial code review found 4 HIGH + 4 MEDIUM + 4 LOW issues; user chose [1] fix-all. Applied fixes:
  - **H1** Completion Notes AC9 reconciled to CLOSED (matches the HW-smoke Change Log entry below); rationale: HW-smoke transcript already on file.
  - **H2/H3** Probe-19.1-B made fresh-boot-robust: dropped the `bt0 != bt5` divergence assertion (test-history-dependent; would fail on a clean COLD per src/antforth.asm:184..197 LDIR-clone); kept only the `bt0 != 0` / `bt5 != 0` LDIR-clone witness. Forth probe + Makefile pass-string + comment all updated. Probe-19.1-B pass-message renamed `...bank-table-ldir-clone-witness`.
  - **H4** Cross-bank pointer hazard inline comment added to `w_C_COMMA_cf` at `src/memory.asm:253..256` (AC5 completion — was missing).
  - **M1** All File List line ranges refreshed to match current file state (figure-drift per `instructions.xml` B.4 / PD-2).
  - **M2** Dev Notes Probe-scope-revision clarified: Story 19.2 alone is insufficient to recover AC7 (a)-(e); a fresh-test-fixture strategy is also needed.
  - **M3** Completion Note AC2 clarified: per-bank-tracking sub-claim is closed by architectural inheritance (same as AC1/AC3/AC4), not by Probe-19.1-A which is bank-0-only.
  - **M4** Probe-19.1-B magic decimal pointers (`54272`, `54302`) replaced with `$D400` / `$D41E` hex literals with `bank-table[5] = $D400 + 5*6` inline comment.
  - Rebuild clean: binary 26603 B (unchanged — all CR fixes were comment / Forth-source / Makefile-string edits, no kernel hot-path code).
  - Test surfaces clean: `make test-repl-banking` 52/0/3; Probe-19.1-A and Probe-19.1-B both PASS under new pass-strings.
- 2026-05-19 (HW-smoke close): Project-lead ran the post-Story-19.1 HW-smoke recipe on real MicroBeast (transcript `~/Downloads/beastty-20260519-143614.bin`). All assertions PASS:
  - Probe-19.1-A: `LATEST .` → 26623 (= user_area + UserArea.latest, fixed address); `LATEST @ .` → 0 at COLD; `12345 LATEST !` + `LATEST @ .` → 12345 (round-trip); `0 LATEST !` restore — AC2 verified on hardware.
  - Per-bank HERE / `,` behavioural witness (HW-fresh-boot variant — no test-file accumulation): `HERE U.` = 26859 (bank-0 COLD snapshot); `42 ,` advances HERE to 26861 (AC3 verified); `BANKS-CLEAR $22 +BANK $35 +BANK 0 BANK!` flushes LIVE to bank-table[0] (= 26861); `1 BANK!` swaps in bank-1's COLD-cloned HERE = 26859 (≠ bank-0's 26861) — AC1 per-bank divergence verified on hardware; `0 BANK!` restores LIVE = 26861 (bank-0 HERE preserved across roundtrip).
  - EVALUATE health-check: `S" 10 20 +" EVALUATE .` → 30 (CATCH/THROW + INTERPRET surface unaffected by Story 19.1 changes).
  - Binary identity confirmed: HW banner shows `27413 bytes free` (post-19.1) vs `27433 bytes free` (pre-19.1 baseline) = exactly **-20 bytes** = matches +20 B kernel growth.
  - HW-smoke verdict: **PASS**. AC9 CLOSED. The probe-19.1-B emulator-side assertion (`h0 != h5`) requires accumulated test-file state to differentiate bank-0 from bank-5 (at fresh boot, all 29 bank-table entries are LDIR-clones per src/antforth.asm:184..197); the equivalent HW-side witness uses `, + 0 BANK!` to advance bank-0's HERE before the bank-1 swap, demonstrating per-bank divergence canonically.
- 2026-05-19 (post-CR HW confirmatory re-run): Project-lead ran a second HW-smoke pass on real MicroBeast after the CR fixes (transcript `~/Downloads/beastty-20260519-151554.bin`). All assertions PASS:
  - Banner: `27413 bytes free` (confirms binary identity preserved through CR comment/Forth/Makefile-only fixes; binary still 26603 B).
  - `LATEST .` → 26623 (= `user_area + UserArea.latest`, AC2 verified post-CR).
  - `LATEST @ .` → 0 at cold; `12345 LATEST !` + `LATEST @ .` → 12345 (round-trip).
  - `0 LATEST !` (restore).
  - `54272 @ U.` (= `$D400 @`) → 26859 (bank-table[0].here non-zero — LDIR-clone witness component for AC1/AC3/AC4).
  - `: TEST-LATEST 1 2 ; LATEST @ U.` → 26859 (LATEST tracks newly-compiled entry — bonus validation of variable-style semantic, including the per-bank-correct read path in bank 0).
  - Verdict: PASS. Confirms CR fixes are kernel-neutral and the post-CR build retains all Story 19.1 functional surface.
