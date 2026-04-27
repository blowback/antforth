# Sprint Change Proposal — Insert Stabilisation Interlude Epic Before Search-Order

**Date:** 2026-04-27
**Author:** Ant (proposal produced via `bmad-bmm-correct-course`)
**Scope classification:** **Moderate** — One new epic inserted into Phase-2; Epic-12 (Search-Order) needs redrafting; Phase-2 PRD/Architecture references updated; sprint-status edited; no rollback of completed work; no MVP withdrawal.

---

## Section 1: Issue Summary

**Problem statement.** Three signals surfaced at the Epic 11 retrospective on 2026-04-27 that together require a course-correction interlude before Epic 12 (Search-Order) starts:

1. **Hardware-only crash class on real MicroBeast** (not reproducible on iz-cpm). Print operations occasionally trigger hard reboots or bogus BDOS errors. Pattern: `1 2 3 ' ABORT CATCH . . . .` printed `-1 ` then soft-rebooted mid-line; later `error -3085` (not a defined THROW code; BC must hold garbage) followed by a `Bdos Err On B: Bad Sector` chain. Project lead wants a thorough antforth-side audit (shadow-register / IX / IY / stack discipline around BDOS) before approaching the MicroBeast firmware maintainer.

2. **Epic 12 is out of date.** Story 12.6 ("ASSEMBLER wordlist + auto-activation in `CODE`/`END-CODE`") still presumes the auto-activation hook that was rolled back. Project lead 2026-04-27: *"we decided to row-back on the whole ASSEMBLER.FTH and auto-loading assembler words — I don't know why this hasn't been properly captured — so there are no knights in shining armour coming to our rescue in epic 12."* Memory `project_assembler_keep_assembly.md` (2026-04-20) only captured the `.FTH` half of the rollback. Story 12.6's planned retirement of the Story-10.7 `asm_hash_dispatch_hack` is invalidated.

3. **Accumulated technical debt.** Epic 11 created or carried 6 debt items (none retired). Project lead 2026-04-27: *"I do not like those technical debts, and I think we need an epic to sort them all out before they snowball."*

**Context.** Epic 11 closed clean on 2026-04-27 with hardware smoke 12/12, 787 PASS / 0 FAIL, `v1.11.0`-ready. The retro surfaced the three signals above as significant discoveries flipping the previously-clean "no epic-update required" verdict.

**Direction given.** Insert a **course-correction new epic** to deal with the hardware crashes and the technical-debt issues, before Epic 12 starts.

**Evidence.**
- Epic 11 retrospective: `_bmad-output/implementation-artifacts/epic-11-retro-2026-04-27.md` §"Significant Discoveries".
- Hardware-crash transcript: `~/Downloads/bestialitty-20260427-120911.bin` (verbatim 2026-04-27 hardware smoke).
- Memory: `project_hardware_crash_audit.md`, `project_epic12_redraft_required.md`, `project_asm_hash_dispatch_hack.md` (retirement plan invalidated).

---

## Section 2: Impact Analysis

### Epic Impact

| Epic | Status | Impact |
|---|---|---|
| Epic 9 — Numeric prefixes | done | None |
| Epic 10 — Core compliance | done | None |
| Epic 11 — Exception subsystem | done (retro 2026-04-27) | None — Epic 11 closed before this proposal |
| **(NEW) Epic 11.5 — Stabilisation, hardware-audit, debt cleanup, Epic-12 redraft prep** | backlog | **+1 epic inserted between 11 and 12.** Six anchor stories — see Section 4. |
| Epic 12 — Search-Order + ASSEMBLER wordlist | backlog | **Moderate — needs redraft.** Story 12.6 currently assumes auto-activation in `CODE`/`END-CODE`; the rollback now extends to that hook. Epic 12 redraft (Story 11.5.5 in this proposal) decides whether `ASSEMBLER` is (a) a passive wordlist needing manual `ALSO ASSEMBLER`, (b) auto-activated through a different mechanism, or (c) Story 12.6 dropped entirely. The redraft is a deliverable of Epic 11.5, not a separate course-correction. |
| Epic 13 — File-Access | backlog | **None.** Epic 13's scope (file I/O, INCLUDE nesting, FS stress, BDOS audit, release gate) is independent of the Epic-12 redraft and the hardware-crash audit. The audit verdict from Story 11.5.1 may inform Epic 13's BDOS-audit story (13.5 — formerly 13.7) but does not change Epic 13's scope. |

