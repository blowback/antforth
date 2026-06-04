# Story 19.4: Epic 19 close-out + antforth 3.0.3 tag

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-04 by create-story workflow on the Story 19.4 turn.
     Story 19.4 is the Epic 19 close-out gate: it ships the *verified
     bank-aware compiler mechanism* (Stories 19.1–19.3.1) as antforth
     3.0.3, with the compiled-body cross-bank DISPATCH debt documented
     as out-of-epic (anchored on the new Epic 19.5 stabilization
     interlude — see epics-phase4-epics-16-22.md). Close-out is a
     0-byte-kernel gate (version-surface alignment + integration probe
     + verdict-table walk + CCD-4 stub-count metric + tag).

     THREE CR-pass findings (2026-06-03, code-review of the Epic-19
     cluster) are load-bearing for this story and were folded into the
     ACs below — do NOT re-discover them at dev-pass:

       (1) ENVELOPE BREACH (AC7). Epic-19 cumulative is +303 B, VERIFIED
           by clean worktree rebuild (19.1 +20 → 26603; 19.2 +123 →
           26726; 19.3 +35 → 26761; 19.3.1 +125 → 26886). The dev-pass
           records for 19.3 (+33) and 19.3.1 (+89) were both wrong and
           were CR-corrected on 2026-06-03. 303 B is OVER the ~300 B
           Epic-19 line envelope. AC7 must record an accept-with-
           rationale + sprint-change-proposal envelope re-baseline,
           NOT a clean ≤300 B pass.

       (2) AC5 EXECUTE-EXPLICIT (integration probe). The north-star UX
           probe must NOT use the compiled-body symbolic-invocation
           form `0 BANK! FROM-FIVE .` — that path is BLOCKED by the DTC
           threading-through-stub-xt defect and the cross-bank-
           trampoline-assumes-DOCOL/EXIT defect, both anchored on Epic
           19.5. The integration probe uses the EXECUTE-explicit form
           (`' FROM-FIVE EXECUTE` / `LATEST @ EXECUTE`), mirroring the
           19.2/19.3 CR-pass AC rewordings.

       (3) DEBT CARRY-FORWARD. The DTC/HW dispatch debt is documented
           out-of-epic and anchored on Epic 19.5 (DTC threading;
           cross-bank trampoline non-DOCOL targets; intra-bank-EXECUTE-
           into-slot-2 HW gap; CATCH-cross-bank reboot; bank-N HERE
           COLD-init). Epic 19 closes shipping the verified MECHANISM,
           not the behavioural compiled-body dispatch.

     The close-out also reconciles the review-state of 19.2/19.3/19.3.1:
     all three are at `review` with their kernel mechanisms CR-verified-
     correct and their behavioural gaps carried to Epic 19.5. Per the
     2026-06-03 scoping decision (project lead), the verified-mechanism
     basis lets them transition `review → done` at this close-out so the
     epic can close. See AC2 + the Q-disposition at dev-pass start. -->

## Story

As Ant (the project lead applying the Epic 19 close-out tag),
I want the user-visible version surface aligned to `3.0.3` (banner / README / memory `description`), the full four-test-surface sweep clean across iz-cpm + iz-cpm-banking + the isolated fixtures, the banked-word stub-count metric captured per CCD-4, the Epic-19 envelope overage reconciled via a sprint-change-proposal record, the verdict-table walk recorded (including the carry-forward of the compiled-body dispatch debt to Epic 19.5), and the `v3.0.3` tag applied,
so that Epic 19's *verified bank-aware compiler mechanism* ships as antforth 3.0.3 with an honest, reconciled close-out — the behavioural compiler-transparent-banking promise (calling a banked word from a compiled definition) is explicitly deferred to the Epic 19.5 stabilization interlude, not silently claimed.

## Acceptance Criteria

**Given** Stories 19.1 + 19.2 + 19.3 + 19.3.1 have shipped (bank-aware `HERE`/`LATEST`/`,`/`COMPILE,`/`:`/`CREATE`/`DOES>` kernel mechanism; all four CR-reviewed 2026-06-03 with kernel mechanisms verified-correct; current binary 26886 B at HEAD per clean worktree rebuild of `010e8f2`) and Epic 19.5 has been registered as the stabilization interlude that owns the compiled-body dispatch debt (`epics-phase4-epics-16-22.md` Epic 19.5 section),
**When** Story 19.4 is dev-passed,

