# Story 20.3: Epic 20 close-out + antforth 3.0.5 tag

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-12 by create-story workflow on the Story 20.3 turn.
     Story 20.3 is the Epic 20 close-out gate: it ships the verified
     bank-aware LOOKUP surface (Stories 20.1 bank-aware FIND + 20.2
     bank-aware WORDS / FR-P4-30 retirement) as the next antforth tag.
     Close-out is a 0-byte-kernel gate (version-surface alignment +
     integration probe + verdict-table walk + CCD-4 stub-count metric +
     envelope reconciliation + tag).

     TWO load-bearing drift findings were discovered at DRAFT TIME and
     folded into the ACs (B.4 / PD-2 figure-drift discipline — the
     epics-file Story 20.3 §"3.x.4" text is stale). Do NOT re-discover
     them at dev-pass:

       (1) VERSION = v3.0.5, NOT v3.0.4. The epics-file placeholder
           "antforth 3.x.4 tag" is STALE. v3.0.4 was already consumed by
           the Epic 19.5 cross-bank-dispatch stabilization + MBB
           banking-BIOS pivot interlude — `git tag v3.0.4` exists on
           commit `2808ce3` ("Close Epic 19.5 … v3.0.4 tag"), and the
           banner (`src/antforth.asm:781`) + README (`:14`) already read
           `v3.0.4`. HEAD is `v3.0.4-6-g4c2ab0b` (the 6 Story-20.1/20.2
           commits). The README version-history prose already narrates
           the v3.0.4 FIND limitation as "carried to Epic 20 (bank-aware
           FIND)". Epic 20 therefore ships **v3.0.5**. This shifts the
           planning-file downstream mapping (Epic 21 → v3.0.6, Epic 22 →
           v3.0.7) — flagged for the close-out, owned by Q1.

       (2) ENVELOPE BREACH (AC7). Epic-20 cumulative is **+680 B**
           (baseline-before-Epic-20 = v3.0.4 close `2808ce3` = 26945 B;
           current HEAD `4c2ab0b` = 27625 B). This is 3.4× OVER the
           ~200 B Epic-20 Decision-Impact-Analysis envelope — because
           Story 20.1's mechanism changed mid-flight from a localised
           per-wordlist-`bank`-field FIND tweak to a full 24-bit
           fat-pointer dictionary HEADER-FORMAT MIGRATION (+1 B per ~379
           kernel header links + 64 B fat bucket array + walk/build code
           + name buffer). AC7 records an accept-with-rationale + SCP
           envelope re-baseline (cf. Story 19.4 AC7), NOT a clean
           ≤200 B pass.

     Two further re-spec notes (the epics-file Story 20.3 ACs predate the
     20.1/20.2 dev-pass re-specs):

       (3) AC5 INTEGRATION PROBE — the epics-file clause "a typo lookup
           against a non-current-bank wordlist produces the attributed
           error message" is STALE. FR-P4-30 (source-bank error
           attribution) was RETIRED in Story 20.2 (no per-bank wordlists
           under the single-global-wordlist + fat-pointer mechanism; a
           FIND miss means "absent everywhere"). The integration probe
           asserts the PLAIN `<word> ?` error, NOT an attributed one.

       (4) Stories 20.1 + 20.2 are ALREADY `done` (no `review → done`
           reconciliation needed, unlike Story 19.4). This close-out is
           cleaner: version surface + verdict walk + envelope SCP +
           integration probe + tag. -->

## Story

As Ant (the project lead applying the Epic 20 close-out tag),
I want the user-visible version surface aligned to `3.0.5` (banner / README / REPL-test-80 assertion / memory `description`), the full test surface clean across iz-cpm + the banking-capable emulator + the isolated fixtures + real MicroBeast, the banked-word stub-count metric captured per CCD-4 with the trend vs the Story 19.4 baseline, the Epic-20 envelope overage reconciled via a sprint-change-proposal record, the deferred `docs/antforth-banking-redesign.md §5.5` doc-sync item closed, the verdict-table walk recorded, and the `v3.0.5` tag applied,
so that Epic 20's bank-aware lookup surface (`FIND` traverses banks invisibly via 24-bit fat dictionary pointers; `WORDS` produces a unified flat listing; the everyday FORTH-wordlist lookup incurs no MMU switch) ships as antforth 3.0.5 with an honest, reconciled close-out.

## Acceptance Criteria

> Close-out + integration verification of Epic 20's verified bank-aware lookup mechanism. The epics-file Story 20.3 §"3.x.4" placeholder is re-specced here against repo reality: the tag is **v3.0.5** (v3.0.4 is taken by Epic 19.5), the envelope is reconciled (not a clean pass), and the FR-P4-30 error-attribution clause is retired. FRs: none directly (close-out). NFRs codified: NFR-P4-4 (stub-count metric); NFR-P4-5 (envelope reconciliation — SCP record); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic decoupling — 3.0.5 ships); NFR-P4-38 (S11 version surface); NFR-P4-39 (S12).

**Given** Stories 20.1 (bank-aware `FIND` via inline 24-bit fat dictionary pointers) + 20.2 (bank-aware `WORDS` verified + FR-P4-30 retired) have shipped and are `done`; current binary 27625 B at HEAD `4c2ab0b`; `git tag v3.0.4` already applied to the Epic-19.5 close commit `2808ce3`,
**When** Story 20.3 is dev-passed,