### Artifact Conflicts

| Artifact | Changes required |
|---|---|
| `prd.md` | **Light.** Add Epic 11.5 to the Epic Sequence section (between Epic 11 and Epic 12). Add a sentence to NFR4 (per-epic ROM budget) noting Epic 11.5 is expected to be near-zero (audit + small fixes). Add a sentence to the Hardware Validation / Real-MicroBeast section flagging the 2026-04-27-discovered crash class as gating Epic 12 acceptance. No FR/NFR additions or deletions. |
| `architecture.md` | **Light.** Add Epic 11.5 entry to the epic-by-epic touched-files matrix (covers `src/exception.asm` print path, `src/strings.asm` for the `(`/EVALUATE fix, possibly `src/system.asm` for stack-overflow guard, possibly `src/assembler.asm` if the audit surfaces a register-preservation issue). No architectural-decision-record additions yet (audit must precede any new ARDs). |
| `epics.md` | **Substantial — two passes.** Pass 1 (this proposal): insert Epic 11.5 epic-spec section between Epic 11 and Epic 12, with the six anchor stories from Section 4 below. Pass 2 (Story 11.5.5 in the new epic itself): redraft Epic 12 sections 12.1–12.7 to match the 2026-04-20 + 2026-04-27 ASSEMBLER rollback decisions. |
| `sprint-status.yaml` | Add `epic-11.5: backlog` and 6 story rows. Update the Epic 12 placeholder comment (already in place from 2026-04-27 retro) to reference this proposal. |
| Memory: `project_phase2_scope.md` | Already updated 2026-04-27 to flag Epic 12 as stale. After Epic 11.5 is approved, add Epic 11.5 to the epic list. |
| Memory: `project_epic12_redraft_required.md` | Already exists from 2026-04-27. After Story 11.5.5 lands, replace with a closure note. |
| Memory: `project_hardware_crash_audit.md` | Already exists from 2026-04-27. After Story 11.5.1 lands with verdict, update with verdict + fix references. |
| Memory: `project_asm_hash_dispatch_hack.md` | Already updated 2026-04-27 to flag retirement plan invalid. Refresh again after Story 11.5.5 (Epic 12 redraft) decides the retirement vehicle. |
| `_bmad-output/implementation-artifacts/epic-11-retro-2026-04-27.md` | **No change** — the retro already proposes Epic 11.5 with the same six anchors. This proposal formalises the retro's recommendation. |

### Technical Impact

- **No code changes by this proposal** — this is a planning artefact. Code changes happen inside Epic 11.5 stories.
- **Epic 11.5 expected ROM delta:** small positive or near-zero. Stack-overflow guard adds bytes; `(`/EVALUATE fix and print-table hardening are mostly neutral; audit story is zero. Hardware-audit fix (if antforth defect found) is unbudgeted until verdict lands.
- **Epic 12 (after redraft):** still grows the kernel for the Search-Order machinery; the redraft may save bytes by dropping Story 12.6's auto-activation hooks if that route is chosen.
- **`v1.11.0` tag is not blocked by this proposal** — Epic 11 closed clean; the tag can apply now or after Epic 11.5 lands. Project lead's call.

---

## Section 3: Recommended Approach

### Path forward: **Direct Adjustment** — insert Epic 11.5 interlude; redraft Epic 12 inside it; carry Epic 13 forward unchanged

**Rationale.**

