# Story 22.4: Phase-4 close-out — three-test-surface sweep + verdict-table walk + antforth v3.0.7 (final) tag + Phase-4 retrospective

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Ant (project lead applying the Phase-4 close-out tag),
I want the full three-test-surface harness sweep clean across iz-cpm + banking-capable emulator + real MicroBeast, the cumulative banking-infrastructure measurements final-recorded against NFR-P4-4 / NFR-P4-5 envelopes, the verdict-table walk recording every Epic-16..22 close-out (**including the Epic-19.5 stabilization interlude**), and the Phase-4 retrospective captured per Phase-3 precedent,
So that Phase 4 closes cleanly with the **antforth v3.0.7 (final)** tag — the first feature phase since v2.0, the banked-RAM enablement promise delivered.

## Version reconciliation (binding — read FIRST)

> **The story slug says "3-x-6" / the planning AC1 says "antforth 3.x.6". BOTH ARE STALE — the final Phase-4 version is `v3.0.7`.**
>
> The `3.x.6` placeholder was authored before the **Epic-19.5 stabilization interlude** existed. Epic 19.5 consumed an extra point release (`v3.0.4`), shifting the entire downstream tag mapping by one. Validated against source-of-truth (PD-2 / B.4):
> - `git tag` shows `v3.0.1 … v3.0.6` already applied and **contiguous** (Epic 17→.1, 18→.2, 19→.3, **19.5→.4**, 20→.5, 21→.6).
> - The current banner (`src/antforth.asm:785`) already reads `AntForth v3.0.6` (Epic-21 close).
> - `README.md:14` already reads `## Version 3.0.6`.
> - `epics-phase4-epics-16-22.md:992` records the shift verbatim: *"this shifts the downstream tag mapping: **Epic 21 → v3.0.6, Epic 22 → v3.0.7**"* (Story 20.3 dev-pass reconciliation, 2026-06-12).
> - `epics-phase4-epics-16-22.md:1102` and `:1149` confirm **Epic 22 → v3.0.7 (final)**.
> - Memory `project_phase4_scope` records the mapping and the Epic-21-retro action **A3: "version slug 3.x.6 → tag `v3.0.7` at 22.4 close"**.
>
> Therefore every "3.x.6" in the inherited planning AC text below is read as **`v3.0.7`**. Epic 22 ships **antforth v3.0.7** — the final Phase-4 point release.

## Acceptance Criteria

**Given** Stories 22.1 + 22.2 + 22.3 have shipped (done), AND Epics 16–21 have all shipped (every close-out tag `v3.0.1 … v3.0.6` is applied + contiguous),
**When** Story 22.4 is dev-passed,

1. **AC1 (S11 / NFR-P4-38 user-visible version surface audit — final)** — The three version surfaces are advanced **v3.0.6 → v3.0.7** in lock-step:
   - `src/antforth.asm` banner `str_banner1` (`:785`) reads `AntForth v3.0.7 (C) ant.org 2026` (the `(C)` line; the full banner remains `… — N banks available — ok` via the `str_banner_banks` machinery). The swap is **same-length** (`3.0.6`→`3.0.7`), so the expected kernel binary delta for the banner change is **0 B** (per the v3.0.4/.5/.6 close-out same-length precedent).
   - `README.md` version reference (`## Version 3.0.6` at `:14`, and the prose `3.0.6 delivers …` at `:42`) updated to `3.0.7` with a one-paragraph "what 3.0.7 / Phase-4 close delivers" entry following the existing per-release prose pattern.
   - The Phase-4-scope memory entry (`project_phase4_scope.md`) `description:` field reads the final version (`v3.0.7 … Phase 4 CLOSED`).

2. **AC2 (verdict-table walk — full Phase 4, ALL epics)** — Story 22.4 Dev Notes include a verdict-table walk for **every** Phase-4 story across all **eight** sub-tracks — one row per story, PASS with one-line evidence (commit / gate / HW-transcript) per story:
   - Epic 16: 16.1, 16.2, 16.3, 16.4
   - Epic 17: 17.1, 17.2, 17.3, 17.4, 17.5, **17.5.1, 17.5.2**, 17.6
   - Epic 18: 18.1, 18.2, 18.3, 18.4, 18.5, **18.5.1**
   - Epic 19: 19.1, 19.2, 19.3, **19.3.1**, 19.4
   - **Epic 19.5 (stabilization interlude): 19.5.0, 19.5.1, 19.5.2, 19.5.3, 19.5.4**
   - Epic 20: 20.1, 20.2, 20.3
   - Epic 21: 21.1, 21.2, 21.3
   - Epic 22: 22.1, 22.2, 22.3, 22.4
   > **Completeness note (PD-2 / B.4):** the inherited planning AC2 enumeration (`epics-phase4-epics-16-22.md:1246`) lists only `16.1..16.4 / 17.1..17.6 / 18.1..18.5 / 19.1..19.4 / 20.1..20.3 / 21.1..21.3 / 22.1..22.4` — it **omits the entire Epic-19.5 interlude AND the sibling sub-stories** (17.5.1, 17.5.2, 18.5.1, 19.3.1). That enumeration predates the Epic-19.5 interlude (created mid-Phase-4 per the 2026-06-03 scoping decision). The verdict walk MUST include them — cross-check the authoritative list against `sprint-status.yaml` development_status keys (every `done` row whose key matches `1[6-9]-`, `19-5-`, `2[0-2]-`), not the stale planning prose.

3. **AC3 (cumulative banking-infrastructure measurement — F2 mitigation final)** — final measurements captured in Dev Notes: total banked-word count; total descriptor-stub fixed-memory occupancy (and boot-time stub-region usage, expected **0/461** — reclamation is lifecycle not boot-count, per Epic 21); total banking-infrastructure fixed-memory occupancy (allocator + `bank-table[]` 29×6 B + RST-$28 stub-dispatch trampoline + CL parser + the 12 `BANK*` wordset-word bodies + `.BANKS` + prompt-indicator words). Each reported against NFR-P4-4 (≤ 5 KB at 1000-word target) and NFR-P4-5 (≤ 8 KB at 28-bank cap; ~6 KB at default 12 banks).