**Then** AC1 (S11 / NFR-P4-38 user-visible version surface audit → **v3.0.5**) — the version surface advances `3.0.4` → `3.0.5`:
- `src/antforth.asm:781` `str_banner1` reads `"AntForth v3.0.5 (C) ant.org 2026"` (currently `v3.0.4`); this is a same-length string edit → **0 B kernel delta** (verify by clean rebuild + `strings build/antforth.com`).
- `README.md:14` `## Version 3.0.5` (currently `3.0.4`); `README.md:39` `V3.0.5 supports the following ANS Forth standard words` (currently `V3.0.4`); the version-history prose (`:24..36`) gains a `3.0.5` sentence describing the bank-aware lookup surface (FIND traverses banks via fat pointers; WORDS unified listing); the v3.0.4 "carried to Epic 20 (bank-aware FIND)" forward-reference (`:36`) is reconciled to "delivered in 3.0.5".
- **`Makefile:1655-1658` REPL test 80 banner assertion** `grep -q 'AntForth v3.0.4'` → `v3.0.5` (test-infra; 0 B). This is the "uncited fourth version surface" class that B.4 caught at the Story 19.4 dev-pass — it IS enumerated here, do not let the post-edit `make test-repl` fail on it.
- The Phase-4-scope memory entry's `description` field (`project_phase4_scope.md`) advances to note `antforth 3.0.5 SHIPPED` (Epic 20 close).
- Re-validate every cited file:line at dev-pass start per B.4 / PD-2 figure-drift discipline (line numbers shift; re-`grep` the banner / README / Makefile assertion before editing).

**And** AC2 (verdict-table walk per Story-13.5.6 precedent) — Story 20.3 Dev Notes include a verdict-table walk for all Epic-20 stories with one-line evidence each:
- 20.1 — bank-aware `FIND` via inline 24-bit fat dictionary pointers — **PASS (done)**; +571 B then +10 B fast-path inline; AC7 (a)–(e) probes `result=-1`; HW smoke PASS (`beastty-20260610-200525.bin`).
- 20.2 — bank-aware `WORDS` verified (FR-P4-29) + FR-P4-30 retired — **PASS (done)**; 0 B kernel (WORDS shipped in 20.1 CR `d078548`); probes (a)–(d) PASS; HW smoke PASS (`beastty-20260611-231019.bin`).
- 20.3 — close-out + 3.0.5 tag — **PASS**; 0 B kernel (version surface + docs + integration probe).

**And** AC3 (banked-word stub-count metric per CCD-4) — Story 20.3 Dev Notes capture: total banked-word descriptor-stub count after Epic 20 (`(stub_alloc_tail − STUB_ALLOC_BASE) / 4`); per-stub stride; descriptor-stub fixed-memory occupancy; **trend vs the Story 19.4 baseline** (0 stubs pre-allocated at boot; 4 B/stub; `STUB_ALLOC_BASE = $D4CB`; region `$D4CB..$DBFF` = 1845 B = 461-stub cap → 0/461 at boot); assert against NFR-P4-4 (per-stub ≤ 5 B; 1000-banked-words target ≤ 5 KB total). Epic 20 added no stub pre-allocation (fat pointers are a dictionary-header change, not a stub change), so the expected trend is **unchanged vs 19.4** — confirm empirically, do not assume.

**And** AC4 (`make check-doc-sync` clean-pass per B.5 + deferred §5.5 reconciliation) — `make check-doc-sync` reports no NEW drift beyond the established advisory baseline. **Additionally close the doc-sync item Story 20.2 AC5 deferred here:** `docs/antforth-banking-redesign.md §5.5`'s *resolution* prose still describes the SUPERSEDED per-wordlist-`bank`-field design — reconcile it to the shipped single-global-wordlist + inline 24-bit fat-pointer mechanism (per the 20.1/20.2 re-specs). Keep the edit to what+why (no provenance bloat per `[[feedback_source_comment_discipline]]`).

**And** AC5 (integration probe — the Epic-20 bank-aware-lookup surface in one breath; FR-P4-30-retired form) — a single probe (new isolated fixture `tests/banking_tests_20_3.fth`, sentinel-delimited `result=-1` verdicts mirroring `tests/banking_tests_20_2.fth`) exercises the full Epic-20 surface end-to-end:
- boot with defaults; create user words in **three different banks** (e.g. `5 BANK! : _w53a ; 6 BANK! : _w53b ; 7 BANK! : _w53c ;`);
- from a third bank (or bank 0) `WORDS` produces a unified flat listing in which `_w53a` / `_w53b` / `_w53c` all appear (bank switches invisible — AC2-of-20.2 property);
- `0 BANK! ' _w53a BANK-OF` returns `5` (bank-aware `FIND` traversal resolves a name whose header lives in another bank — the 20.1 mechanism), and `' _w53c BANK-OF` returns `7`;
- a typo lookup (`?NOSUCH? `) produces the **plain Phase-3 `<word> ?` error with NO bank suffix** — FR-P4-30 retired (do NOT assert an attributed "looked in bank-N" message; that epics-file clause is stale, retired in 20.2);
- caller's current bank (`BANK@`) and slot-2 page (`MBB-GET-2`) are restored after the `WORDS` / `BANK-OF` traversals.
- An inline comment in the fixture states this is the Epic-20 close-out north-star: bank-aware lookup is observable end-to-end, error attribution is retired.