- **No implementation work to roll back.** Epic 11 is `done`, Epic 12 is `backlog`, Epic 13 is `backlog`. The audit / debt-cleanup work has not started, so this is purely a forward-planning insertion.
- **MVP is unchanged.** Phase-2's two headline goals (100% ANS Core compliance — already achieved in Epic 10; on-device source development — Epic 13) are both intact. The interlude is hardening, not feature withdrawal.
- **The hardware-crash audit is gating.** Without a clean print path on real MicroBeast, Epic 12's Search-Order machinery and Epic 13's File-Access stress would be tested on a hardware platform that crashes during print operations — the test signal would be drowned out by the field condition. Audit-then-fix-or-escalate is the only credible sequence.
- **The Epic 12 redraft must precede Story 12.1.** Story 12.1 (`FORTH-WORDLIST` bootstrap) is upstream of Story 12.6, but Story 12.6's removal/redesign affects whether Story 12.1's bucket-array layout needs an `ASSEMBLER` slot pre-allocated. The redraft is fastest to do as one of the interlude stories rather than mid-Epic-12.
- **Debt accumulation is real.** Six items, none retired by Epic 11. The 2026-04-20 ASSEMBLER rollback already retired one item (the lazy-load capstone) without spending implementation effort; the same pattern applies here for the items that turn out to be over-scoped.

**Numbering — two options for the project lead to choose at approval time:**

| Option | Description | Trade-off |
|---|---|---|
| **A: Insert as "Epic 11.5"** (recommended) | New epic numbered between 11 and 12. Sprint-status key `epic-11.5: backlog`; story keys `11.5-1-...` through `11.5-6-...` (YAML accepts dots in keys when the value side is unambiguous). | **Pros:** zero churn on Epic 12 / Epic 13 references in PRD / architecture / memory / 30+ implementation-artifact files. **Cons:** "Epic 11.5" is non-standard numbering. |
| B: Renumber existing Epic 12 → Epic 13, existing Epic 13 → Epic 14, name the interlude **Epic 12** | Clean integer numbering throughout. | **Pros:** consistent integer-only epic numbering. **Cons:** ~50+ cross-references across PRD / architecture / epics.md / sprint-status / memories / retros need surgical edits, mirroring the renumbering churn from the 2026-04-20 proposal. Net effort comparable to the audit story itself, for a cosmetic gain. |

**Recommendation:** Option A. The 2026-04-20 proposal renumbered within Epic 12 / Epic 13 because the deletions made integer numbering tight; here the only insertion is one epic, and the cross-reference churn is disproportionate to the cosmetic gain.

**Effort estimate (Phase-2 net):** **Net cost** of one interlude epic. Six small-to-medium stories + Epic 12 redraft as one of them.

- Story 11.5.1 (hardware audit) — load-bearing for Epic 12 readiness; verdict-producing; may spawn fix story or escalation note. Medium effort + uncertainty.
- Stories 11.5.2 / 11.5.3 / 11.5.4 / 11.5.6 — small fixes / hardening. Each ≤ ½ day's work assuming the audit clears them.
- Story 11.5.5 (Epic 12 redraft) — pure document surgery; ~1–2 hours.

**Risk.** Medium-low. The audit verdict is the only material uncertainty. Worst case: a non-trivial antforth defect requires a follow-up fix story before Epic 12 starts. Even so, the interlude path is strictly better than starting Epic 12 against a crashing hardware platform.

**Timeline impact.** Phase-2 release (`antforth 2.0`) delayed by the duration of Epic 11.5. No epic deleted; one inserted.

### Alternatives considered and rejected

- **Option 2: Rollback.** Nothing to roll back — Epic 11 closed clean.
- **Option 3: MVP review.** Not warranted — no Phase-2 goal is being withdrawn.
- **Defer the audit; start Epic 12 now.** Rejected — testing Epic 12 on hardware that crashes during print operations would invalidate every Epic-12 hardware-smoke verdict.
- **Bundle the audit + debt fixes as Story 12.0 of Epic 12.** Rejected — the audit may surface non-trivial work that's larger than a single story, and the Epic 12 redraft is itself a dependency. Inverting the dependency by making Epic 12 own its prerequisites would tangle scopes.
- **Skip the Epic 12 redraft until after Story 12.1.** Rejected — Story 12.1's bucket-array layout depends on whether `ASSEMBLER` is a wordlist target.

