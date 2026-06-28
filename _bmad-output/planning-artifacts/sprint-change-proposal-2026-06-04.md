# Sprint Change Proposal — Epic-19 Binary-Envelope Re-baseline

**Date:** 2026-06-04
**Author:** Ant (proposal produced at the Story 19.4 Epic-19 close-out dev-pass)
**Scope classification:** **Minor** — One envelope figure re-baselined; no rollback of completed work; no new/removed FR/NFR; no MVP withdrawal; no story re-sequencing. Records an accept-with-rationale for a binary-delta overage already shipped and CR-verified.

---

## Section 1: Issue Summary

**Problem statement.** Epic 19 (bank-aware compiler mechanism — `:`/`,`/`COMPILE,`/`CREATE`/`DOES>`) shipped a cumulative kernel binary delta of **+303 B**, which is **over the ~300 B Epic-19 Decision-Impact-Analysis line envelope** recorded in `epics-phase4-epics-16-22.md`. Story 19.4 (the Epic-19 close-out gate) must reconcile this overage rather than silently asserting a clean ≤300 B pass.

**How it surfaced.** The +303 B figure was established by the 2026-06-03 code-review of the Epic-19 cluster via clean worktree rebuilds. Two dev-pass binary-delta records were found to be understated and were CR-corrected:
- Story 19.3 dev-pass recorded **+33 B**; the true delta is **+35 B**.
- Story 19.3.1 dev-pass recorded **+89 B**; the true delta is **+125 B**.

**Verification (re-validated at the Story 19.4 dev-pass, 2026-06-04, per B.3).**

| Story | Close size | Δ | Note |
|---|---|---|---|
| (Epic-19 start) | 26583 B | — | end of Epic 18 (commit `ea7f066`, parent of Story 19.1) |
| 19.1 | 26603 B | +20 | per-bank HERE/LATEST/,/COMPILE, |
| 19.2 | 26726 B | +123 | bank-aware `:` + descriptor-stub-on-`;` |
| 19.3 | 26761 B | +35 | CREATE/DOES> (CR-corrected from +33) |
| 19.3.1 | 26886 B | +125 | INCLUDE-EOF + bucket-skip (CR-corrected from +89) |
| **Epic-19 total** | **26886 B** | **+303 B** | **OVER ~300 B line envelope** |

Re-derivation method at the 19.4 dev-pass: clean `make clean && make` of HEAD (`010e8f2`) → **26886 B**; clean worktree build of the pre-Epic-19 baseline (`ea7f066`) → **26583 B**; `26886 − 26583 = 303 B`, which equals the sum of the CR-corrected per-story deltas (`20 + 123 + 35 + 125 = 303`).

**Evidence.**
- HEAD clean rebuild: `wc -c build/antforth.com` = 26886 B (2026-06-04).
- Pre-Epic-19 baseline: clean worktree build of `ea7f066` = 26583 B (2026-06-04).
- 2026-06-03 CR-pass corrections of the 19.3 / 19.3.1 dev-pass delta records.
- Story 19.4 §"The three load-bearing CR-pass findings" — finding (1).

---

## Section 2: Impact Analysis

### Envelope Impact

| Figure | Old | New | Basis |
|---|---|---|---|
| Epic-19 binary envelope | ~300 B (redesign-§7 spec target) | **~720–810 B** (re-baselined) | Empirical Phase-4 pattern is ~2.4–2.7× the redesign-§7 spec target ([[project_epic17_envelope]]); `300 × 2.4 = 720`, `300 × 2.7 = 810`. |
| Epic-19 realised delta | — | **+303 B** | CR-verified clean rebuild; sits comfortably inside the re-baselined envelope (303 ≪ 720). |

The ~300 B figure was a **redesign-§7 spec target**, not an empirically-calibrated envelope. The established Phase-4 calibration data point ([[project_epic17_envelope]], accepted 2026-05-16) is that realised kernel deltas run ~2.4–2.7× the redesign-§7 spec targets. Applying that multiplier to the ~300 B target yields a realistic Epic-19 envelope of ~720–810 B. The realised +303 B is ~1.0× the spec target — i.e. Epic 19 came in *well under* the empirically-expected envelope, and only "over" against the un-calibrated raw spec target.

### NFR Impact

- **NFR-P4-5 (8 KB Phase-4 fixed-memory cap):** **Unaffected.** +303 B is a small fraction of the 8 KB cap. The descriptor-stub region (`$D4CB..$DBFF`, 1845 B, 461-stub cap) pre-allocates **0 stubs at boot** (verified at the 19.4 dev-pass: boot-time `stub_alloc_tail == STUB_ALLOC_BASE`); stubs are runtime-allocated only by user bank-N>0 definitions at 4 B/stub.
- **No other NFR affected.** No T-state hot-path regression is introduced by this re-baseline (it is a documentation/accounting change).

### Artifact Conflicts

| Artifact | Changes required |
|---|---|
| `epics-phase4-epics-16-22.md` | The Epic-19 close-out reframing note (`:871`) already records the +303 B figure and directs Story 19.4's AC7 to record this re-baseline. No further epics-doc edit required by this proposal. |
| Story 19.4 Dev Notes | Log this SCP disposition (done — AC7). |
| Memory `project_phase4_scope.md` | Epic 19 bullet updated to record +303 B SCP-rebaselined (done at the 19.4 dev-pass). |
| `sprint-status.yaml` | No envelope-specific edit; the 19.4 close-out transitions are independent. |