**And** AC6 (full test surface sweep — re-validate at dev-pass start per B.3) — all baselines preserved against the v3.0.5 build:
- `make test-repl` ≥ **975 PASS / 0 FAIL** on iz-cpm (the `XYZZY ?` undefined-word assertion holds; REPL test 80 banner assertion now `v3.0.5`);
- `make test-repl-banking` ≥ **61 PASS / 0 FAIL**;
- `make test-repl-banking-isolated-20-1` = **6 / 0**; `make test-repl-banking-isolated-20-2` = **5 / 0**; new `make test-repl-banking-isolated-20-3` ≥ **1 PASS** (the AC5 integration probe);
- `make test-repl-banking-isolated-19-3` / `-19-4` / `-19-5-1` = **15 / 2 / 2** (unchanged cohort);
- `make test-straddle-regression` = **3 / 3**; `make test-file-sanity` = **0 errors** (new `disk/a/P203*.FTH` HW copy `0x1A`-terminated).
- **Hardware smoke:** one full hardware-typed smoke batch covering Epic 20's bank-aware lookup surface (the AC5 integration probe) PASSes on real MicroBeast per S9 / NFR-P4-11; the HW-smoke recipe is posted IN THE CLOSING CHAT MESSAGE per `[[feedback_post_hw_smoke_steps_at_review]]` (STRONG).

**And** AC7 (Epic-20 envelope reconciliation — accept-with-rationale + SCP record, cf. Story 19.4 AC7) — the verified Epic-20 cumulative binary delta is **+680 B** (baseline-before-Epic-20 = v3.0.4 close `2808ce3` = **26945 B**; HEAD `4c2ab0b` = **27625 B**; re-validate both by clean `make clean && make` worktree rebuilds at dev-pass start per B.3). This is **3.4× OVER the ~200 B Epic-20 Decision-Impact-Analysis envelope** → AC7 does NOT assert a clean ≤200 B pass; instead it records a sprint-change-proposal envelope re-baseline with this rationale:
- Story 20.1's mechanism changed mid-flight (project-lead-steered) from a localised per-wordlist-`bank`-field FIND tweak (the ~200 B planning premise) to a full **24-bit fat-pointer dictionary header-format migration** — a different cost class (+1 B per ~379 kernel header links ≈ +379 B alone, + 64 B fat bucket array + the page-in/restore walk + build_header fat read/write + 32 B name snapshot buffer). The ~200 B envelope was scoped against the abandoned design and is not a meaningful ceiling for the shipped one.
- The empirical Phase-4 binary-delta pattern is ~2.4–2.7× the redesign-§7 spec target (`[[project_epic17_envelope]]`); even re-baselined to ~480–540 B the +680 B exceeds it — because this is not a "2.4× overshoot of the same design" but a design substitution. The honest framing: the fat-pointer migration is a structural change whose cost is recorded and accepted, with the user-facing FIND/WORDS goal delivered.
- **NFR-P4-5's 8 KB Phase-4 fixed-memory cap is unaffected** — +680 B is a small fraction; confirm the cumulative Phase-4 fixed-memory budget against the 8 KB cap in Dev Notes.
- The SCP record is written to `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-NN.md` and the disposition logged in Dev Notes (Q2 selects dedicated-file vs annotate-existing).