---

## Section 4: Detailed Change Proposals

### 4.1 New Epic 11.5 — Stabilisation, Hardware Audit, Debt Cleanup, Epic-12 Redraft Prep

Inserted into `_bmad-output/planning-artifacts/epics.md` between Epic 11 and Epic 12.

**Epic 11.5: Stabilisation, Hardware Audit, Debt Cleanup, Epic-12 Redraft Prep**

The Epic 11 retrospective (2026-04-27) surfaced two epic-update signals (a hardware-only crash class on real MicroBeast affecting print operations; Epic 12's auto-activation plan invalidated by the wider 2026-04-20 ASSEMBLER rollback) plus six accumulated technical-debt items from Epics 10 and 11 that risk snowballing into Epic 12. This interlude epic clears the field before Epic 12 starts — one audit story, four small hardening / debt-retirement stories, one document-surgery story redrafting Epic 12 to match the rollback decisions. Shippable as `antforth 1.11.5` (or carried implicitly into Epic 12's tag).

#### Story 11.5.1: Real-MicroBeast hardware crash audit

As the antforth maintainer,
I want a thorough audit of every BDOS-call register-preservation assumption, every shadow-register / IX / IY / stack interaction with print paths, and a hardware reproduction of the 2026-04-27-observed crashes,
So that we can produce a verdict (antforth defect / firmware bug / shared-fault) with reproducer for each path before approaching the MicroBeast firmware maintainer.

**Acceptance Criteria (anchors — to be sharpened during `create-story`):**