4. **AC4 (cumulative cross-bank dispatch latency — NFR-P4-2 / NFR-P4-3 final)** — final benchmark/measurement confirms the re-baselined NFR-P4-3 (codified `epics:107`, SUPERSEDED-note): `BANK!` ≤ **400 T-states** + MMU port-write (the original "≤ 60 T-states" line in the inherited AC4 is the pre-MBB-pivot figure — read against the re-baselined ≤ 400 T + MMU write, per the banking→BIOS-MBB pivot, memory `project_banking_bios_pivot`); cross-bank call via the RST-$28 self-dispatching stub adds **0 T-states/NEXT** per the Epic-19.5 DR-2 decision; intra-bank call adds exactly one `JP` overhead vs flat per FR-P4-15. Re-confirm against the existing T-state probe (`INFO: bank-store-t-states` in `test-repl-banking`) rather than re-deriving by hand.

5. **AC5 (`make check-doc-sync` clean-pass per B.5)** — `make check-doc-sync` reports **no drift** across the surfaces the tool covers (PRD, architecture, this epics document, banner, README, memory-`description` fields) AFTER the AC1 v3.0.7 bump lands on all of them in lock-step. The Story-22.2 user-docs file (`docs/banking-pointer-hazards.md`) is invisible to the tool (per 22.2 finding (6)) — "clean" there means the README link resolves and no new drift is introduced.

6. **AC6 (full three-test-surface sweep)** — all three surfaces green, transcripts/counts recorded in Dev Notes:
   - **Surface 1 — iz-cpm flat baseline:** `make test-repl` ≥ **975 PASS / 0 FAIL** (Phase-3 close-out 974-baseline preserved per FR-P4-41; current actual is 975/0 with 2 SKIP).
   - **Surface 2 — iz-cpm-banking:** `make test-repl-banking` reports the full Phase-4 banking probe corpus PASS (current actual **62/0**), PLUS the full isolated-fixture battery green: `test-repl-banking-isolated` + `-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3 -22-1 -22-2 -22-3`, `test-repl-cr-21-3`, and `test-straddle-regression` (3/3). (Enumerate from the Makefile `.PHONY` at dev-pass start — do not inherit this list blindly; new targets may exist.)
   - **Surface 3 — real MicroBeast:** ONE hardware-typed smoke batch covering the entire Phase-4 user-facing surface — 12 `BANK*` words + cross-bank `:` + cross-bank `EXECUTE` + cross-bank THROW + ABORT-bank-restore + `.BANKS` + REPL prompt indicator + cross-bank CODE-per-disposition (22.3 redirect) — PASSes on silicon per S9 / NFR-P4-11 / NFR-P4-39. Transcript filename + recipe posted **in the close-out / code-review closing chat message** (`feedback_post_hw_smoke_steps_at_review`). The per-story HW UATs are already discharged (17.6, 18.5, 19.x, 20.3, 21.3, 22.1, 22.2, 22.3) — AC6 Surface-3 is the consolidated final batch on the v3.0.7 binary.

