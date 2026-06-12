# Sprint Change Proposal — Epic-20 Binary-Envelope Re-baseline

**Date:** 2026-06-12
**Author:** Ant (proposal produced at the Story 20.3 Epic-20 close-out dev-pass)
**Scope classification:** **Minor** — One envelope figure re-baselined; no rollback of completed work; no new/removed FR/NFR; no MVP withdrawal; no story re-sequencing. Records an accept-with-rationale for a binary-delta overage already shipped and CR-verified (Stories 20.1 + 20.2 are `done`).

---

## Section 1: Issue Summary

**Problem statement.** Epic 20 (bank-aware lookup surface — bank-aware `FIND` + `WORDS`) shipped a cumulative kernel binary delta of **+680 B**, which is **3.4× over the ~200 B Epic-20 Decision-Impact-Analysis envelope** recorded in `epics-phase4-epics-16-22.md`. Story 20.3 (the Epic-20 close-out gate) must reconcile this overage rather than silently asserting a clean ≤200 B pass.

**Root cause — a design substitution, not a same-design overshoot.** Story 20.1's mechanism changed mid-flight (project-lead-steered) from a localised **per-wordlist-`bank`-field FIND tweak** — the ~200 B planning premise, in which `FIND` saved the current bank, switched to a wordlist's home bank, walked the chain, and restored — to a full **24-bit fat-pointer dictionary header-format migration**: every dictionary link (each hash-bucket head and each header's `hash_link`) became an inline `[addr:2][bank:1]` fat pointer, so the bank travels with each pointer and `FIND`/`WORDS` page in the link's bank before dereferencing a window-resident header. The ~200 B envelope was scoped against the abandoned design and is not a meaningful ceiling for the shipped one.

**Verification (re-validated at the Story 20.3 dev-pass, 2026-06-12, per B.3 — clean `make clean && make` worktree rebuilds, not inherited).**

| Story | Close size | Δ | Note |
|---|---|---|---|
| (Epic-20 start) | 26945 B | — | v3.0.4 close `2808ce3` (Epic 19.5 + MBB banking-BIOS pivot) |
| 20.1 dev-pass | 27516 B | +571 | bank-aware `FIND` — fat-pointer header-format migration (incl. +10 B fast-path inline) |
| 20.1 CR (`d078548`/`d6dc751`) | 27625 B | +109 | bank-aware `WORDS` added in CR + fat-bank-byte error recovery + zero full 9-byte label record |
| 20.2 | 27625 B | +0 | `WORDS` verify (FR-P4-29) + FR-P4-30 retire — no kernel code |
| **Epic-20 total** | **27625 B** | **+680 B** | **3.4× OVER the ~200 B envelope → re-baseline** |

Re-derivation method at the 20.3 dev-pass: clean rebuild of HEAD (`4c2ab0b`) → **27625 B**; clean worktree build of the pre-Epic-20 baseline (`2808ce3`, the Epic-19.5 close that carries `git tag v3.0.4`) → **26945 B**; `27625 − 26945 = 680 B`. The +680 B endpoint is the authoritative, independently re-verified figure; the per-story sub-deltas are from the story records (they drifted during the 20.1 CR, as the 20.2 story documents).

**Evidence.**
- HEAD clean rebuild: `wc -c build/antforth.com` = 27625 B (2026-06-12).
- Pre-Epic-20 baseline: clean worktree build of `2808ce3` = 26945 B (2026-06-12).
- Story 20.3 AC7 / Dev Notes "Epic-20 cumulative binary trajectory".

**Approximate component breakdown of the +680 B** (fat-pointer migration cost class): +1 B per ~379 kernel header links ≈ **+379 B** for the header-format widening alone; **+64 B** fat bucket-head array; the per-entry page-in / caller-restore walk in `FIND` and `WORDS`; `build_header` fat-pointer read/write; a 32 B name-snapshot buffer. These are structural costs of the migration, absent entirely from the per-wordlist-`bank`-field design.

---

## Section 2: Impact Analysis

### Envelope Impact

| Figure | Old | New | Basis |
|---|---|---|---|
| Epic-20 binary envelope | ~200 B (Decision-Impact-Analysis target, per-wordlist-`bank`-field design) | **superseded — not a meaningful ceiling for the shipped design** | The target was scoped against an abandoned mechanism. |
| Epic-20 realised delta | — | **+680 B** | CR-verified clean rebuild; the shipped fat-pointer header-format migration. |

Unlike the Epic-17/19 reconciliations — where the realised delta was a ~2.4–2.7× *overshoot of the same design* and fit inside a multiplier-calibrated envelope ([[project_epic17_envelope]]) — Epic 20 is a **design substitution**. Applying the empirical ~2.4–2.7× multiplier to the ~200 B target yields only ~480–540 B, and **+680 B exceeds even that**. The honest framing is therefore not "we came in under a calibrated envelope" but: the mechanism shipped is structurally different from and more capable than the one the ~200 B figure costed, its cost is recorded and accepted, and the user-facing FIND/WORDS goal is delivered. This SCP does not invent a multiplier to make +680 B "fit"; it records the substitution.

### NFR Impact

- **NFR-P4-5 (8 KB Phase-4 fixed-memory cap):** **Unaffected.** +680 B is a small fraction of the 8 KB cap, and the fat-pointer change is a dictionary-*header*-format change in code/links, not a fixed-memory-region growth. The descriptor-stub region (`$D4CB..$DBFF`, 1845 B, 461-stub cap) pre-allocates **0 stubs at boot** (re-confirmed at the 20.3 dev-pass — Epic 20 adds no stub pre-allocation); stubs remain runtime-allocated at 4 B/stub by user bank-N>0 definitions only.
- **No other NFR affected.** No T-state hot-path regression: the everyday FORTH-wordlist `FIND` path (links whose bank byte is the fixed bank) incurs no MMU switch; only a window-resident foreign-bank link triggers a page-in.

### Artifact Conflicts

| Artifact | Changes required |
|---|---|
| `epics-phase4-epics-16-22.md` | Annotate the Story 20.3 § with the version (v3.0.5) and the +680 B design-substitution re-baseline; flag the downstream tag mapping shift (Epic 21 → v3.0.6, Epic 22 → v3.0.7). Done at the 20.3 dev-pass. |
| Story 20.3 Dev Notes | Log this SCP disposition (done — AC7). |
| Memory `project_phase4_scope.md` | Epic 20 bullet updated to record +680 B SCP-rebaselined (done at the 20.3 dev-pass). |
| `sprint-status.yaml` | No envelope-specific edit; the 20.3 close-out transitions are independent. |

### Technical Impact

- **No code changes by this proposal** — it is a planning/accounting artefact. The +680 B is already shipped and CR-verified across Stories 20.1 + 20.2 (both `done`).

---

## Section 3: Recommended Path Forward

**Accept-with-rationale + envelope retirement.** Retire the ~200 B Epic-20 target as scoped against an abandoned design; record the realised **+680 B** as the verified cost of the shipped 24-bit fat-pointer header-format migration that delivers bank-aware `FIND` + unified `WORDS`. No rollback, no re-scoping, no work deferred on envelope grounds.

**Forward guidance.** When a mechanism is substituted mid-epic (not merely overshot), the envelope must be **re-derived from the new design's cost class**, not multiplier-scaled from the old target — multiplier calibration ([[project_epic17_envelope]]) applies to same-design overshoot, not design substitution. Future Phase-4 epic planning should re-cost an envelope the moment the mechanism changes, rather than reconcile at close-out.

---

## Section 4: Approval

- **Disposition:** Accept-with-rationale (Q2 at the Story 20.3 dev-pass, AskUserQuestion 2026-06-12 — dedicated SCP record).
- **Approved by:** Ant (project lead), Story 20.3 dev-pass.
- **Cross-references:** Story 20.3 AC7; `epics-phase4-epics-16-22.md` (Epic-20 close-out §); [[project_epic17_envelope]] (same-design 2.4–2.7× pattern — explicitly NOT applied here); [[project_story20_1_fat_pointers]] (the design substitution); `sprint-change-proposal-2026-06-04.md` (Epic-19 / 19.5 envelope precedent shape).