**Given** the 2026-04-27 hardware smoke transcript (`~/Downloads/bestialitty-20260427-120911.bin`)
**When** each of the two reproducible incidents (incident #1: `1 2 3 ' ABORT CATCH . . . .` soft-reboot; incident #2: `error -3085` followed by Bdos Err chain) is reproduced on real MicroBeast hardware
**Then** the trigger sequence is documented byte-for-byte and the failure mode (hard reboot, BDOS error, hang) is recorded with timing.

**Given** every BDOS call site in `src/*.asm`
**When** audited
**Then** the per-site shadow-register / IX / IY / stack-discipline assumption is documented and cross-referenced against the CP/M 2.2 BDOS contract (function-by-function, since the contract is per-function and implementation-defined for many functions).

**Given** the audit findings
**When** synthesised
**Then** a verdict is produced for each incident: **(a)** antforth defect — produce a fix-story spec; **(b)** firmware bug — produce a minimal reproducer the MicroBeast maintainer can use; **(c)** shared-fault — document the boundary and the antforth-side mitigation.

**Given** Story 11.4.1's i*x preservation path (the `1 2 3 ' ABORT CATCH . . . .` form is exactly the path it redesigned)
**When** the audit checks whether Story 11.4.1's CATCH/THROW redesign is implicated in incident #1 specifically
**Then** the verdict is recorded — either ruled out (with evidence) or implicated (with reproducer).

**Given** the verdict for each incident
**When** the audit lands
**Then** the project lead reviews and approves the next-step plan (fix-stories, escalation to firmware maintainer, or both).

#### Story 11.5.2: Stack-overflow `-3 THROW` guard

Wire a `-3 THROW` guard so that data-stack growth past `s0` raises `THROW_STACK_OVERFLOW` cleanly rather than corrupting whatever lives below. Closes the Story 11.8 NFR6 documented gap. Hooks into the existing `check_underflow{,_2,_3,_4}` / `do_underflow_error` infrastructure pattern from the symmetric direction.

**Acceptance Criteria (anchors):**
- Allocate `THROW_STACK_OVERFLOW EQU -3` in `src/constants.asm` (already reserved per `docs/throw-codes.md:74`).
- Wire a guard at every site that pushes onto the data stack from a depth-unaware caller (analogous to where `check_underflow` is called today).
- Add `tests/throw_migration_tests.fth` Section 5 (or extend Section 1) with caught + uncaught -3 cases.
- Update Story 11.8 NFR6 verdict from "PASS-with-documented-gap" to "PASS" by adding the test 766 corollary.
- Story 11.5.1 audit may identify this guard as the proximate cause of incident #1; if so, Story 11.5.2 closes that finding too.

#### Story 11.5.3: `(` / EVALUATE source-frame fix

Story 11.6 F8 deferral. `(` doesn't respect EVALUATE's source-frame boundary; an unterminated `(` inside `EVALUATE` walks past the EVALUATE source into whatever input the outer REPL provides next, eating subsequent commands until parsing fails. Affects any code that wraps user-supplied source in `EVALUATE` and tries to `CATCH` parser errors.

**Acceptance Criteria (anchors):**
- `: T58 S" ( unterminated " EVALUATE ; ' T58 CATCH .` returns `-58  ok` (caught the unexpected-end-of-input THROW, scoped to EVALUATE's source frame).
- Subsequent REPL lines are not consumed by the runaway parse.
- Closes Story 11.6 F8 (the only pre-existing antforth-`(` defect surfaced by Epic 11).
- Unblocks Story 11.5 D2 caught-form coverage for asm-error THROW codes (-258..-269) by adding an EVALUATE-based caught-test harness.

#### Story 11.5.4: `print_throw_description` table-walk hardening

Story 11.5 F9 / Story 11.6 R-L6 carry. The 8-bit `ADD A, L / INC H` walk in `print_throw_description` would wrap if `HL` ≈ `$FF00` — currently safe (kernel ~17 KB) but a documented growth risk. Switch to 16-bit `ADD HL, A` form. Cold path; defensive only. Net delta near-zero.

**Acceptance Criteria (anchors):**
- Replace 8-bit walk with 16-bit form.
- Re-verify all uncaught-THROW REPL tests (685–693, 716–717, 750–753, 762–764, 768–770) still PASS byte-identically.
- Net byte delta recorded.

#### Story 11.5.5: Epic 12 redraft

Document-surgery story. Update `_bmad-output/planning-artifacts/epics.md` Epic 12 sections (12.1–12.7) and `sprint-status.yaml` Epic 12 rows to match both the 2026-04-20 ASSEMBLER.FTH rollback **and** the 2026-04-27 auto-activation rollback. Project lead chooses one of three paths during this story:

- **(a) Passive `ASSEMBLER` wordlist.** User types `ALSO ASSEMBLER` manually inside CODE blocks. Story 12.6 retains a smaller scope (just register the wordlist; no auto-activation). The asm-`#` dispatch hack retires once the two `#` words separate at the wordlist layer.
- **(b) Drop Story 12.6 entirely.** No `ASSEMBLER` wordlist; opcodes stay at the global-search-order top. The asm-`#` hack stays permanent. Smallest Epic 12.
- **(c) Reinstate auto-activation under a different mechanism.** `CODE` itself manipulates the search order without needing the dispatch hack. Story 12.6 redrafted with a different design.

**Acceptance Criteria (anchors):**
- Project-lead pick recorded in story Completion Notes.
- `epics.md` Epic 12 sections 12.1–12.7 redrafted to match the pick.
- `sprint-status.yaml` Epic 12 rows updated.
- Memories `project_phase2_scope.md`, `project_epic12_redraft_required.md`, `project_asm_hash_dispatch_hack.md` updated.
- The asm-`#` hack retirement plan in `project_asm_hash_dispatch_hack.md` is either fixed or marked permanent per the pick.

#### Story 11.5.6 (optional): `-271` semantic split

Story 11.6 F4 deferral. `THROW_ASM_RANGE = -271` collapses two distinct conditions (`+D` displacement out-of-range; `BIT,` bit-number out-of-range); diagnostic gives no locality. Allocate `-272 THROW_ASM_BIT_RANGE`; split the two raises in `src/assembler.asm`.

**Optional** — judgment call on whether the diagnostic-locality gain justifies the EQU + table churn. Project lead may drop this story without affecting the rest of Epic 11.5.

#### Story 11.5.7 (optional): Epic 11.5 close-out + CCD-4-equivalent gate

If Epic 11.5 grows to ≥4 stories landing kernel changes, close with a small CCD-4 gate (full regression pass + ROM-delta delta against post-Story-11.7 baseline + hardware re-smoke covering the audit verdict). If Epic 11.5 is mostly document surgery (e.g., audit verdict = firmware bug; only Story 11.5.5 redraft lands), the Epic 11.5 close-out collapses into the next CCD-4 gate (Epic 12.7).

### 4.2 PRD (`_bmad-output/planning-artifacts/prd.md`)

#### 4.2.1 Epic Sequence — insert Epic 11.5

Add a row between Epic 11 and Epic 12 in whichever table / list summarises the Phase-2 epics:

```
Epic 11.5 — Stabilisation, hardware audit, debt cleanup, Epic-12 redraft prep
```

#### 4.2.2 NFR4 (per-epic ROM budget) — append

Append: *"Epic 11.5 is expected to land near-zero net ROM delta (audit + small hardening fixes); a non-trivial delta requires explicit justification per the audit verdict."*

#### 4.2.3 Hardware Validation section — append

Append: *"The 2026-04-27 hardware smoke during Story 11.8 surfaced a real-MicroBeast crash class on print operations not reproducible in iz-cpm. Epic 11.5 Story 11.5.1 audits this; Epic 12 hardware-smoke acceptance is gated on the audit verdict (clean / mitigated / accepted-as-firmware-bug)."*

### 4.3 Architecture (`_bmad-output/planning-artifacts/architecture.md`)

#### 4.3.1 Epic-by-epic touched-files matrix — insert Epic 11.5 row

Insert a row noting Epic 11.5 touches: `src/exception.asm` (print-table hardening), `src/strings.asm` (`(`/EVALUATE fix), `src/system.asm` (stack-overflow guard, possibly), `src/assembler.asm` (potentially, pending Story 11.5.6 + Story 11.5.5 outcome), tests, Makefile, docs.

#### 4.3.2 No new architectural decisions until audit lands

Story 11.5.1's audit may surface a register-preservation defect that requires an architectural decision record (e.g., "shadow-register state across BDOS calls — explicit save/restore vs. assume-preserved"). Such ADRs land inside Story 11.5.1 if the audit verdict warrants them, not pre-emptively in this proposal.

### 4.4 Sprint Status (`_bmad-output/implementation-artifacts/sprint-status.yaml`)

Add the following block between the Epic 11 retrospective comment and the `epic-12: backlog` row (or wherever Epic 11's section closes):

```yaml
  epic-11.5: backlog
  11.5-1-real-microbeast-hardware-crash-audit: backlog
  11.5-2-stack-overflow-throw-3-guard: backlog
  11.5-3-paren-evaluate-source-frame-fix: backlog
  11.5-4-print-throw-description-table-walk-hardening: backlog
  11.5-5-epic-12-redraft: backlog
  11.5-6-throw-271-semantic-split: backlog
  epic-11.5-retrospective: optional
```

(If the project lead picks Option B numbering — renumber existing Epic 12 → 13, etc. — these become `12-1-...` through `12-7-...` and `epic-12: backlog`; Section 5 below describes the renumbering scope.)

The existing comment block under `epic-11-retrospective: done` flagging Epic 12 as stale is preserved verbatim — it cross-references this proposal.

### 4.5 Memory updates (post-approval)

Already-staged updates from 2026-04-27 (`project_epic12_redraft_required.md`, `project_hardware_crash_audit.md`, `project_phase2_scope.md` flagged stale, `project_asm_hash_dispatch_hack.md` retirement plan flagged invalid) remain in place. After this proposal lands, add one new memory:

- `project_epic_11_5_scope.md` — scope memory for Epic 11.5, mirroring `project_epic4_scope.md` / `project_epic5_scope.md` style. Created on approval.

---

## Section 5: Implementation Handoff

**Scope classification:** **Moderate** — sprint reorganisation; no rollback; one new epic; ~50 lines of cross-document edits.

**Recipients and responsibilities:**

| Recipient | Responsibility |
|---|---|
| **Project lead (Ant)** | Approve this proposal. Pick Option A or Option B numbering. Sign off on the audit-story scope before `create-story` runs (Story 11.5.1 has unusual breadth — worth validating before dev). |
| **PO / SM (Alice / Bob)** | Run `bmad-bmm-create-story` on Story 11.5.1 first (audit is gating). On audit completion, decide whether Stories 11.5.2 / 11.5.3 / 11.5.4 / 11.5.5 / 11.5.6 land in their drafted form or need adjustment per the audit verdict. Run `create-story` on each as the queue clears. |
| **Dev Agent** | Execute stories in order. Story 11.5.1 first (hardware audit, gating). Stories 11.5.2 / 11.5.3 / 11.5.4 / 11.5.6 are independent and can be sequenced by the SM. Story 11.5.5 (Epic 12 redraft) can run in parallel with the others — it's document surgery. |
| **Project lead (Ant)** again at Story 11.5.1 close-out | Decide on antforth-fix vs. firmware-escalation based on the audit verdict. Approve any new fix-stories that the audit spawns. |

**Success criteria for Epic 11.5:**

- Hardware-crash audit verdict produced with reproducers (Story 11.5.1).
- Antforth-side fixes applied for any verdict-(a) defects, OR firmware-side reproducer prepared for verdict-(b) escalation.
- Stack-overflow (-3) guard wired and tested.
- `(`/EVALUATE source-frame defect fixed.
- `print_throw_description` walk hardened.
- Epic 12 redrafted to match the post-2026-04-20 + post-2026-04-27 ASSEMBLER scope.
- No regressions to the 787 PASS baseline.
- ROM delta within Epic 11.5 expected envelope (near-zero) or justified per the audit verdict.

**Pre-Epic-12 gate (replaces the implicit Epic 11 → Epic 12 handoff):**

Epic 12 (Search-Order) does NOT start until:
1. Epic 11.5 closes (or the audit verdict has explicitly cleared a fast-track on hardware).
2. Story 11.5.5 has redrafted Epic 12.
3. The `v1.11.0` tag has been applied (project-lead's discretion — can be at Epic 11 close-out or after Epic 11.5 close-out).

---

## Section 6: Outstanding Decisions for Project Lead

Before this proposal can be approved as-is, the project lead picks:

1. **Numbering** — Option A (Epic 11.5; recommended) or Option B (renumber existing 12 → 13, 13 → 14; clean integers). Recommendation: A.
2. **Hardware-audit scope ceiling** — is the audit a single story with a verdict deliverable, or does it permit a "tag and fix in-pass" mode where small antforth-side defects identified during the audit are fixed in the same story? Recommendation: verdict-only deliverable; fix-stories spawn from the verdict.
3. **`v1.11.0` tag timing** — apply now (Epic 11 closed clean) or defer to post-Epic-11.5? Recommendation: apply now; Epic 11.5's value is forward-stabilisation, not backfill on Epic 11.
4. **Optional Story 11.5.6** — keep as drafted, drop, or merge into Story 11.5.5. Recommendation: keep optional; project lead decides at Epic 11.5 close-out whether to land it or carry forward.
5. **Optional Story 11.5.7 close-out gate** — execute as a per-CCD-4 close-out, or fold into Epic 12.7's close-out. Recommendation: fold into Epic 12.7 unless ≥3 kernel-changing stories land in Epic 11.5.

---

*This proposal formalises the recommendation made by the Epic 11 retrospective on 2026-04-27. It is small in code-change surface (one audit story, three small fixes, one document redraft, one optional split) and moderate in planning surface (one new epic, light PRD/architecture additions, sprint-status edits). The audit story is the load-bearing one; the rest are debt cleanup that's been queued long enough to deserve a dedicated landing pass.*