**Then** AC1 (S11 / NFR-P4-38 user-visible version surface audit) — the version surface is aligned to `3.0.3`:
- `src/antforth.asm:772` `str_banner1` reads `"AntForth v3.0.3 (C) ant.org 2026"` (currently `v3.0.2`); this is a same-length string edit → **0 B kernel delta**.
- `README.md` version references advance to `3.0.3` (currently `## Version 3.0.2` at `:14`, `V3.0.2 supports...` at `:27`, and the version-history prose at `:17..25`; note `:25` already forward-references `antforth 3.0.3+`).
- The Phase-4-scope memory entry's `description` field (`project_phase4_scope.md`) advances to note `antforth 3.0.3 SHIPPED` (Epic 19 close).
- Re-validate every cited file:line at dev-pass start per B.4 / PD-2 figure-drift discipline (line numbers shift as files grow).

**And** AC2 (verdict-table walk per Story-13.5.6 precedent + review-state reconciliation) — Story 19.4 Dev Notes include a verdict-table walk for all Epic-19 stories with one-line evidence each:
- 19.1 — per-bank `HERE`/`LATEST`/`,`/`COMPILE,` — PASS (done).
- 19.2 — bank-aware `:` + stub-on-`;` — kernel mechanism CR-verified-correct; compiled-body AC4/AC5 carried to Epic 19.5.
- 19.3 — bank-aware `CREATE`/`DOES>` — kernel mechanism CR-verified-correct (+35 B, CR-corrected from +33); compiled-body AC3/DOES> + DOVAR-target cross-bank carried to Epic 19.5.
- 19.3.1 — INCLUDE-EOF (Defect-1) + bucket-pollution (Defect-2) fixes — CR-verified-correct (+125 B, CR-corrected from +89); CR-noted that Defect-2's specific CR-symptom root cause is unconfirmed (bucket-pollution hardened).
- The close-out reconciles the `review` state of 19.2/19.3/19.3.1: on the verified-mechanism basis (per the 2026-06-03 scoping decision), transition each `review → done` with the behavioural debt explicitly carried to Epic 19.5 (Q1 at dev-pass start confirms this disposition with the project lead before flipping).

**And** AC3 (banked-word stub-count metric per CCD-4 + F2 mitigation) — Story 19.4 Dev Notes capture: total banked-word descriptor-stub count after Epic 19 (`(stub_alloc_tail − STUB_ALLOC_BASE) / 4` across the test surfaces); total descriptor-stub fixed-memory occupancy; trend vs the Story 18.5 baseline; assert against the stub-allocation envelope (redesign §7: ~4–5 KB per 1000 words; STUB_ALLOC_BASE = $D4CB, region cap 461 stubs). This becomes the per-epic CCD-4 close-out line item from Story 19.4 forward (F2 mitigation operational).