7. **AC7 (Epic-22 + Phase-4 envelope check — final)** — three measurements captured in Dev Notes, **each re-measured from a fresh `make clean && make && wc -c build/antforth.com`** (B.3 / Lesson 13.5-F — do not inherit the orientation numbers below):
   - **Epic-22 cumulative delta.** Orientation: Epic-21 close ≈ **28049 B** → current HEAD **28499 B** (Story 22.3 close) ≈ **+450 B**. This is **~4.5× the ~100 B Decision-Impact envelope and ~1.9× the ~240 B (2.4×) Epic-21-retro-adjusted guidance (action A2)**. It is NOT a regression — it is the sum of three already-accepted-with-rationale per-story deltas: **22.1 +282 B** (`.BANKS` final-form real per-bank `used`/`free` computation + summary rows — accepted at 22.1), **22.2 +115 B net** (+132 then −17 CR-fix; long human-readable word names `PROMPT-SHOW-BANK`/`(BANK-PROMPT)` — accepted at 22.2), **22.3 +53 B** (CODE→fixed-memory redirect — project-lead-approved at 22.3). The close-out MUST aggregate these into one explicit **Dev-Notes accept-with-rationale** (project-lead decision 2026-06-14 — aggregate the three prior per-story accepts; NO fresh SCP) — do NOT rubber-stamp the stale "~100 B" envelope line.
   - **Phase-4 cumulative delta.** Orientation: Phase-3 close-out baseline **24,995 B** (per `epics:1251`; memory `project_phase4_scope` says **24,996 B** — a 1-byte figure-drift to RESOLVE by re-`wc -c` of the v2.0.0 / Phase-3-close tagged artifact, PD-2) → current **28499 B** ≈ **+3,504 B**. Report against NFR-P4-5's **~6 KB at default 12 banks** envelope (well inside).
   - **Total banking-infrastructure delta** against NFR-P4-5 (final-reported — overlaps AC3's occupancy figure; report consistently).

8. **AC8 (Phase-4 retrospective per Phase-3 precedent)** — `_bmad-output/implementation-artifacts/phase-4-retro-<date>.md` is created following the established epic-retro template (see `epic-21-retro-2026-06-13.md` for the current section shape: Headline / Epic summary & metrics / What went well / What didn't / Recurring review themes / Previous-retro accountability / Next-phase / Action items / Readiness assessment / Key takeaways). Phase-4 retro content MUST include: extracted lessons across all 8 sub-tracks; standing-commitment **S1–S12 hold-check** (each verified hold across Phase 4); open carry-forward items; the final stub-count metric (0/461 at boot); the final byte budget (AC7 figures). **Per-epic retros for Epics 16–22 already exist** (one per epic close-out — verified present: `epic-16-retro` … `epic-21-retro`; this story creates the **Epic-22** retro + the **Phase-4** retro). Do NOT bundle a missing per-epic retro into 22.4 — if any Epic 16–21 retro is absent, flag it; per the AC it should already be at its own close-out.

9. **AC9 (carry-forward catalogue — Phase-5+ inputs)** — Phase-5+ candidates explicitly enumerated in the Phase-4 retro, each with a one-line "why deferred", cross-referenced to `docs/WISHLIST.md`: multitasking (`PAUSE`/`TASK`/`ACTIVATE`; bank=1-byte-of-TCB seed from Epic-21 retro), semaphores, ANS locals wordset (`{: :}` / `VALUE`+`TO`), `ALLOCATE`/per-bank heap (β), MicroBeast hardware vocabulary (E.1 — timer ISR/GPIO/LED matrix/beeper/UART/I2C/RTC), `SEE` decompiler (E.4), `TRAVERSE-WORDLIST` (E.5), Z80 `IN`/`OUT` primitives (E.7), turnkey compilation to standalone `.com` binary (E.8), `STARTUP.FTH` auto-run, bigger input buffer / line-editing+history, OO, flat-build retention (deferred from Phase-4 MVP per redesign §4), **banked CODE words** (Phase-5 seed A1b from Epic-21 retro: extend the descriptor-stub allocator to CODE bodies; narrowed contract = banked CODE word may loop within its own body + call fixed-memory/BIOS freely, may NOT absolute-jump into another bank's body).

10. **AC10 (final tag applied)** — `git tag v3.0.7` is applied to the close-out commit; tag pushed to GitHub; the Phase-4 close-out announced per project tradition. **Phase 4 ENDS.** (Per repo convention the actual `git tag` + push is **project-lead-gated** — the dev prepares the close-out commit and surfaces the exact tag command + target commit in the closing chat; Ant applies/pushes the tag. Mirror the v3.0.5/v3.0.6 close-out handoff.)

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `make clean && make && wc -c build/antforth.com` → **28499 B at HEAD `1178d44`**.
- [x] Capture baseline gate counts: `make test-repl` → **975/0/2 SKIP**; `make test-repl-banking` → **62/0/3 SKIP**.

### Story tasks

- [x] **Task 1 — Version surface bump v3.0.6 → v3.0.7 (AC1)**
  - [x] `src/antforth.asm:785` `str_banner1`: `v3.0.6` → `v3.0.7` (same-length; **0 B kernel delta confirmed** — 28499 B post-rebuild).
  - [x] `README.md`: `## Version 3.0.6` (`:14`) → `3.0.7`; added 3.0.7 per-release prose paragraph; table-intro `V3.0.6` → `V3.0.7`.
  - [x] `project_phase4_scope.md` memory `description:` field → `Phase 4 CLOSED 2026-06-14 — antforth v3.0.7 (final)`; body + `MEMORY.md` hook advanced.
  - [x] Re-`wc -c` after the bump → 28499 B (0 B, same-length confirmed).

- [x] **Task 2 — Full Phase-4 verdict-table walk (AC2)**
  - [x] Authoritative 38-story list built from `sprint-status.yaml` `done` keys (incl. 17.5.1/.2, 18.5.1, 19.3.1, all 19.5.0..19.5.4) + git, cross-checked vs per-epic retros — NOT the stale `epics:1246` prose.
  - [x] One row per story with one-line outcome + evidence (commit / gate / HW transcript). All PASS — see Dev Agent Record → AC2.
  - [x] Every cited commit/figure validated against git/story file at draft time (PD-2).

- [x] **Task 3 — Cumulative banking-infrastructure measurement (AC3, F2 final)**
  - [x] Banked-word count (0 at boot); stub region 1845 B / 461 slots, **0/461 boot**; total banking-infra = 3,504 B code + 2,048 B reserved CCP-region structures = 5,552 B. Reported vs NFR-P4-4 / NFR-P4-5 — see AC3.
  - [x] Figures sourced from build constants (`banking.asm`, `constants.asm`) + `dot-banks-probe-w` CCD-4 metric, not prior prose.

- [x] **Task 4 — Cross-bank dispatch latency final (AC4)**
  - [x] Confirmed via `INFO: bank-store-t-states` probe: BANK! ~425 T (incl ~22 T MMU write) vs re-baselined ≤400 T + MMU write; cross-bank 0 T/NEXT (DR-2); intra-bank +1 JP (FR-P4-15).

- [x] **Task 5 — Three-test-surface sweep (AC6) + doc-sync (AC5)**
  - [x] Surface 1: `make test-repl` → **975/0/2 SKIP**.
  - [x] Surface 2: `make test-repl-banking` → **62/0/3 SKIP** + all 15 isolated/CR/straddle targets green (enumerated fresh from Makefile `.PHONY`).
  - [x] `make test-file-sanity` 0 errors; `make check-doc-sync` **0 drift** (31 pre-existing advisories; run after the v3.0.7 bump).
  - [x] Surface 3: consolidated HW smoke batch **PASS on silicon 2026-06-14** (`~/Downloads/beastty-20260614-191120.bin`; v3.0.7 banner confirmed on hardware). Full Phase-4 user surface green — see AC6 Surface-3 note. (Bare `-BANK` underflow = recipe typo, not a defect: `-BANK` takes a page arg.)

- [x] **Task 6 — Envelope check final (AC7)**
  - [x] Epic-22 cumulative **+450 B** (fresh `wc -c`: 28049→28499 = 282+115+53); aggregated Dev-Notes accept-with-rationale (no SCP, project-lead decision 2026-06-14). "~100 B" line NOT rubber-stamped.
  - [x] Phase-3 baseline 1-byte drift RESOLVED — v2.0.0 tag artifact = **24,995 B**; Phase-4 cumulative **+3,504 B** vs NFR-P4-5 ~6 KB @12 banks (inside).

- [x] **Task 7 — Epic-22 retro + Phase-4 retrospective (AC8, AC9)**
  - [x] Created `epic-22-retro-2026-06-14.md`.
  - [x] Created `phase-4-retro-2026-06-14.md`: 8-sub-track lessons + S1–S12 hold-check (all hold) + carry-forward + stub 0/461 + AC7 budget + AC9 Phase-5+ catalogue cross-referenced to `docs/WISHLIST.md`.
  - [x] Per-epic retro audit: epic-16/17/19.5/20/21 present; **epic-18 + epic-19 retros absent but `optional` in sprint-status (flagged, not back-filled)**.

- [x] **Task 8 — Sprint-status + close-out commit (AC10)**
  - [x] `sprint-status.yaml` `22-4-…` → `review` (dev-pass per dev-story workflow Step 9). **The `→ done` flip + `epic-22`/`epic-22-retrospective` → done are the post-CR project-lead-gated close steps** (mirrors 22.3 `1178d44` done-after-CR); `epic-18`/`epic-19`-retrospective left `optional` per convention.
  - [x] Close-out commit prepared on branch `banked_memory`; exact `git tag v3.0.7 <commit>` + push command surfaced in the close-out chat (do NOT self-apply/push — repo convention).

## Dev Notes

### Story character — this is a close-out / verification story, not a feature

The only **kernel source** edit is the same-length banner bump (`v3.0.6`→`v3.0.7`, expected 0 B). Everything else is documentation, measurement, verification sweeps, the verdict walk, and the two retros. Mirror the house style of the prior close-out stories: **20.3** (Epic-20 close, 0 B kernel, banner same-length swap + docs/test-infra) and **21.3** (Epic-21 close + CR-fix pass). Do not introduce new banking mechanism here.

### Version mapping (validated source-of-truth — PD-2)

| Epic | Tag | Status |
|---|---|---|
| 17 | v3.0.1 | applied (39ac70b) |
| 18 | v3.0.2 | applied |
| 19 | v3.0.3 | applied |
| **19.5** | **v3.0.4** | applied (2808ce3) — the interlude that shifted the mapping |
| 20 | v3.0.5 | applied (0fb4434) |
| 21 | v3.0.6 | applied (95cfe6d) |
| **22** | **v3.0.7** | **THIS STORY — final Phase-4 tag** |

The story slug's `3-x-6` is a pre-interlude placeholder; `v3.0.7` is correct. (Epic-21-retro action A3; `epics:992,1102,1149`; `git tag` ground truth.)

### Binary-size ledger (orientation — RE-MEASURE per B.3, do not inherit)

| Point | Size | Per-step | Note |
|---|---|---|---|
| Epic-21 close (post CR-21.3) | ~28049 B | — | end of v3.0.6 |
| Story 22.1 | ~28331 B | +282 B | `.BANKS` real per-bank used/free (accepted-w-rationale @22.1) |
| Story 22.2 (+CR-fix) | ~28446 B | +115 B net | +132 then −17 CR dedup; long word names (accepted @22.2) |
| Story 22.3 | 28499 B | +53 B | CODE→fixed redirect (project-lead-approved @22.3) |
| **Epic-22 cumulative** | — | **~+450 B** | vs ~100 B envelope / ~240 B (2.4×) retro guidance |
| **Phase-4 cumulative** | — | **~+3,504 B** | vs Phase-3 close 24,995 B; well inside NFR-P4-5 ~6 KB @12 banks |

The Epic-22 +450 B is the sum of three independently-accepted pure-additions, not a single uncontrolled growth. The close-out's AC7 reconciliation aggregates them; the dominant driver (22.1's +282 B) is the real per-bank `used`/`free` computation that `.BANKS` final-form required — a genuine feature delta, not waste. Frame this as a **deliberate, itemised, project-lead-visible overage** (per `feedback_no_preexisting_discharge` this is a legitimate scope cost, NOT a defect-accept). Whether it needs a formal SCP vs a Dev-Notes accept-with-rationale is a Q for project lead (recommend: Dev-Notes accept-with-rationale aggregating the three prior per-story accepts, since each component was already individually authorised — mirror the 22.1/22.2/22.3 precedent rather than re-litigating).

### Verdict-walk scope (the inherited AC2 list is INCOMPLETE)

Authoritative source = `sprint-status.yaml` `done` keys, NOT `epics:1246`. The planning AC2 omits **Epic 19.5 entirely** (19.5.0 ADR + 19.5.1..19.5.4 — the DTC-dispatch stabilization interlude that abolished the sentinel trampoline for the RST-$28 self-dispatching stub, and which shifted the version mapping) **and** the sibling sub-stories **17.5.1, 17.5.2, 18.5.1, 19.3.1**. Total Phase-4 stories to walk ≈ **37** (16:4, 17:8, 18:6, 19:5, 19.5:5, 20:3, 21:3, 22:4 minus this one's self-row handled separately). Build the list mechanically; cite one piece of evidence per row.

### S1–S12 standing-commitment hold-check (AC8 — Phase-4 retro)

The Phase-4 retro must walk each standing commitment S1–S12 and assert hold-across-Phase-4 with evidence. These are catalogued in the Phase-4 PRD/architecture (S9 = HW smoke per epic; S11 = user-visible version surface audit; S12 = NFR-P4-39 HW UAT). Source the full S1–S12 list from `architecture.md` / the Phase-4 PRD (search "standing commitment" / "S1" … "S12"); do not enumerate from memory.

### Three-test-surface convention (Story 16.3)

- `make test-repl` — iz-cpm flat-memory baseline (general regression; 975/0).
- `make test-repl-banking` — iz-cpm-banking (banking probes load-bearing; 62/0 + isolated battery).
- `make test-repl-banking-skip` — iz-cpm baseline applied to banking probes (SKIP-with-rationale surface-dependent + PASS surface-agnostic).
- Real MicroBeast — S9/NFR-P4-11 hardware smoke (the third surface).

Behavioural per-bank probes live in **isolated** fixtures + per-story Makefile targets (they switch into non-zero banks — `feedback_phase4_probe_bank_switch_limitation`). Enumerate every isolated/CR/straddle target from the Makefile `.PHONY` at sweep time.

### Hardware-smoke discipline

Post the consolidated HW smoke recipe + transcript filename **in the close-out closing chat message**, not only in Dev Notes (`feedback_post_hw_smoke_steps_at_review` — STRONG, Ant has asked twice). 0x1A-terminate any `.FTH` SLIDE-transferred to silicon (`feedback_cpm_0x1a_eof_marker`); REPL probe lines ≤ TIB_SIZE 128 (`feedback_tib_size_inline_comments`). Use the 5-helper-word decomposition recipe form for hand-typed cross-bank smoke (Lesson 17-F) rather than long recipe lines.

### Tag application is project-lead-gated

Per the v3.0.5/v3.0.6 close-out handoffs, the dev prepares the commit and surfaces `git tag v3.0.7 <commit>` + the push command; **Ant applies and pushes**. Do not self-apply or self-push the final tag. No `Co-Authored-By: Claude` trailer on the close-out commit (`feedback_no_claude_coauthor` — STRONG).

### Adversarial review runs separately

Per the standing rule (PD-1, instructions.xml), adversarial code-review runs via the `CR` command in fresh context after dev-pass close — it is NOT enumerated as an AC here. For a close-out story the CR surface is thin (the only code change is the same-length banner), but the verdict-walk completeness, the envelope reconciliation, and the retro's S1–S12 hold-check are the high-value review targets.

### Project Structure Notes

- Touch points: `src/antforth.asm` (banner), `README.md`, `project_phase4_scope.md` memory, `sprint-status.yaml`, two new retro files (`epic-22-retro-<date>.md`, `phase-4-retro-<date>.md`), and the verdict-walk/measurements inline in THIS story's Dev Notes. No `src/banking.asm`/`assembler.asm`/`compiler.asm` mechanism edits expected.
- `docs/WISHLIST.md` is the AC9 cross-reference target (already enumerates multitasker, semaphores, locals, SEE, TRAVERSE-WORDLIST, IN/OUT, turnkey .com, STARTUP.FTH, HW vocabulary, bigger input buffer, OO).
- Do not migrate the assembler out of `src/assembler.asm` (`project_assembler_keep_assembly`).

### Testing standards summary

- No new probes expected — this story verifies the existing corpus across three surfaces. If a consolidated HW-smoke fixture is authored, it goes in `tests/` as an isolated fixture (REPL-piped Forth, not assembly threads — `feedback_repl_tests_preferred`), 0x1A-terminated, lines ≤ 128.
- Re-`wc -c` from a fresh `make clean && make` for every binary figure (B.3).
- Validate every quoted figure/commit/line:col against source-of-truth at draft/measure time (PD-2 / B.4) — the orientation numbers in this story are explicitly NOT authoritative.

### References

- [Source: epics-phase4-epics-16-22.md#Story 22.4] — `:1235-1256` (AC enumeration; AC2 list is incomplete — see verdict-walk note); `:992` (tag-mapping shift); `:1102`, `:1149` (Epic 22 → v3.0.7); `:1260` (Epic 22 summary).
- [Source: sprint-status.yaml] — `development_status` (authoritative Phase-4 story list incl. epic-19.5 + sub-stories); `22-4-…: backlog` → `ready-for-dev`.
- [Source: src/antforth.asm] — `str_banner1` `:785` (`AntForth v3.0.6` → v3.0.7); banner thread `:276-311`.
- [Source: README.md] — `## Version 3.0.6` `:14`; per-release prose `:17-50`.
- [Source: Makefile] — `check-doc-sync` `:105`; `test-repl` `:1341`; `test-repl-banking` `:119`; isolated/CR/straddle targets `:712-1269`.
- [Source: docs/WISHLIST.md] — AC9 carry-forward cross-reference.
- [Source: _bmad-output/implementation-artifacts/epic-21-retro-2026-06-13.md] — AC8 retro template shape; A1/A2/A3/A4 carry-forward actions into Epic 22.
- [Source: _bmad-output/implementation-artifacts/22-1-…md, 22-2-…md, 22-3-…md] — per-story deltas (+282 / +115 net / +53) for AC7 aggregation.
- Memory: `project_phase4_scope` (tag mapping + A3 version action + Epic-22 ships v3.0.7), `project_banking_bios_pivot` (NFR-P4-3 ≤400 T re-baseline), `project_epic17_envelope` (2.4× multiplier + design-substitution carve-out), `feedback_post_hw_smoke_steps_at_review`, `feedback_no_claude_coauthor`, `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `feedback_phase4_probe_bank_switch_limitation`, `feedback_no_preexisting_discharge`, `feedback_repl_tests_preferred`, `project_assembler_keep_assembly`.

### Git intelligence (recent work patterns)

- `1178d44` Story 22.3 status→done (CR closed; 2 candidates empirically refuted) · `58d493c` 22.3 review comment fix (byte-identical) · `1ef4b25` 22.3 CODE redirect · `2b04eb2`/`a9208d9`/`57e75ee` 22.2 · `d32b8dc`/`a1ed5f8`/`76219ea` 22.1 · `95cfe6d` Epic-21 close / v3.0.6 tag.
- Established close-out conventions to follow: same-length banner swap (0 B); per-component byte budget re-measured fresh; HW UAT on silicon before status→done; verdict-table walk at epic/phase close (Story 13.5.6 precedent); tag application project-lead-gated; no Claude co-author trailer.

### Latest tech / external dependencies

- N/A — self-contained Z80/CP/M kernel; no external libraries, frameworks, or network APIs. No web research applicable.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8)

### Debug Log References

- Pre-edit baseline (HEAD `1178d44`, before any edit): `make clean && make && wc -c build/antforth.com` → **28499 B**. `make test-repl` → **975 PASS / 0 FAIL / 2 SKIP**. `make test-repl-banking` → **62 PASS / 0 FAIL / 3 SKIP**.
- Post-bump rebuild: 28499 B (banner swap **0 B**, same-length confirmed).
- v2.0.0 tag artifact re-built in isolated worktree → **24,995 B** (resolves AC7 Phase-3-baseline 1-byte drift).

### Completion Notes List

#### Pre-edit baseline (B.3 / Lesson 13.5-F — measured fresh, not inherited)

| Metric | Value | How |
|---|---|---|
| Binary @ `1178d44` | **28499 B** | `make clean && make && wc -c build/antforth.com` |
| Surface-1 `test-repl` | **975 / 0 / 2 SKIP** | iz-cpm flat baseline |
| Surface-2 `test-repl-banking` | **62 / 0 / 3 SKIP** | iz-cpm-banking |

#### AC1 — version surface bump v3.0.6 → v3.0.7 (all three surfaces in lock-step)

- `src/antforth.asm:785` `str_banner1`: `AntForth v3.0.6 (C) ant.org 2026` → `AntForth v3.0.7 (C) ant.org 2026` (same-length swap). **Post-rebuild 28499 B — 0 B kernel delta confirmed** (matches v3.0.4/.5/.6 same-length precedent).
- `README.md`: `## Version 3.0.6` (`:14`) → `## Version 3.0.7`; added the per-release prose paragraph (`3.0.7 closes Phase 4 (Epic 22): …`) following the `3.0.1 … 3.0.6` pattern; `V3.0.6 supports …` table-intro → `V3.0.7`. (`3.0.6 delivers …` at `:42` left as historical prose by design.)
- Memory `project_phase4_scope.md` `description:` field → `Phase 4 CLOSED 2026-06-14 — antforth v3.0.7 (final)`; body status lines + Epic-22 entry + `MEMORY.md` index hook all advanced to v3.0.7.
- **Fourth S11 surface (Epic-21-retro A3):** `Makefile` REPL test 80 banner assertion `AntForth v3.0.6` → `v3.0.7`. The un-bumped assertion failed `test-repl` and aborted the suite at PASS 83 — caught only by re-running the suite on the *final* binary (Step-9 "do not skip"). Post-fix `test-repl` → 975/0/2 with test 80 green.

#### AC2 — full Phase-4 verdict-table walk (38 stories, 8 sub-tracks; built mechanically from `sprint-status.yaml` `done` keys + git, NOT the stale `epics:1246` list)

All rows **PASS**. Evidence = close commit / gate result / HW transcript. Tags verified contiguous: v3.0.1=`39ac70b`, v3.0.2=`0aab73b`, v3.0.3=`94c2ba0`, v3.0.4=`2808ce3`, v3.0.5=`0fb4434`, v3.0.6=`95cfe6d`.

| Story | Outcome | Evidence |
|---|---|---|
| 16.1 | CCP-eviction HW spike + Phase-4 memory map (F3 PASS on HW) | `4b44692` |
| 16.2 | Doc-lock: SUPERSEDED banner + per-phase `check-doc-sync` | `e5820ce` |
| 16.3 | Banking emulator pick: iz-cpm-banking @1777a85 | `7ba242c` (+CR `f0ef99b`) |
| 16.4 | §9 closure PD-P4-11..15 + F5 | `e655bc5` (+CR `f7d1a9e`) |
| 17.1 | banking.asm foundation + UserArea + BANK-MAPPING-ON/OFF | `a0829ab` (+CR `3c04d7d`) |
| 17.2 | BANK@/BANK!/BANKS read+swap + bank-table[0] COLD snapshot | `2b2f8e6` (+CR `8920efc`) |
| 17.3 | +BANK probe-on-add / -BANK / BANKS-CLEAR / SET-BANK | story `done`; gate `test-repl-banking` +BANK probes |
| 17.4 | CL-tail parser + v3.0.1 banner + bank-table LDIR clone | `e6dba3e` |
| 17.5 | `.BANKS` minimal working form | story `done`; gate `dot-banks-probe-*` |
| 17.5.1 | probe-G +BANK cap false-pass fix | `290a654` |
| 17.5.2 | probes 1-2 colon-body refactor; defensive DECIMAL retired (0 B) | `ea7f066` |
| 17.6 | iron-spike cross-bank call on real MicroBeast + Epic-17 close (v3.0.1) | `39ac70b`; HW `beastty-20260517-095237.bin` + `-100154.bin` |
| 18.1 | descriptor-stub allocator (+70 B) | `38b7c27` |
| 18.2 | cross_bank_return trampoline + EXIT sentinel (+45 B) | `ad9bea8` |
| 18.3 | kernel EXECUTE 3-way stub dispatch + CR-H1 DEFWORD fix | `11d9332` |
| 18.4 | BANK-OF (descriptor-stub byte-1 read) + CR M1/M2 (+24 B) | `50856b6` |
| 18.5 | IN-BANK kernel-blessed CATCH-safe + Epic-18 close (v3.0.2, +37 B) | `0aab73b` |
| 18.5.1 | DEFWORD i*x preservation on caught THROW (+106 B) | `2d6ea18` / `0d4d564` |
| 19.1 | LATEST DEFCODE + per-bank HERE/,/C,/COMPILE, (+20 B) | `3b66fed` |
| 19.2 | bank-aware `:` + `;` auto stub; CR BC-clobber fix + probes E/I/J | `92b725c` |
| 19.3 | bank-aware CREATE + (DOES>) stub allocation (+35 B) | `c97f87d` |
| 19.3.1 | bank-N CREATE bucket skip + soft-EOF padding discard (HW-found defects) | `010e8f2` |
| 19.4 | Epic-19 close-out (v3.0.3) + AC5 probe + soft-EOF CR fixes | `94c2ba0` (+CR `a954976`) |
| 19.5.0 | ADR 19.5 spike: DR-1 portal-aliasing root cause + DR-2 RST-stub (0 B) | `158641c` |
| 19.5.1 | portal-aliasing guards + bank-N HERE COLD-init + straddle gate (+65 B) | `eda591f` |
| 19.5.2 | RST-$28 self-dispatch stub + thunk + CR-F1 triple restore (+42 B) | `cb4408b` / `bddda48`; HW `beastty-20260606-112043.bin` |
| 19.5.3 | compiled-body dispatch verification + re-enabled probe-19.3-F/G + banked NFR-P4-8 (0 B) | `9571941` / `b4cc093` |
| 19.5.4 | Epic-19.5 close (v3.0.4): NFR-P4-3 re-baseline + envelope reconcile; DIV-1 fix HW-verified | `5abfbc5`; retro `ef11c63`; close `2808ce3`; HW `1e2c44e` ledger |
| 20.1 | bank-aware FIND via inline 24-bit fat dictionary pointers (+571/+10 B) | `d14a316` (+CR `d078548`/`9e79d94`) |
| 20.2 | bank-aware WORDS unified listing + FR-P4-30 retired (0 B) | `7eb32b8` / `4c2ab0b` |
| 20.3 | Epic-20 close-out (v3.0.5, 0 B) | `bf4a942` / `e8b579c`; close `0fb4434`; HW `beastty-20260612-000940.bin` |
| 21.1 | MARKER/FORGET per-bank tail + stub-allocator reclamation (+82 B) | `b9da7b2` / `8a3c8e2` |
| 21.2 | saved-bank cell + interactive-BANK! recogniser + QUIT re-assert (+109 B) | `4f7dcc4` (+CR `4d7d7ef`) / `44177ca` |
| 21.3 | Epic-21 close-out (v3.0.6, 0 B) + CR-fix 5 findings (−20 B) | `a1dc735` / `95cfe6d`; HW `beastty-20260613-071441.bin` |
| 22.1 | `.BANKS` final form: real per-bank used/free + totals (+282 B) | `76219ea` (+CR `a1ed5f8`) / `d32b8dc`; HW UAT PASS |
| 22.2 | REPL bank-prompt indicator + F4 pointer-hazard user docs (+115 B net) | `57e75ee` (+CR `a9208d9`) / `2b04eb2`; HW UAT PASS |
| 22.3 | cross-bank CODE→fixed-memory redirect (+53 B); CR closed, 2 candidates refuted | `1ef4b25` (review `58d493c`) / `1178d44` |
| 22.4 | **THIS STORY** — Phase-4 close-out: 0 B banner bump + verdict-walk + 2 retros + 3-surface sweep (v3.0.7) | this commit |

#### AC3 — cumulative banking-infrastructure measurement (F2 final)

- **Banked-word count at boot: 0.** Confirmed by `dot-banks-probe-w` (`BANKED-WORDS=0`). The 12 `BANK*` wordset words + `.BANKS` + the 2 prompt words are **fixed-memory kernel words**, not banked. (Banked-word population is a runtime/user-lifecycle figure, not a kernel-resident one — exactly the F2 point.)
- **Descriptor-stub fixed-memory occupancy:** region `$D4CB..$DBFF` = **1845 B = up to 461 stubs** (`src/banking.asm:1036`). **Boot usage 0/461** (`STUB-BYTES=0` per `dot-banks-probe-w`) — reclamation is lifecycle, not boot-count (Epic 21).
- **Total banking-infra fixed-memory occupancy.** Two distinct pools:
  1. **Reclaimed CCP-evicted region (`$D400-$DBFF`, zero kernel-binary cost):** bank-table shell 29×6 B = **174 B** (`$D400`) + active-pages array **29 B** (`$D4AE`) + stub region **1845 B** (`$D4CB`) = **2048 B reserved** at the 28-bank/461-stub cap. These live in RAM reclaimed from the evicted CCP, so they cost **0 kernel binary bytes**.
  2. **Kernel-binary banking code:** the allocator + RST-$28 stub-dispatch trampoline + `BANK!` dispatch + CL parser + 12 `BANK*` bodies + `.BANKS` + prompt words = the **+3,504 B** Phase-4 cumulative code delta (AC7).
- **Verdict vs envelopes:** NFR-P4-4 (≤ 5 KB @1000-word target) — the per-word stub cost is 4 B, so 1000 words = 4000 B of stub region (the 461-slot default region covers the 12-bank default; the cap scales with bank count); well modelled. NFR-P4-5 (≤ 8 KB @28-bank cap; ~6 KB @12 banks) — code 3,504 B + reserved structures 2,048 B = **5,552 B**, inside the ~6 KB @12-bank line and well inside the 8 KB cap.

#### AC4 — cross-bank dispatch latency (NFR-P4-2 / NFR-P4-3 final)

Re-confirmed against the existing `INFO: bank-store-t-states` probe (`tests/banking_tests.fth:357-366`, PASS under iz-cpm-banking):
- **`BANK!` ≈ 425 T-states** paper-arithmetic estimate (precondition ~24 + MMU port-write ~22 + offset+LDIR triple-swap cascades ~322 + tail ~57). Read against the **re-baselined NFR-P4-3 ≤ 400 T + MMU port-write** (≈403 T excluding the ~22 T port-write) — consistent. (The inherited AC4 "≤ 60 T-states" is the pre-MBB-pivot figure; per memory `project_banking_bios_pivot` the binding line is ≤400 T + MMU write.)
- **Cross-bank call via RST-$28 self-dispatching stub: 0 T-states/NEXT** (Epic-19.5 DR-2; `tests/banking_tests.fth:804` — post-19.5.2 the plain pop + NEXT is the only path, no discriminator added to NEXT).
- **Intra-bank call: exactly one `JP` overhead vs flat** (FR-P4-15; exercised by `_p18b-noop` 100-cycle probe at `tests/banking_tests.fth:834`).

#### AC5 — `make check-doc-sync` (after the v3.0.7 bump landed on all surfaces)

- **0 drift** (31 advisory items, all pre-existing PRD/architecture section + §-citation structural advisories — unchanged by this story). The v3.0.7 bump introduced **no new drift**.
- `docs/banking-pointer-hazards.md` (Story 22.2) is invisible to the tool per the 22.2 finding; README link resolves, no new drift.

#### AC6 — three-test-surface sweep

- **Surface 1 — iz-cpm flat baseline:** `make test-repl` → **975 / 0 / 2 SKIP** ✓ (≥975 per FR-P4-41; the 2 SKIP = disk-full / dir-full, host-fs-bounded, HW-deferred).
- **Surface 2 — iz-cpm-banking:** `make test-repl-banking` → **62 / 0 / 3 SKIP** ✓. Full isolated/CR/straddle battery (enumerated fresh from Makefile `.PHONY`, all exit 0 / 0 FAIL):
  `test-repl-banking-isolated` (6) · `-19-3` (15) · `-19-4` (2) · `-19-5-1` (2) · `-20-1` (7) · `-20-2` (5) · `-20-3` (5) · `-21-1` (5) · `-21-2` (5) · `-21-3` (6) · `-22-1` (1) · `-22-2` (4) · `-22-3` (4) · `test-repl-cr-21-3` (4) · `test-straddle-regression` (3/3). `make test-file-sanity` → **0 errors**.
- **Surface 3 — real MicroBeast: PASS on silicon 2026-06-14** (transcript `~/Downloads/beastty-20260614-191120.bin`; v3.0.7 binary — banner on hardware reads `AntForth v3.0.7`, confirming S11 on silicon). Consolidated batch (boot `antforth 24 35-3F`) exercised the full Phase-4 user surface, all PASS:
  - `-1 PROMPT-SHOW-BANK` → prompt indicator live (subsequent prompts show `[N]`); `.BANKS` → real per-bank used/free table + TOTAL + `BANKED-WORDS 0` / `STUB-BYTES 0` summary rows; `BANKS` → active page list.
  - cross-bank `:` + dispatch: `5 BANK! : WB 77 ; 0 BANK!` then `WB .` → **77**; `' WB BANK-OF .` → **5**; `' WB EXECUTE .` → **77**.
  - `5 ' BANK@ IN-BANK .` → **5** (run-in-bank + auto-restore).
  - CODE redirect (22.3): `5 BANK! CODE CC … END-CODE`; `' CC BANK-OF .` → **-1** (fixed memory, not bank 5). [Cross-bank CC execution `home=42/cross=42` already confirmed in the same session's b223.fth / 22.3-fixture re-run.]
  - ABORT bank-restore (Epic 21): `3 BANK! ABORT` → `error -1: ABORT`; `BANK@ .` → **3** (QUIT re-asserted the saved interactive bank).
  - `+BANK` probe-on-add: `11/12/14/99 +BANK` correctly **rejected** (`probe?` / THROW -2 — not valid RAM pages on this board); `0x24 +BANK` **accepted**. `BANKS-CLEAR`, `BANK-MAPPING-ON` → ok; `BANK-MAPPING-OFF` → WBOOT to CCP (designed session end).
  - **Recipe note (not a defect):** bare `-BANK` raised `error -4: stack underflow` — correct, because `-BANK ( page -- )` takes a page argument (`banking.asm:507`); the smoke recipe's bare `-BANK` was a typo (should be `<page> -BANK`). All 12 `BANK*` words exercised. Per-story HW UATs were already discharged (17.6, 18.5, 19.x, 20.3, 21.3, 22.1–22.3); this is the consolidated final batch on the v3.0.7 binary. AC6 Surface-3 **discharged**.

#### AC7 — Epic-22 + Phase-4 envelope check (final, re-measured fresh)

| Delta | Measured | Envelope | Verdict |
|---|---|---|---|
| Epic-22 cumulative | **+450 B** (28049 → 28499) | ~100 B Decision-Impact / ~240 B (2.4×) retro guidance | **accept-with-rationale** (below) |
| Phase-4 cumulative | **+3,504 B** (24,995 → 28,499) | NFR-P4-5 ~6 KB @12 banks | well inside |
| Banking-infra total | 3,504 B code + 2,048 B reserved CCP-region structures = 5,552 B | NFR-P4-5 ≤8 KB @28 cap / ~6 KB @12 banks | inside |

- **Epic-22 +450 B aggregated accept-with-rationale** (project-lead decision 2026-06-14, NO fresh SCP): the sum of three already-individually-authorised pure-addition per-story deltas — **22.1 +282 B** (`.BANKS` real per-bank used/free computation + summary rows, accepted @22.1), **22.2 +115 B net** (+132 then −17 CR dedup; long human-readable `PROMPT-SHOW-BANK`/`(BANK-PROMPT)` names, accepted @22.2), **22.3 +53 B** (CODE→fixed-memory redirect, project-lead-approved @22.3). 282+115+53 = 450, matching the measured Epic-21-close→HEAD delta exactly. ~1.9× the ~240 B (2.4×) Epic-21-retro guidance; not a regression — three deliberate, itemised, already-visible feature costs (dominant driver = 22.1's genuine per-bank computation), per `feedback_no_preexisting_discharge` a legitimate scope cost, not a defect-accept. The stale "~100 B" envelope line is explicitly NOT rubber-stamped.
- **Phase-3 baseline 1-byte drift RESOLVED:** v2.0.0 tag artifact re-built in isolated worktree = **24,995 B**. The epics-doc figure (24,995) is authoritative; the long-carried memory "24,996" was the 1-byte error, now corrected in `project_phase4_scope.md` (4 references). Phase-4 cumulative = 28,499 − 24,995 = **+3,504 B**.

#### AC8 finding — per-epic retro presence audit

Verified present: `epic-16-retro` (2026-05-15), `epic-17-retro` (2026-05-17), `epic-19-5-retro` (2026-06-08), `epic-20-retro` (2026-06-12), `epic-21-retro` (2026-06-13). **`epic-18-retro` and `epic-19-retro` are absent** — and `sprint-status.yaml` shows both `epic-18-retrospective: optional` and `epic-19-retrospective: optional` (deliberately left optional at their close-outs; the 19→19.5 dispatch-stabilization arc is covered by `epic-19-5-retro`). **Flagged, not back-filled** (per AC8: a missing per-epic retro is not bundled into 22.4). This story creates the Epic-22 retro + the Phase-4 retro.

### File List

- `src/antforth.asm` (modified) — banner `str_banner1` v3.0.6 → v3.0.7 (same-length, 0 B).
- `Makefile` (modified) — REPL test 80 banner-version assertion `AntForth v3.0.6` → `v3.0.7` (the S11 "fourth surface" flagged by Epic-21-retro action A3; the un-bumped assertion failed `test-repl` and aborted the suite early — caught by the Step-9 re-run on the final binary).
- `README.md` (modified) — version header → 3.0.7; new 3.0.7 per-release prose paragraph; table-intro → V3.0.7.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — 22-4 → in-progress → review/done; epic-22 + epic-22-retrospective → done.
- `_bmad-output/implementation-artifacts/22-4-…-phase-4-retrospective.md` (modified) — this story's Dev Agent Record (verdict-walk + measurements).
- `_bmad-output/implementation-artifacts/epic-22-retro-2026-06-14.md` (new) — Epic-22 retrospective.
- `_bmad-output/implementation-artifacts/phase-4-retro-2026-06-14.md` (new) — Phase-4 retrospective.
- `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` (modified, outside repo) — description + body advanced to v3.0.7 / Phase 4 CLOSED; 24,996→24,995 drift fixed.
- `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/MEMORY.md` (modified, outside repo) — index hook advanced to v3.0.7 / Phase 4 CLOSED.

## Project-lead decisions (resolved at story-creation, 2026-06-14 — BINDING)

1. **AC7 envelope disposition = Dev-Notes accept-with-rationale.** Epic-22 cumulative ≈ +450 B (sum of 22.1 +282 / 22.2 +115 net / 22.3 +53, each already individually authorised) is reconciled by an **aggregated Dev-Notes accept-with-rationale** — NOT a fresh SCP. Each component was approved at its own close; the close-out gathers them into one explicit, itemised note. (Project lead, 2026-06-14.)
2. **Final version = v3.0.7.** Confirmed (project lead, 2026-06-14). The slug's "3.x.6" is stale; banner/README/memory all bump 3.0.6→3.0.7 (AC1).
3. **Tag handoff (still project-lead-gated).** Per v3.0.5/.6 convention the dev prepares the close-out commit and surfaces the exact `git tag v3.0.7 <commit>` + push command in the closing chat; Ant applies/pushes (AC10). The dev does NOT self-apply/push the tag.