**And** AC8 (tag applied) — `git tag v3.0.5` is applied to the close-out commit; tag pushed to GitHub release. Commit + tag + push are outward-facing — execute ONLY on explicit user authorization at close-out (per the Story 19.4 precedent: the recipe is provided, the push is deferred to user go-ahead). Confirm `git tag` shows a contiguous `v3.0.1..v3.0.4` already present (it does — no gap to reconcile, unlike Story 19.4's missing v3.0.2).

**FRs covered:** none directly (close-out + integration verification of Epic 20's verified bank-aware lookup mechanism). **NFRs codified:** NFR-P4-4 (stub-count metric); NFR-P4-5 (envelope reconciliation — SCP record); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic decoupling — antforth 3.0.5 ships); NFR-P4-38 (S11 version surface); NFR-P4-39 (S12).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: clean `make clean && make` rebuild of HEAD `4c2ab0b` → **27625 B** (confirmed).
- [x] Capture baseline-before-Epic-20: clean worktree build of `2808ce3` (v3.0.4 close) → **26945 B** (confirmed). Epic-20 cumulative = 27625 − 26945 = **+680 B** (AC7).
- [x] Capture `make test-repl` → **975 PASS / 0 FAIL** (confirmed).
- [x] Capture `make test-repl-banking` → **61 PASS / 0 FAIL** (confirmed).
- [x] Capture `make test-repl-banking-isolated-20-1` (6/0), `-20-2` (5/0), `-19-3` (15/0), `-19-4` (2/0), `-19-5-1` (2/0); `make test-straddle-regression` (3/0); `make test-file-sanity` (0 errors); `make check-doc-sync` (31 advisory / 0 drift) — all confirmed at baseline.
- [x] Re-validate AC1 version-surface citations against source-of-truth (per B.4): banner `src/antforth.asm:781` = `v3.0.4` ✓; README `## Version 3.0.4` `:14`, `V3.0.4 supports` `:39`, prose `:14..37`; **Makefile REPL test 80 `:1655-1658` `grep -q 'AntForth v3.0.4'`** (fourth surface, three lines :1655/:1656/:1658). Full `grep -rE 'v?3\.0\.4'` confirmed these are the ONLY surfaces.
- [x] Confirm `git tag` state: `v3.0.1`, `v3.0.2`, `v3.0.3`, `v3.0.4` all present and contiguous; `v3.0.4` tags `2808ce3` (Epic 19.5 close). No tag-gap to reconcile. Next tag = **v3.0.5** (AC8).

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [x] **Q1 — close-out version number.** Resolved **v3.0.5** (AskUserQuestion 2026-06-12, recommended option). Downstream mapping shift (Epic 21 → v3.0.6, Epic 22 → v3.0.7) annotated in the epics file.
- [x] **Q2 — envelope-reconciliation SCP granularity (AC7).** Resolved **dedicated SCP file** (AskUserQuestion 2026-06-12, recommended option) → `sprint-change-proposal-2026-06-12.md`.

### Story tasks

- [x] **Task 1 — Version-surface alignment to 3.0.5** (AC: #1, #4)
  - [x] Sub-1.1 `src/antforth.asm:781` banner `v3.0.4` → `v3.0.5` (same-length; **0 B kernel delta** verified by clean rebuild → still 27625 B; `strings build/antforth.com` shows `AntForth v3.0.5`).
  - [x] Sub-1.2 `README.md` version refs → 3.0.5 (heading `:14`; supports-line; version-history prose — added a 3.0.5 sentence for the bank-aware lookup surface; reconciled the "carried to Epic 20" forward-reference to "3.0.5 delivers the bank-aware lookup surface"). Historical 3.0.x prose intact.
  - [x] Sub-1.3 Makefile REPL test 80 banner assertion `v3.0.4` → `v3.0.5` (test-infra; 0 B). test-80 now PASS on `AntForth v3.0.5`.
  - [x] Sub-1.4 `project_phase4_scope.md` memory `description` updated (Epic-20 close-out / 3.0.5; corrected the stale "v3.0.4 tag HELD" — v3.0.4 IS tagged on 2808ce3); Epic 20 bullet → DONE with the +680 B SCP-rebaseline note + downstream mapping shift.
  - [x] Sub-1.5 `make check-doc-sync` clean (31 advisory / 0 drift, unchanged); **closed the deferred §5.5 reconciliation** (AC4): `docs/antforth-banking-redesign.md §5.5` resolution prose rewritten from the superseded per-wordlist-`bank`-field design to the shipped single-global-wordlist + inline 24-bit fat-pointer mechanism (what+why, no provenance).

- [x] **Task 2 — Verdict-table walk** (AC: #2)
  - [x] Sub-2.1 3-row Epic-20 verdict table in Dev Notes (20.1 / 20.2 / 20.3) with one-line evidence + HW-transcript references. No `review → done` reconciliation needed (20.1/20.2 already `done`).

- [x] **Task 3 — CCD-4 banked-word stub-count metric** (AC: #3)
  - [x] Sub-3.1 Captured empirically: fresh-boot first bank-N stub xt = `$D4CB` (= STUB_ALLOC_BASE → boot tail == base → **0 stubs at boot**); second = `$D4CF` → **4 B stride**. Region `$D4CB..$DBFF` = 1845 B = **461-stub cap** → **0/461 (0%) at boot — unchanged vs Story 19.4**. NFR-P4-4: 4 B ≤ 5 B ✓; 1000-word target 4000 B ≤ 5 KB ✓.

- [x] **Task 4 — AC5 integration probe** (AC: #5)
  - [x] Sub-4.1 New isolated fixture `tests/banking_tests_20_3.fth` + Makefile target `test-repl-banking-isolated-20-3` + `.PHONY` (mirrors `-20-2`). Three-bank (5/6/7) WORDS unified-listing (a) + bank-aware `'`/`BANK-OF` home-bank resolution (b) + bank/slot-2 restore after traversals (c) + plain `?NOSUCH? ?` FR-P4-30-retired (d). Sentinel-bounded; lines ≤ TIB_SIZE 128. **5 PASS / 0 FAIL.**
  - [x] Sub-4.2 `disk/a/P203INTG.FTH` CP/M 8.3 HW copy, `0x1A`-terminated; HW-ordered (suite-end sentinel before the typo abort, probe-d last with no BYE — mirrors `P202WRDS.FTH`). file-sanity 0 errors.

- [x] **Task 5 — Full test surface sweep** (AC: #6)
  - [x] Sub-5.1 All targets green against the v3.0.5 build: test-repl **975/0** (test-80 now v3.0.5) · test-repl-banking **61/0** · isolated 20-1 **6/0** · 20-2 **5/0** · 20-3 (new) **5/0** · 19-3/19-4/19-5-1 **15/2/2** · straddle **3/3** · file-sanity **0 errors** · check-doc-sync **0 drift** (31 advisory).

- [x] **Task 6 — Epic-20 envelope SCP reconciliation** (AC: #7)
  - [x] Sub-6.1 Re-derived +680 B by clean worktree rebuilds (2808ce3 = 26945 B; HEAD = 27625 B).
  - [x] Sub-6.2 Per Q2, wrote `sprint-change-proposal-2026-06-12.md` (design-substitution rationale: localised FIND tweak → fat-pointer header-format migration; ~480–540 B multiplier re-baseline still exceeded because it is a design substitution, not a same-design overshoot — multiplier explicitly NOT applied); NFR-P4-5 8 KB fixed-memory cap confirmed unaffected; disposition logged in Dev Notes.

- [~] **Task 7 — Hardware smoke + close-out tag** (AC: #6, #8) — *user-gated; recipes provided, execution deferred to Ant*
  - [x] Sub-7.1 HW-smoke recipe for the AC5 integration probe provided in the closing chat message (STRONG rule).
  - [ ] Sub-7.2 Per Q1 + user authorization, `git tag v3.0.5` on the close-out commit; push deferred to explicit go-ahead (`git push origin <branch> v3.0.5`). **PENDING user authorization** (outward-facing, per Story 19.4 precedent).

- [~] **Task 8 — Sprint-status transition** (sprint-status.yaml)
  - [x] Sub-8.1 `20-3-...` `ready-for-dev` → `in-progress` at dev-pass start (done).
  - [x] Sub-8.2 `20-3-...` `in-progress` → `review` at dev-pass close (done); CR-pass → `done` is the next gate.
  - [ ] Sub-8.3 `epic-20` → `done` at close-out (after CR-pass + tag). **PENDING** (deferred to the CR-pass + tag close gate).

## Dev Notes

### The two load-bearing draft-time drift findings (folded into ACs)

1. **Version = v3.0.5, not "3.x.4" (AC1, AC8).** The epics-file Story 20.3 §"antforth 3.x.4 tag" placeholder is stale. `git tag v3.0.4` already exists on `2808ce3` (Epic 19.5 close — "Cross-bank dispatch stabilization + banking-BIOS pivot"); banner `src/antforth.asm:781` and README `:14` already read `v3.0.4`; HEAD is `v3.0.4-6-g4c2ab0b`. README prose already narrates the v3.0.4 FIND limit as "carried to Epic 20 (bank-aware FIND)". Epic 20 ships **v3.0.5**. (B.4 / PD-2: this is exactly the figure-drift the discipline mandates re-validating — the epics-file `3.x.N` slug is a planning placeholder, never the source of the version number.)
2. **Envelope breach +680 B vs ~200 B (AC7).** Baseline-before-Epic-20 (v3.0.4 close `2808ce3`) = 26945 B; HEAD `4c2ab0b` = 27625 B → **+680 B**, 3.4× over the ~200 B envelope. Cause: Story 20.1's design substitution (per-wordlist `bank` field → 24-bit fat-pointer header-format migration). SCP re-baseline, not a clean pass. NFR-P4-5 8 KB cap unaffected.

### Epic-20 cumulative binary trajectory (re-validate at dev-pass per B.3)

| Story | Close size | Δ | Note |
|---|---|---|---|
| (Epic-20 start) | 26945 B | — | v3.0.4 close `2808ce3` (Epic 19.5 + MBB pivot) |
| 20.1 | 27516 B | +571 | bank-aware FIND — fat-pointer header-format migration (incl. +10 B fast-path inline) |
| 20.1 CR (`d078548`/`d6dc751`) | ~27622–27625 B | ~+106 | bank-aware WORDS in CR + fat-bank-byte error recovery + 9-byte label-record zeroing |
| 20.2 | 27625 B | +0 | WORDS verify + FR-P4-30 retire (no kernel code) |
| **Epic-20 total** | **27625 B** | **+680** | **3.4× OVER ~200 B envelope → SCP re-baseline (AC7)** |

Story 20.3 itself is **0 B kernel** (banner same-length swap; README / Makefile-assertion / memory / docs / test fixture are docs/infra). Re-derive each row by clean worktree rebuild at dev-pass start — the dev-pass reported figures drifted during the 20.1 CR (the 20.2 story itself documents the 27516 → 27622 drift).

### Why the FR-P4-30 error-attribution clause is retired (AC5 re-spec)

The epics-file Story 20.3 AC5 says the integration probe should show "a typo lookup … produces the attributed error message". That clause predates the Story 20.2 dev-pass, which **retired FR-P4-30**: under the shipped single-global-wordlist + inline 24-bit fat-pointer mechanism there are no per-bank wordlists to attribute, and bank-aware FIND resolves a name in any reachable bank, so a miss means "absent everywhere" with no "wrong bank" hypothesis. The `<word> ?` surface stays Phase-3-identical. The AC5 probe therefore asserts the **plain** error (matching the existing `make test-repl` "XYZZY ?" assertion), not an attributed one. (See `20-2-…md` §"FR-P4-30 retirement rationale".)

### Deferred §5.5 doc-sync item (AC4)

Story 20.2 AC5 flagged — and explicitly deferred to this close-out — that `docs/antforth-banking-redesign.md §5.5`'s *resolution* prose still describes the superseded per-wordlist-`bank`-field design (the "INTERIM GOTCHA" resolution text was written before the fat-pointer pivot). AC4 closes it: reconcile §5.5 to the shipped mechanism (single global wordlist; bucket heads + hash_links are inline 24-bit `[addr:2][bank:1]` fat pointers; page-in before deref of a window-resident address). What+why only, no provenance (`[[feedback_source_comment_discipline]]`).

### CCD-4 stub-count metric (AC3) — Story 19.4 baseline to trend against

Story 19.4 captured: 0 stubs pre-allocated at boot (`stub_alloc_tail == STUB_ALLOC_BASE = $D4CB = 54475`); per-stub stride **4 B** (54475 → 54479); region `$D4CB..$DBFF` = 1845 B = **461-stub cap** → 0/461 (0%) at boot. Epic 20 is a dictionary-*header*-format change (fat pointers in bucket heads / hash_links), **not** a descriptor-stub change — it pre-allocates no stubs — so the expected trend is **unchanged**. Confirm empirically (don't assume). NFR-P4-4: per-stub ≤ 5 B (4 B ✓); 1000-word target ≤ 5 KB total (4 KB ✓ with margin).

### Source tree components to touch

- `src/antforth.asm:781` — banner `v3.0.4` → `v3.0.5` (0 B; same length).
- `README.md:14,39` + version-history prose `:24..36` — version refs to 3.0.5 + a 3.0.5 sentence + reconcile "carried to Epic 20".
- `Makefile:1655-1658` — REPL test 80 banner assertion → v3.0.5; new `test-repl-banking-isolated-20-3` target + `.PHONY` (mirror `:872` `-20-2`).
- `docs/antforth-banking-redesign.md §5.5` — reconcile resolution prose to the fat-pointer mechanism (AC4).
- `tests/banking_tests_20_3.fth` (NEW) — AC5 integration probe.
- `disk/a/P203*.FTH` (NEW) — CP/M 8.3 HW-smoke copy, 0x1A-terminated.
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-NN.md` (NEW) — AC7 envelope re-baseline SCP record.
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` — annotate Story 20.3 § (version = v3.0.5; downstream Epic 21/22 mapping shift); FR-P4-30 / FIND-attribution AC re-spec note.
- `project_phase4_scope.md` (memory, external) — `description` + Epic 20 bullet → 3.0.5 SHIPPED / DONE.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 20.3 transitions + epic-20 → done.

### Project Structure Notes

- Story 20.3 is the Epic-20 close-out gate; **0 B kernel**. After it ships, Epic 20 is `done` and the next work is **Epic 21** (`MARKER` / `FORGET` per-bank + `ABORT` / `QUIT` bank-state restore → next tag, expected v3.0.6 per the Q1 downstream-mapping shift).
- Stories 20.1 and 20.2 are already `done` — no `review → done` reconciliation (this close-out is simpler than Story 19.4, which had three `review` stories to reconcile).
- `WORDS` and `FIND` live in `src/dictionary.asm` (the epics goal text loosely says `src/wordlists.asm`); the close-out touches no kernel code.
- Sprint-status row `20-3-epic-20-close-out-antforth-3-x-4-tag` is in the `epic-20:` block. **Note the filename/key slug `…3-x-4-tag` is itself stale drift** (it predates the v3.0.4 collision) — the file is kept at the sprint-status key for workflow consistency, but the story title and tag are **v3.0.5**.

### Detected conflicts or variances

- **Version slug drift:** sprint-status key + epics-file §"3.x.4" say 3.0.4; reality requires **3.0.5** (v3.0.4 consumed by Epic 19.5). Resolved by AC1/AC8 + Q1; the filename keeps the key per the workflow's `{story_key}.md` rule.
- **Envelope ~200 B vs realised +680 B** — reconciled via AC7 SCP re-baseline (design substitution, not a same-design overshoot; the ~200 B figure was scoped against the abandoned per-wordlist-`bank`-field design).
- **AC5 attributed-error clause stale** — FR-P4-30 retired in 20.2; the probe asserts the plain `<word> ?`.
- **Downstream version mapping shifts** — if Q1 confirms v3.0.5, the epics-file Epic 21 ("3.x.5") / Epic 22 ("3.x.6") placeholders shift to v3.0.6 / v3.0.7; annotate the epics file.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:984-1003`] — Story 20.3 §"Epic 20 close-out + antforth 3.x.4 tag" (the placeholder this story re-specs); Epic 20 goal `:906-921`.
- [Source: `_bmad-output/implementation-artifacts/20-1-…md`, `20-2-…md`] — the two shipped Epic-20 stories (fat-pointer FIND; WORDS verify + FR-P4-30 retire) this close-out reconciles.
- [Source: `_bmad-output/implementation-artifacts/19-4-epic-19-close-out-antforth-3-x-3-tag.md`] — the structural template for this close-out (version surface + verdict walk + CCD-4 stub metric + envelope SCP + tag; B.4 "fourth surface" catch at `Makefile` banner assertion).
- [Source: `src/antforth.asm:781`] — banner version string (AC1; re-validate line at dev-pass; same-length 0 B swap).
- [Source: `README.md:14,24-36,39`] — README version refs + version-history prose (AC1).
- [Source: `Makefile:1655-1658`] — REPL test 80 banner assertion (AC1 fourth surface); `:872` `test-repl-banking-isolated-20-2` recipe to mirror for `-20-3` (AC5/AC6).
- [Source: `docs/antforth-banking-redesign.md §5.5`] — bank-aware FIND / INTERIM GOTCHA; resolution prose to reconcile (AC4, deferred from 20.2 AC5). `§5.4` — per-bank state.
- [Source: `src/banking.asm` STUB_ALLOC_BASE `$D4CB`; `src/dictionary.asm` `(stub-allocate)` 4 B stride] — CCD-4 stub metric (AC3); Story 19.4 baseline.
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md`] — prior SCP record shape (AC7).
- [Source: `_bmad-output/planning-artifacts/prd.md:599`, `architecture.md:377-379`] — NFR-P4-4 (stub ≤ 5 B; ≤ 5 KB @ 1000-word target); NFR-P4-5 (8 KB Phase-4 fixed-memory cap).
- Git: `v3.0.4` = `2808ce3` (Epic 19.5 close, 26945 B); HEAD `4c2ab0b` = 27625 B; `v3.0.3` = `94c2ba0`.
- Memory: `[[project_phase4_scope]]`, `[[project_banking_bios_pivot]]`, `[[project_story20_1_fat_pointers]]`, `[[project_epic17_envelope]]`, `[[feedback_post_hw_smoke_steps_at_review]]` (STRONG), `[[feedback_no_claude_coauthor]]` (STRONG), `[[feedback_cpm_0x1a_eof_marker]]`, `[[feedback_tib_size_inline_comments]]`, `[[feedback_phase4_probe_bank_switch_limitation]]`, `[[feedback_source_comment_discipline]]`, `[[feedback_kernel_ldir_estimate_overshoot]]`, `[[feedback_no_preexisting_discharge]]`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8), dev-story workflow, 2026-06-12.

### Implementation Plan

0-byte-kernel close-out. Order executed: (1) pre-edit baseline captured via clean rebuilds + full test sweep (no source edits); (2) Q1/Q2 dispositions resolved via AskUserQuestion → v3.0.5 + dedicated SCP; (3) version surface aligned (banner same-length swap, README prose, Makefile test-80 assertion, memory, §5.5 doc reconcile); (4) AC5 integration fixture + Makefile target authored and verified on emulator; (5) full surface re-swept against the v3.0.5 build; (6) +680 B re-derived and the envelope SCP written; (7) story record + verdict walk + CCD-4 metric. HW smoke + tag/push are user-gated (recipes provided).

### Verdict-table walk (AC2)

| Story | What | Verdict | Evidence |
|---|---|---|---|
| 20.1 | bank-aware `FIND` via inline 24-bit fat dictionary pointers `[addr:2][bank:1]` | **PASS (done)** | +571 B then +10 B fast-path inline; isolated-20-1 6/0 (`result=-1` traversal probes); HW smoke PASS (`beastty-20260610-200525.bin`) |
| 20.2 | bank-aware `WORDS` verified (FR-P4-29) + FR-P4-30 retired | **PASS (done)** | 0 B kernel (WORDS shipped in 20.1 CR `d078548`); isolated-20-2 5/0; HW smoke PASS (`beastty-20260611-231019.bin`) |
| 20.3 | close-out + v3.0.5 tag | **PASS (review)** | 0 B kernel (banner same-length + docs/test-infra); isolated-20-3 5/0 new integration probe; **HW smoke PASS on real MicroBeast** (`beastty-20260612-000940.bin`) |

No `review → done` reconciliation needed — 20.1/20.2 were already `done` before this close-out.

### CCD-4 banked-word stub-count metric (AC3)

Captured empirically from a fresh boot (not assumed): the first bank-N>0 colon definition's xt = `$D4CB` and the second = `$D4CF`.
- `$D4CB` = `STUB_ALLOC_BASE` (= `ACTIVE_PAGES_BASE $D4AE` + `ACTIVE_PAGES_SIZE 29`) → boot-time `stub_alloc_tail == STUB_ALLOC_BASE` → **0 stubs pre-allocated at boot**.
- `$D4CF − $D4CB = 4` → **4 B per-stub stride** (layout v2: `$EF` RST-$28 + signed target_bank + target_addr lo/hi).
- Region `$D4CB..$DBFF` = 1845 B / 4 = **461-stub cap** → **0 / 461 (0%) at boot**.
- **Trend vs Story 19.4 baseline: UNCHANGED.** Epic 20 is a dictionary-*header*-format change (fat pointers in bucket heads + `hash_link`s), not a descriptor-stub change — it pre-allocates no stubs, as predicted.
- NFR-P4-4: per-stub 4 B ≤ 5 B ✓; 1000-banked-word target = 4000 B ≤ 5 KB ✓ (with margin).

### Envelope reconciliation (AC7)

Re-derived via clean `make clean && make` rebuilds at the dev-pass: baseline `2808ce3` (v3.0.4 close) = **26945 B**; HEAD `4c2ab0b` = **27625 B** → Epic-20 cumulative **+680 B**, 3.4× over the ~200 B Decision-Impact-Analysis target. Disposition: **accept-with-rationale + envelope retirement** (the ~200 B target was scoped against the abandoned per-wordlist-`bank`-field design; the shipped mechanism is a 24-bit fat-pointer header-format migration — a different, more capable cost class; the ~2.4–2.7× same-design multiplier does NOT apply to a design substitution and is explicitly not invoked). Recorded in `sprint-change-proposal-2026-06-12.md` (Q2 = dedicated file). NFR-P4-5 8 KB Phase-4 fixed-memory cap unaffected (+680 B is code/links, not fixed-memory growth; stub region still 0/461 at boot).

### Completion Notes List

- **0 B kernel delta confirmed end-to-end** — final clean rebuild = 27625 B (identical to HEAD); the only kernel-affecting edit is the same-length banner string. `strings build/antforth.com` → `AntForth v3.0.5`.
- **Version surface (AC1):** banner, README heading + supports-line + version-history prose (with a new 3.0.5 sentence; "carried to Epic 20" reconciled to "delivered in 3.0.5"), Makefile test-80 assertion (the B.4 "fourth surface"), and the Phase-4-scope memory `description` all advanced to 3.0.5. A full `grep -rE 'v?3\.0\.4'` confirmed these were the only surfaces.
- **AC5 integration probe** (`tests/banking_tests_20_3.fth`, 5/0): three banks' words list flat under one `WORDS`; `'`+`BANK-OF` resolve `_w53a→5` / `_w53c→7` via bank-aware FIND; bank + slot-2 restored after the traversals (`result=-1`); typo → plain `?NOSUCH? ?` (FR-P4-30 retired).
- **FR-P4-30 retired** (re-spec carried from 20.2): the integration probe asserts the plain `<word> ?`, not the stale "attributed source-bank" message.
- **AC4 §5.5 doc-sync** closed (deferred from 20.2 AC5): redesign §5.5 resolution prose now describes the shipped single-global-wordlist + fat-pointer mechanism.
- **Epics file annotated** with a dev-pass reconciliation block (version v3.0.5; downstream Epic 21 → v3.0.6 / Epic 22 → v3.0.7; FR-P4-30 retired; FR-P4-27 superseded; +680 B SCP re-baseline).
- **HW smoke PASS (AC6 / S9 / NFR-P4-11)** — Ant ran `INCLUDE P203INTG.FTH` on real MicroBeast (transcript `beastty-20260612-000940.bin`): probe-20.3-a WORDS dump lists `_w53a`/`_w53b`/`_w53c` flat from bank 0; probe-20.3-b `result=-1` (FIND+BANK-OF `_w53a→5`/`_w53c→7`); probe-20.3-c `result=-1` (bank+slot-2 restored); suite-end sentinel present; probe-20.3-d plain `?NOSUCH? ?` + `-13` recovery as the last lines. **Caveat:** the silicon binary carried the `v3.0.4` banner (it was the 27625 B HEAD before the banner edit); the v3.0.5 release binary differs only by the same-length banner string (0 B kernel delta, verified), and the AC5 mechanism is banner-independent, so the verification holds for v3.0.5 — consistent with the Story 19.5.4 same-length-banner-swap-needs-no-new-smoke precedent.
- **User-gated remainder:** `git tag v3.0.5` + push await Ant's go-ahead; `epic-20 → done` + `20-3 → done` follow the CR-pass + tag.

### File List

- `src/antforth.asm` — banner `v3.0.4` → `v3.0.5` (same-length; 0 B kernel delta).
- `README.md` — version heading + supports-line → 3.0.5; version-history prose gains a 3.0.5 sentence; "carried to Epic 20" forward-reference reconciled.
- `Makefile` — REPL test 80 banner assertion → `AntForth v3.0.5`; new `test-repl-banking-isolated-20-3` target + `.PHONY` entry.
- `docs/antforth-banking-redesign.md` — §5.5 resolution prose reconciled to the shipped fat-pointer mechanism (AC4).
- `tests/banking_tests_20_3.fth` (NEW) — AC5 integration probe (3-bank WORDS + bank-aware FIND/BANK-OF + restore + FR-P4-30-retired typo).
- `disk/a/P203INTG.FTH` (NEW) — CP/M 8.3 hardware-smoke copy, 0x1A-terminated, HW-ordered.
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-12.md` (NEW) — AC7 Epic-20 envelope re-baseline SCP record.
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` — Story 20.3 § dev-pass reconciliation annotation (version / FR-P4-30 / envelope / downstream mapping).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `20-3-…` ready-for-dev → in-progress → review.
- `_bmad-output/implementation-artifacts/20-3-epic-20-close-out-antforth-3-x-4-tag.md` — this story file (tasks, Dev Agent Record, status).
- `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` (external memory) — `description` + Epic 20 bullet → 3.0.5 / DONE.

### Change Log

| Date | Change |
|---|---|
| 2026-06-12 | Story 20.3 dev-pass: Epic-20 close-out / antforth 3.0.5. Version surface aligned (0 B kernel, 27625 B); AC5 integration fixture + Makefile target (5/0); full surface swept green (975/0 · 61/0 · 6/5/5 · 15/2/2 · 3/3 · file-sanity 0 · doc-sync 0 drift); CCD-4 stub metric 0/461 at boot (unchanged vs 19.4); §5.5 doc-sync reconciled; +680 B envelope SCP recorded (`sprint-change-proposal-2026-06-12.md`); epics file reconciled. **HW smoke PASS on real MicroBeast** (`beastty-20260612-000940.bin` — AC5 integration probe all-green on silicon; binary carried v3.0.4 banner, 0 B same-length difference from v3.0.5). `git tag v3.0.5` + push deferred to user authorization. Status → review. |