**And** AC4 (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no NEW drift between PRD, architecture, this epics document, and the banner / README versions beyond the 31-advisory baseline (the version-surface edits in AC1 must keep banner/README/epics version strings mutually consistent).

**And** AC5 (integration probe — the verified mechanism in one breath, EXECUTE-explicit form per CR finding (2)) — a single probe in the isolated banking fixture exercises the verified Epic-19 mechanism end-to-end **via EXECUTE-explicit dispatch only**: boot with defaults; `5 BANK!`; `CREATE FROM-FIVE 100 ,` (or `: FROM-FIVE 100 ;`) defines into bank 5; `LATEST @` captures the stub-xt; `LATEST @ BANK-OF` returns `5`; `LATEST @ EXECUTE` (intra-bank) and a stashed-xt `0 BANK! <xt> EXECUTE` (cross-bank, sentinel-trampoline) dispatch correctly with the caller bank restored. **The compiled-body symbolic-invocation form (`0 BANK! FROM-FIVE .`) is OUT OF SCOPE and must NOT appear in this probe** — it is blocked by the DTC + non-DOCOL-trampoline defects anchored on Epic 19.5. The probe carries an inline comment stating that the symbolic-invocation north-star UX lands in Epic 19.5, not here.

**And** AC6 (four-test-surface sweep) — all baselines preserved (re-validate at dev-pass start per B.3): `make test-repl` ≥ **975 PASS / 0 FAIL / 2 SKIP**; `make test-repl-banking` ≥ **61 PASS / 0 FAIL / 3 SKIP**; `make test-repl-banking-isolated` ≥ **6 PASS / 0 FAIL**; `make test-repl-banking-isolated-19-3` ≥ **3 PASS + 2 DEFER** (Probe-19.3-F/G defer-sentinels stay deferred — anchored on Epic 19.5; Probe-19.3.1-A + suite = +2 PASS); `make test-repl-banking-skip` ≥ **25 PASS / 0 FAIL / 3 SKIP**. Hardware smoke: the Epic-19 bank-N hardware verdict is already discharged (Story 19.3.1 AC5, transcript `~/Downloads/beastty-20260522-152152.bin`); a close-out hardware smoke of the AC5 EXECUTE-explicit integration probe runs on real MicroBeast per S9 / NFR-P4-11, with the HW-smoke recipe in the closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.

**And** AC7 (Epic-19 envelope reconciliation per CR finding (1) — accept-with-rationale + SCP record) — the **verified** Epic-19 cumulative binary delta is **+303 B** (19.1 +20, 19.2 +123, 19.3 +35, 19.3.1 +125; cumulative `wc -c build/antforth.com` = 26886 B at HEAD, baseline-before-Epic-19 = 26583 B; re-validate at dev-pass start per B.3). This is **OVER the ~300 B Epic-19 Decision-Impact-Analysis envelope** → AC7 does NOT assert a clean ≤300 B pass; instead it records a sprint-change-proposal envelope re-baseline: the empirical Phase-4 binary-delta pattern is ~2.4–2.7× the redesign-§7 spec target ([[project_epic17_envelope]]), which puts Epic-19's realistic envelope at ~720–810 B — 303 B sits comfortably inside the re-baselined envelope. NFR-P4-5's 8 KB Phase-4 fixed-memory cap is unaffected (303 B is a small fraction). The SCP record is written to `_bmad-output/planning-artifacts/` (sprint-change-proposal-2026-06-NN.md) and the disposition is logged in this story's Dev Notes.

**And** AC8 (Epic-19.5 debt carry-forward documented per CR finding (3)) — Story 19.4 Dev Notes carry forward the explicit Epic-19.5 anchor list (DTC threading-through-stub-xt; cross-bank trampoline assumes DOCOL/EXIT — non-DOCOL targets hang, Probe-19.3-F; intra-bank-EXECUTE-into-slot-2 HW gap, Probe-19.2-F; CATCH-around-cross-bank-EXECUTE reboot; bank-N HERE COLD-init, H5; the `src/antforth.asm:206,209` H5 source comment still referencing "Story 19.5" to be re-pointed to Epic 19.5 in Story 19.5.1). The close-out makes explicit that Epic 19 ships the verified mechanism, and the behavioural compiler-transparent-banking promise is Epic-19.5 scope.

**And** AC9 (tag applied) — `git tag v3.0.3` is applied to the close-out commit; tag pushed to GitHub release. **Pre-tag check (surfaced at CR draft):** the `v3.0.2` tag appears to be ABSENT from `git tag` output (only `v3.0.1` is present despite Epic 18's close claiming `v3.0.2` applied) — verify whether `v3.0.2` needs to be (re)applied to the Epic-18 close-out commit before or alongside `v3.0.3`, OR whether Epic 18 was tagged under a different scheme (Q2 at dev-pass start).

**FRs covered:** none directly (close-out + integration verification of the Epic-19 verified mechanism). **NFRs codified:** NFR-P4-5 (envelope reconciliation — SCP record); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic-level decoupling — antforth 3.0.3 ships); NFR-P4-38 (S11 version surface); NFR-P4-39 (S12).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → **26886 B** (clean `make clean && make` rebuild of HEAD `010e8f2`). Matches expected.
- [x] Capture current `make test-repl` baseline → **975 PASS / 0 FAIL / 2 SKIP**.
- [x] Capture current `make test-repl-banking` baseline → **61 PASS / 0 FAIL / 3 SKIP**.
- [x] Capture current `make test-repl-banking-isolated` baseline → **6 PASS / 0 FAIL**.
- [x] Capture current `make test-repl-banking-isolated-19-3` baseline → **5 PASS + 2 DEFER** (incl. Probe-19.3.1-A + suite).
- [x] Capture current `make test-repl-banking-skip` baseline → **25 PASS / 0 FAIL / 3 SKIP**.
- [x] Capture current `make check-doc-sync` baseline → **31 advisory / 0 drift**.
- [x] Re-validate AC1 version-surface citations against source-of-truth (per B.4): banner `src/antforth.asm:772` = `v3.0.2` ✓; README `## Version 3.0.2` :14, `V3.0.2 supports` :27, prose :17-25 ✓; memory `description` ✓. **B.4 catch:** a fourth version-surface reference NOT cited in AC1 — REPL test 80 banner assertion at `Makefile:1549-1553` (`grep 'AntForth v3.0.2'`) — was discovered when the post-edit `test-repl` run FAILed; advanced to v3.0.3 (test-infra; 0 B).
- [x] Confirm `git tag` state re: `v3.0.2` presence/absence (AC9 pre-tag check): **`v3.0.2` is genuinely ABSENT** (`git tag` shows `v3.0.1` as the highest present). Q2 → apply v3.0.2 to Epic-18 close-out commit `0aab73b` (verified: v3.0.2 banner, ancestor of HEAD).

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [x] **Q1 — review→done transition for 19.2/19.3/19.3.1.** **Resolved α** (AskUserQuestion 2026-06-04): transition all three `review → done` on the verified-mechanism basis; behavioural debt carried to Epic 19.5; verdict-table walk records the carry-forward. Applied in `sprint-status.yaml`.
- [x] **Q2 — `v3.0.2` tag reconciliation.** **Resolved α** (AskUserQuestion 2026-06-04): `v3.0.2` is genuinely absent; apply it to the Epic-18 close-out commit `0aab73b` before/alongside `v3.0.3` so tag history is contiguous. (Tag application pending CR-pass + user authorization — see Task 8.)
- [x] **Q3 — SCP record granularity (AC7).** **Resolved α** (AskUserQuestion 2026-06-04): dedicated SCP record written at `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md`.

### Story tasks

- [x] **Task 1 — Version-surface alignment to 3.0.3** (AC: #1, #4)
  - [x] Sub-1.1 `src/antforth.asm:772` banner `v3.0.2` → `v3.0.3` (same-length; **0 B kernel delta** verified — clean rebuild still 26886 B; banner confirmed in binary via `strings`).
  - [x] Sub-1.2 `README.md` version refs → 3.0.3 (heading :14; supports-line :32; version-history prose extended with a 3.0.3 sentence; the historical "3.0.2 completes the wordset" prose left intact).
  - [x] Sub-1.3 `project_phase4_scope.md` memory `description` → antforth 3.0.3 SHIPPED 2026-06-04 (Epic 19 close); Epic 19 bullet → DONE with +303 B SCP-rebaseline note.
  - [x] Sub-1.4 `make check-doc-sync` clean (**31 advisory / 0 drift** — unchanged; no version/banner drift).

- [x] **Task 2 — Verdict-table walk + review→done reconciliation** (AC: #2)
  - [x] Sub-2.1 4-row Epic-19 verdict table written in Dev Notes (below) with one-line evidence + Epic-19.5 carry-forward notes.
  - [x] Sub-2.2 Per Q1-α, transitioned 19.2/19.3/19.3.1 `review → done` in `sprint-status.yaml` (each annotated with the verified-mechanism basis + Epic-19.5 carry-forward).

- [x] **Task 3 — CCD-4 banked-word stub-count metric** (AC: #3)
  - [x] Sub-3.1 Captured empirically: boot-time `stub_alloc_tail == STUB_ALLOC_BASE` ($D4CB=54475) → **0 stubs at boot**; per-stub stride **4 B** (confirmed: 1st `(stub-allocate)`=54475, 2nd=54479); region `$D4CB..$DBFF` = 1845 B = 461-stub cap → **0/461 (0%) at boot**; trend vs Story 18.5 baseline: unchanged (allocator + 4 B/stub contract from Story 18.1; Epic 19 consumes it at runtime, pre-allocates none).

- [x] **Task 4 — AC5 integration probe (EXECUTE-explicit)** (AC: #5)
  - [x] Sub-4.1 New isolated fixture `tests/banking_tests_19_4.fth` + Makefile target `test-repl-banking-isolated-19-4`; Probe-19.4-A exercises BANK-OF + intra-bank EXECUTE + cross-bank EXECUTE end-to-end (colon body, EXECUTE-explicit only); sentinel-bounded; lines ≤ TIB_SIZE. **2 PASS / 0 FAIL.**
  - [x] Sub-4.2 Inline comment block states the symbolic-invocation north-star UX is Epic-19.5 scope, not here; documents why a colon body (not CREATE) is used (cross-bank EXECUTE of a DOVAR target hangs — Probe-19.3-F).

- [x] **Task 5 — Four-test-surface sweep** (AC: #6)
  - [x] Sub-5.1..5.5 All targets green against the v3.0.3 build: test-repl 975/0/2 · test-repl-banking 61/0/3 · isolated 6/0 · isolated-19-3 5 PASS+2 DEFER · isolated-19-4 2 PASS · banking-skip 25/0/3.

- [x] **Task 6 — Epic-19 envelope SCP reconciliation** (AC: #7)
  - [x] Sub-6.1 Re-derived: pre-Epic-19 baseline `ea7f066` clean worktree build = **26583 B**; HEAD = **26886 B** → **+303 B** (= 20+123+35+125).
  - [x] Sub-6.2 Per Q3-α, wrote `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` (envelope re-baseline ~720–810 B; 303 B inside); disposition logged in Dev Notes.

- [x] **Task 7 — Epic-19.5 debt carry-forward** (AC: #8)
  - [x] Sub-7.1 Epic-19.5 anchor list recorded in Dev Notes (carry-forward section); cross-referenced epics-doc Epic 19.5 (`:875`); confirmed `src/antforth.asm:206,209,213` H5 comment still says "Story 19.5" → re-point to "Epic 19.5" owed to Story 19.5.1 (forward work, not this story).

- [~] **Task 8 — Hardware smoke + close-out tag** (AC: #6, #9)
  - [x] Sub-8.1 HW-smoke recipe for the AC5 EXECUTE-explicit integration probe provided in the closing chat message (STRONG rule).
  - [x] Sub-8.2 Per Q2, `v3.0.2` reconciled (annotated tag on `0aab73b`) + `v3.0.3` applied to the close-out commit — user-authorized 2026-06-04 ("check in and tag") after CR-pass. Push deferred (not in the authorization; `git push origin banked_memory v3.0.2 v3.0.3` when ready).

- [~] **Task 9 — Sprint-status transition** (sprint-status.yaml)
  - [x] Sub-9.1 `19-4-...` `ready-for-dev` → `in-progress` at dev-pass start.
  - [x] Sub-9.2 `19-4-...` `in-progress` → `review` at dev-pass close.
  - [x] Sub-9.3 `epic-19` → `done` at close-out (2026-06-04, post-CR-pass; `19-4-...` row → `done` in the same edit).
  - [x] Sub-9.4 CR-pass completed 2026-06-04 (7 findings → fixed; see 19.3.1 artifact §"CR-pass 2026-06-04" — the kernel findings all live in the 19.3.1 review-fix delta).

## Dev Notes

### The three load-bearing CR-pass findings (2026-06-03) — folded into ACs

1. **Envelope breach (AC7).** Epic-19 cumulative is **+303 B** (verified by clean worktree rebuilds: 19.1 26603, 19.2 26726, 19.3 26761, 19.3.1 26886; baseline-before-Epic-19 = 26583). The 19.3 dev-pass recorded +33 (real +35) and 19.3.1 recorded +89 (real +125); both CR-corrected 2026-06-03. 303 B > ~300 B Epic-19 envelope → SCP re-baseline (not a clean pass). NFR-P4-5 8 KB cap fine.
2. **AC5 EXECUTE-explicit.** Compiled-body symbolic invocation (`0 BANK! FROM-FIVE .`) is blocked by the DTC + non-DOCOL-trampoline defects (Epic 19.5). Integration probe uses EXECUTE-explicit dispatch only.
3. **Debt carry-forward (AC8).** Epic 19 ships the verified mechanism; behavioural compiled-body dispatch is Epic-19.5 scope.

### Epic-19 cumulative binary trajectory (verified 2026-06-03; re-validate at dev-pass per B.3)

| Story | Close size | Δ | Note |
|---|---|---|---|
| (Epic-19 start) | 26583 B | — | end of Epic 18 |
| 19.1 | 26603 B | +20 | per-bank HERE/LATEST/,/COMPILE, |
| 19.2 | 26726 B | +123 | bank-aware `:` + stub-on-`;` |
| 19.3 | 26761 B | +35 | CREATE/DOES> (CR-corrected from +33) |
| 19.3.1 | 26886 B | +125 | INCLUDE-EOF + bucket-skip (CR-corrected from +89) |
| **Epic-19 total** | **26886 B** | **+303** | **OVER ~300 B line envelope → SCP re-baseline (AC7)** |

Story 19.4 itself is **0 B kernel** (banner string is same-length; README/memory are docs).

### Epic 19.5 carry-forward anchor list (AC8)

Per `epics-phase4-epics-16-22.md` Epic 19.5 section (the stabilization interlude that superseded the never-spawned "Story 19.5"):
- DTC threading-through-stub-xt (NEXT `JP (HL)` into a stub).
- Cross-bank trampoline assumes a DOCOL/EXIT pair — non-DOCOL targets (`DOVAR`/`DOCON`/`VARIABLE`/code-words) hang (Probe-19.3-F; a distinct root cause).
- Intra-bank-EXECUTE-into-slot-2 HW gap (Probe-19.2-F hung on real MicroBeast).
- CATCH-around-cross-bank-EXECUTE reboot.
- Bank-N HERE COLD-init collision (H5); the `src/antforth.asm:206,209` H5 comment still says "Story 19.5" → re-point to Epic 19.5 in Story 19.5.1.
- Epic 19.5 leads with an ADR spike (trampoline-fragility root-cause + DTC dispatch architecture A/B/C).

### Source tree components to touch

- `src/antforth.asm:772` — banner version string `v3.0.2` → `v3.0.3` (0 B; same length).
- `README.md` — version refs to 3.0.3.
- `project_phase4_scope.md` (memory) — `description` + Epic 19 bullet → 3.0.3 SHIPPED / DONE.
- isolated banking fixture (`tests/banking_tests_19_*.fth` or a new `tests/banking_tests_19_4.fth`) — AC5 EXECUTE-explicit integration probe.
- `Makefile` — wire the integration probe into a close-out target if a new fixture is added.
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-NN.md` — NEW (AC7 SCP record).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 19.4 transitions + 19.2/19.3/19.3.1 review→done + epic-19 → done.

### Project Structure Notes

- Story 19.4 is the Epic-19 close-out gate; 0 B kernel. After it ships, Epic 19 is `done` and the next work is Epic 19.5 (stabilization interlude; ADR-first) — NOT Epic 20 (Epic 19.5 is the interlude inserted between 19 and 20 per the Epic-11.5/13.5 precedent).
- Stories 19.2/19.3/19.3.1 are at `review` with kernel mechanisms CR-verified-correct (2026-06-03) and behavioural gaps carried to Epic 19.5; AC2 + Q1 reconcile their state at this close-out.
- Sprint-status row `19-4-epic-19-close-out-antforth-3-x-3-tag` is in the `epic-19:` block (sprint-status.yaml :459), immediately after `19-3-1-...`.

### Detected conflicts or variances

- **`v3.0.2` tag absent from `git tag`** (only `v3.0.1` present at draft time) despite Epic 18's close claiming `v3.0.2` applied. Surfaced as Q2 / AC9 pre-tag check — reconcile at dev-pass start (don't blindly apply only `v3.0.3` if the tag history should be contiguous).
- **Epic-19 envelope ~300 B vs realised 303 B** — reconciled via AC7 SCP re-baseline (the ~300 B figure was a redesign-§7 spec target; the empirical pattern is 2.4–2.7× per [[project_epic17_envelope]]).
- **Epic close with stories in `review`** — resolved by Q1 (transition to `done` on verified-mechanism basis); if (β) chosen, document the epic-`done`-with-review-stories semantics.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` Story 19.4 section + Epic 19 close-out reframing note + Epic 19.5 section] — close-out scope + the three CR findings + carry-forward
- [Source: `_bmad-output/implementation-artifacts/19-2-...md`, `19-3-...md`, `19-3-1-...md`] — the three CR-reviewed stories (CR-pass corrections 2026-06-03) this close-out reconciles
- [Source: `src/antforth.asm:772`] — banner version string (AC1; re-validate line at dev-pass)
- [Source: `README.md:14,17,25,27`] — README version refs (AC1)
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-04-27.md` etc.] — prior SCP record shape (AC7)
- [Source: `feedback_post_hw_smoke_steps_at_review.md`] — STRONG: HW-smoke recipe in closing chat message
- [Source: `feedback_no_claude_coauthor.md`] — STRONG: no Claude co-author trailer in commits
- [Source: `project_epic17_envelope.md`] — empirical 2.4–2.7× spec-target pattern (AC7 re-baseline)
- [Source: `project_phase4_scope.md`] — Phase-4 scope; Epic 19 closing via 3.0.3; Epic 19.5 stabilization interlude
- [Source: ANS Forth 1994 §6.1.0070 `'`, §6.1.2510 `[']`, §6.1.1550 `FIND`] — xt semantics for the EXECUTE-explicit integration probe

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — dev-story workflow, 2026-06-04.

### Debug Log References

- B.4 figure-drift catch: the post-edit `make test-repl` aborted at REPL test 80 (`FAIL: expected 'AntForth v3.0.2' in output`, got `AntForth v3.0.3`). Root cause: a banner-version regression assertion at `Makefile:1549-1553` that AC1 did not enumerate. Advanced the assertion to `v3.0.3` (test-infra; 0 B). Re-run → 975/0/2. This is exactly the version-surface reference class B.4/PD-2 mandates re-validating; AC1's three cited surfaces were complete but the test-suite assertion was a fourth, uncited surface.

### Completion Notes List

**Epic-19 close-out verdict-table walk (AC2):**

| Story | Mechanism | Verdict | Evidence | Epic-19.5 carry-forward |
|---|---|---|---|---|
| 19.1 | per-bank `HERE`/`LATEST`/`,`/`COMPILE,` | **PASS (done)** | +20 B; shipped + CR-clean | — |
| 19.2 | bank-aware `:` + stub-on-`;` | **kernel mechanism CR-verified-correct** → done (Q1-α) | +123 B; isolated probes D/E/F/G/I PASS (6/0) | compiled-body AC4/AC5 (DTC threading-through-stub-xt) |
| 19.3 | bank-aware `CREATE`/`DOES>` | **kernel mechanism CR-verified-correct** → done (Q1-α) | +35 B (CR-corrected from +33); isolated-19-3 5 PASS + 2 DEFER | compiled-body AC3/DOES> + DOVAR-target cross-bank (Probe-19.3-F, non-DOCOL trampoline) |
| 19.3.1 | INCLUDE-EOF (Defect-1) + bucket-pollution (Defect-2) fixes | **CR-verified-correct** → done (Q1-α) | +125 B (CR-corrected from +89); Probe-19.3.1-A PASS | CR-noted Defect-2's specific CR-symptom root cause unconfirmed (bucket-pollution hardened) |

**AC1 (version surface → 3.0.3):** banner `src/antforth.asm:772` (0 B same-length swap, verified in binary); README heading/supports-line/prose; memory `project_phase4_scope.md` description + Epic 19 bullet; **+** the uncited fourth surface — REPL test 80 banner assertion (`Makefile:1549-1553`) advanced to v3.0.3 (see Debug Log).

**AC3 (CCD-4 stub metric):** 0 stubs pre-allocated at boot (`stub_alloc_tail == STUB_ALLOC_BASE = $D4CB`); per-stub stride 4 B (empirically: 54475 → 54479); region `$D4CB..$DBFF` = 1845 B = 461-stub cap → 0/461 (0%) at boot; trend vs Story 18.5: unchanged (allocator + 4 B/stub contract from Story 18.1; Epic 19 consumes at runtime, pre-allocates none). This is the per-epic CCD-4 close-out line item from 19.4 forward (F2 mitigation operational).

**AC5 (integration probe, EXECUTE-explicit):** `tests/banking_tests_19_4.fth` Probe-19.4-A — `5 BANK!` → `: _p194a-tgt 100 ;` → `LATEST @` stub-xt → `BANK-OF`=5 + stub-in-region → intra-bank `EXECUTE`=100 → `0 BANK!` cross-bank `EXECUTE`=100 + caller bank restored. **2 PASS** under iz-cpm-banking. Symbolic-invocation north-star UX explicitly OUT OF SCOPE (Epic 19.5). Colon body (not CREATE) chosen because cross-bank EXECUTE of a DOVAR target hangs the trampoline (Probe-19.3-F).

**AC6 (four-test-surface sweep):** test-repl 975/0/2 · test-repl-banking 61/0/3 · test-repl-banking-isolated 6/0 · test-repl-banking-isolated-19-3 5 PASS + 2 DEFER · test-repl-banking-isolated-19-4 2 PASS · test-repl-banking-skip 25/0/3 · check-doc-sync 31 advisory / 0 drift. Hardware: Epic-19 bank-N verdict already discharged (Story 19.3.1 AC5); AC5 close-out HW smoke recipe in the closing chat message (S9 / NFR-P4-11).

**AC7 (envelope reconciliation):** verified Epic-19 cumulative **+303 B** (baseline-before-Epic-19 `ea7f066` = 26583 B clean worktree build; HEAD = 26886 B; = 20+123+35+125). OVER the ~300 B raw spec target → SCP re-baseline (`sprint-change-proposal-2026-06-04.md`): realistic envelope ~720–810 B per the ~2.4–2.7× empirical pattern ([[project_epic17_envelope]]); 303 B sits well inside. NFR-P4-5 8 KB fixed-memory cap unaffected. Story 19.4 itself = **0 B kernel** (banner same-length; README/memory/tests are docs/infra).

**AC8 (Epic-19.5 debt carry-forward):** anchor list — (a) DTC threading-through-stub-xt (`NEXT` blind `JP (HL)`); (b) cross-bank trampoline assumes DOCOL/EXIT pair — non-DOCOL targets (DOVAR/DOCON/VARIABLE/code-words) hang (Probe-19.3-F, distinct root cause); intra-bank-EXECUTE-into-slot-2 HW gap (Probe-19.2-F); CATCH-around-cross-bank-EXECUTE reboot; bank-N HERE COLD-init (H5). Epics-doc Epic 19.5 at `epics-phase4-epics-16-22.md:875` (ADR-first interlude). `src/antforth.asm:206,209,213` H5 comment still references "Story 19.5" → re-point to "Epic 19.5" owed to Story 19.5.1.

**AC9 (tag) — PENDING CR-pass + user authorization.** `v3.0.2` is genuinely absent locally; Q2-α → apply to Epic-18 close-out `0aab73b` (verified v3.0.2 banner, ancestor of HEAD), then `v3.0.3` to the 19.4 close-out commit, then push. Commit + tag + push are outward-facing and the close-out commit does not yet exist — recipe provided in the closing chat message; not executed during the dev-pass.

### File List

- `src/antforth.asm` (M) — banner `v3.0.2` → `v3.0.3` (`:772`; 0 B same-length) + version-trajectory comment.
- `README.md` (M) — version heading/supports-line → 3.0.3 + 3.0.3 version-history sentence.
- `Makefile` (M) — REPL test 80 banner assertion → v3.0.3; new `.PHONY` + `test-repl-banking-isolated-19-4` target.
- `tests/banking_tests_19_4.fth` (A) — AC5 EXECUTE-explicit integration probe (Probe-19.4-A).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` (A) — AC7 Epic-19 envelope re-baseline SCP record.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (M) — 19.4 in-progress→review; 19.2/19.3/19.3.1 review→done (Q1-α).
- `_bmad-output/implementation-artifacts/19-4-epic-19-close-out-antforth-3-x-3-tag.md` (M) — this story (tasks, Dev Notes, Dev Agent Record).
- `~/.claude/.../memory/project_phase4_scope.md` (M, external) — `description` + Epic 19 bullet → 3.0.3 SHIPPED / DONE.

### Change Log

- 2026-06-04 — Story 19.4 dev-pass (Epic-19 close-out). Version surface aligned to antforth 3.0.3 (banner 0 B + README + memory + REPL test 80 assertion). AC5 EXECUTE-explicit integration probe added (`tests/banking_tests_19_4.fth` + Makefile target; 2 PASS). Four-test-surface sweep clean (975/0/2 · 61/0/3 · 6/0 · 5+2 DEFER · 25/0/3) + new isolated-19-4 surface (2 PASS). CCD-4 stub metric captured (0 stubs at boot, 4 B/stub, 0/461 region). AC7 Epic-19 envelope reconciled at +303 B via dedicated SCP record (`sprint-change-proposal-2026-06-04.md`; ~720–810 B re-baseline). 19.2/19.3/19.3.1 reconciled `review → done` (Q1-α, verified-mechanism basis). Story → review. PENDING CR-pass + user authorization: commit, `git tag v3.0.2` (on `0aab73b`) + `v3.0.3` (close-out commit), push, `epic-19 → done`.
- 2026-06-04 (CR pass + close-out) — Adversarial CR over the full working tree (7 angles → 10 deduped candidates → 4 CONFIRMED / 4 PLAUSIBLE / 2 REFUTED); all findings fixed same day. Kernel findings live in the 19.3.1 review-fix delta — recorded in the 19.3.1 artifact §"CR-pass 2026-06-04" (F1 `fid_validate` chokepoint in `(file-refill)`; F2 latch-semantics comment corrections; F3 `clear_eof_seen` helper; F4 entry-gate `LD L,B`; F5 `tests/banking_tests_19_4.fth` 0x1A trailer; F6 padding-discard residual documented). **Post-CR metrics supersede the dev-pass figures:** close-out binary **26834 B** (−52 B vs `010e8f2`); Epic-19 cumulative **+251 B — back UNDER the ~300 B line envelope** (the SCP record stands as the decision artifact for the transient +303 B breach; its ~720–810 B re-baseline guidance remains for Epic-20+ planning). Sweep re-verified green post-fix (975/0 · 61/0 · isolated base/19-2/19-3/19-4 · skip · file-sanity · doc-sync 0 drift). User authorization received ("check in and tag"): close-out commit + annotated `v3.0.2` (on `0aab73b`) + `v3.0.3` tags applied; push deferred. Story → done; `epic-19` → done.