### Technical Impact

- **No code changes by this proposal** — it is a planning/accounting artefact. The +303 B is already shipped and CR-verified.

---

## Section 3: Recommended Path Forward

**Accept-with-rationale + envelope re-baseline.** Adopt ~720–810 B as the calibrated Epic-19 binary envelope (replacing the ~300 B raw spec target); record the realised +303 B as inside that envelope. This is consistent with the precedent established for Epic 17 ([[project_epic17_envelope]]) and avoids a spurious "over-budget" flag against an un-calibrated target. No rollback, no re-scoping, no work deferred on envelope grounds.

**Forward guidance.** Future Phase-4 epic envelope planning should apply the ~2.4–2.7× multiplier to redesign-§7 spec targets up front (already captured in [[project_epic17_envelope]]), so the realised-vs-planned gap does not recur as a per-epic reconciliation.

---

## Section 4: Approval

- **Disposition:** Accept-with-rationale (Q3-α at the Story 19.4 dev-pass, AskUserQuestion 2026-06-04 — dedicated SCP record).
- **Approved by:** Ant (project lead), Story 19.4 dev-pass.
- **Cross-references:** Story 19.4 AC7; `epics-phase4-epics-16-22.md:871` (Epic-19 close-out reframing); [[project_epic17_envelope]] (the 2.4–2.7× empirical pattern).

---

## Addendum: Epic 19.5 envelope reconciliation (Story 19.5.4 close-out, 2026-06-08)

**Context.** Epic 19.5 (cross-bank-dispatch stabilization interlude — ADR-first, Stories 19.5.0–19.5.3) shipped as antforth 3.0.4. This addendum reconciles its cumulative binary delta against the ADR-itemised guidance, applying the same accept-with-rationale + realistic-envelope precedent this SCP established for Epic 19.

**Measured cumulative delta (re-derived via clean rebuilds at the 19.5.4 dev-pass — not inherited):**

| Story | Δ | Close size | Note |
|---|---|---|---|
| Epic-19 close (v3.0.3 baseline) | — | **26834 B** | clean rebuild of tag `v3.0.3` (commit `94c2ba0`) |
| 19.5.0 (ADR spike) | 0 B | 26834 B | zero binary delta |
| 19.5.1 (F1 portal-aliasing guard + F2 COLD-init + F3 slot) | +65 B | ~26899 B | eda591f |
| 19.5.2 (RST-stub option-C dispatch + CR-F1 CATCH triple restore) | +~42 B | ~26940 B | bddda48 |
| DIV-1 fix (MMU-readback correctness) | +13 B | 26953 B | 1bab95a — **unbudgeted correctness fix** |
| 19.5.3 (compiled-body + NFR-P4-8 verification) | 0 B | 26953 B | test/doc only |
| 19.5.4 (this close-out) | 0 B | **26953 B** | same-length banner + docs + test-infra |
| **Epic-19.5 total** | **+119 B** | **26953 B** | clean-rebuild verified (26953 − 26834) |

**ADR guidance vs realised.** The ADR-itemised guidance was **~+30..+100 B** (epics:902 — F1 ~20 + F2 ~17 + option-C net −13..+25 + CATCH ~20, ×1.25). **+119 B is ~19 B over the ~100 B upper guidance.**

**Disposition — accept-with-rationale (not a clean ≤100 B pass):**
1. **The +13 B DIV-1 fix was an unbudgeted correctness fix** — a HW-only MMU-port-readback float (`IN A,(0x72)` returns an open-bus self-opcode echo on real silicon; the restored slot-2 page is unmapped) found during 19.5.2's hardware smoke. It could not be declined ([[feedback_no_accept_disposition_for_bugs]], [[project_div1_mmu_port_readback]]). **Excluding it, the epic lands at +106 B** — within rounding of the ~100 B guidance.
2. **The residual sits comfortably inside the realistic envelope.** The empirical Phase-4 pattern is ~2.4–2.7× the redesign-§7 spec target ([[project_epic17_envelope]]), putting the ~100 B ADR figure's realistic band at **~240–270 B**. +119 B is well inside it.
3. **NFR-P4-5's 8 KB Phase-4 fixed-memory cap is unaffected** — 119 B is a small fraction of the banking-infrastructure budget.

No code changes by this addendum — it is a planning/accounting artefact; the +119 B is shipped and CR-verified across Stories 19.5.1–19.5.3. The AC2 three-surface re-sweep at the 19.5.4 dev-pass forced **no** kernel fix (0 B story), so nothing is added to this reconciliation.

- **Disposition:** Accept-with-rationale (Q1-α at the Story 19.5.4 dev-pass, AskUserQuestion 2026-06-08 — append to this existing SCP rather than spawn a new one, per [[feedback_ceremony_diminishing_returns]]).
- **Approved by:** Ant (project lead), Story 19.5.4 dev-pass.
- **Cross-references:** Story 19.5.4 AC3; ADR 19.5 (`docs/adr-19-5-cross-bank-dispatch.md`); [[project_epic17_envelope]]; [[project_div1_mmu_port_readback]].
