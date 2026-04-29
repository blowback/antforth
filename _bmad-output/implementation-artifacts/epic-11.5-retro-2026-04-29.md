# Epic 11.5 Retrospective: Stabilisation, Hardware Audit & Epic-12 Redraft Prep

**Date:** 2026-04-29
**Facilitator:** Bob (Scrum Master)
**Participants:** Alice (Product Owner), Bob (Scrum Master), Charlie (Senior Dev), Dana (QA Engineer), Ant (Project Lead)

---

## Epic Summary

- **Epic:** 11.5 — Stabilisation, hardware audit, and Epic-12 redraft preparation (debt-cleanup interlude inserted 2026-04-27 between Epic 11 and Epic 12)
- **Stories Completed:** 7/7 (100%) — 11.5.1, 11.5.1.2, 11.5.2, 11.5.3, 11.5.4, 11.5.5, 11.5.6, 11.5.7 close-out gate
- **Scope:** Audit + reproduce 2026-04-27 hardware crash class (Story 11.5.1 verdict-only); spawn firmware reproducer (11.5.1.2 PROBE.COM); retire 5 carry-over debt items (`-3` overflow guard, `(` / EVALUATE source-frame, `print_throw_description` wrap-safety, `-271` semantic split, Epic 12 redraft); CCD-4-equivalent close-out gate (11.5.7)
- **Binary Size:** 17,425 → **17,541 bytes** (**+116 bytes**, clean reconciliation, 0-byte residual)
- **REPL Tests:** 787 → **810 PASS** (**+23 tests**, zero regressions across 1..801 unique numbers)
- **Hardware Audit Verdict:** **(c) shared-fault** — BDOS shadow-clobber on fns 1/2/10; firmware fix verified clean (PROBE.COM all-P 2026-04-28); antforth-side defensive hardening (11.5.2) wired
- **Hardware Re-Smoke:** 2026-04-29 — Story 11.8 12-line batch + Epic-11.5 verdict reproducers (overflow recovery, `(`/EVALUATE caught -58, `-271 disp range`, `-272 bit range`); zero hard-reboot, zero BDOS-Err-On-B chain, zero print corruption
- **Code Review Findings:** Every story surfaced findings (1 MEDIUM in 11.5.1; LOW counts elsewhere); zero-finding self-reviews escalated for project-lead read
- **Epic 12 Readiness:** **UNBLOCKED** — sprint-status rows aligned to redraft; asm-`#` hack permanence memorialised; no orphan ASSEMBLER references in planning artifacts or memories
- **Production Incidents:** 0
- **Sprint changes during epic:** 0 (one contingent fix-story, 11.5.1.1 antforth defensive saves, dropped permanently 2026-04-28 once firmware fix verified)

### Stories Delivered

| Story | Title | Δ Bytes | Notes |
|-------|-------|---------|-------|
| 11.5.1 | Real-MicroBeast hardware crash audit | 0 | Verdict-only; verdict (c) shared-fault for both 2026-04-27 incidents; spawned 11.5.1.2; 11.5.1.1 deferred contingent then dropped |
| 11.5.1.2 | Firmware BDOS register-preservation reproducer | 0 (separate `.COM` tool) | PROBE.COM authored; confirmed shadow-register clobber on BDOS fns 1/2/10; firmware fix verified all-P 2026-04-28 |
| 11.5.2 | Stack-overflow `-3 THROW` guard | +74 | `check_overflow` + `do_overflow_error` + 5 hot-push call sites + desc-table row; tests 779–782 |
| 11.5.3 | `(` / EVALUATE source-frame fix | +21 | Hybrid (b)+(c): QUERY defensively resets `tib_addr`/`source_id` + EVALUATE wraps INTERPRET in CATCH; 14 new tests |
| 11.5.4 | `print_throw_description` table-walk hardening | −2 | 16-bit `ADD HL, DE` form (wrap-safe modulo 65536); covered by existing tests 150/171/693/753 worst-case walks |
| 11.5.5 | Epic 12 redraft | 0 | Document-only; Story 12.6 (ASSEMBLER wordlist + auto-activation) deleted; Story 12.7 → 12.6 close-out gate; ~8 forward-looking refs scrubbed across `epics.md`/`prd.md`/`architecture.md`/sprint-status.yaml |
| 11.5.6 | `-271` semantic split | +23 | `THROW_ASM_RANGE` → `THROW_ASM_DISP_RANGE` (-271); new `THROW_ASM_BIT_RANGE` (-272); 5 new tests (798–801 + in-pass) |
| 11.5.7 | Epic 11.5 close-out gate (CCD-4 equivalent) | 0 | Audit-only; 7 CCD-4 gate rows all PASS; hardware re-smoke clean; Epic 12 unblock declaration |
| **Total** | | **+116** | |

### Agent Models Used

- All seven stories: Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

---

## Successes

- **Cross-stack defect resolved in 24 hours via verdict-only discipline.** Story 11.5.1 was authored on 2026-04-27 with the constraint "no source edits — deliver the verdict + reproducer." The discipline kept the un-patched antforth source available for the firmware maintainer to reason against; PROBE.COM (Story 11.5.1.2) gave Andy a standalone reproducer that exercised BDOS register preservation without antforth in the loop. Firmware fix landed 2026-04-28 (commit `ced99d1`); PROBE.COM verified all-P. Story 11.5.1.1 (antforth-side defensive saves, contingent on firmware-side inconclusiveness) was dropped permanently. **The shape — verdict-only audit + standalone reproducer + spawned fix-stories from the verdict — is the right vehicle for any future shared-fault investigation.**

- **Seven Epic 11 retro action items, all closed in Epic 11.5.** Adversarial review (every story had 1+ findings); REPL-piped tests as default (zero new asm threads); real-byte-count estimation (Story 11.5.6 hit AC #11 prediction exactly: +6 trampoline + 12 desc-row + 5 widening = +23B); AC-composition validation (11.5.1 Incident #1 reproducer hardware-validated); PARTIAL verdicts require independent verification (11.5.1 `w_ACCEPT_cf` PARTIAL escalated; 11.5.2 explicitly ruled stack-overflow OUT as Incident-#1 cause); inventory grep covers helpers (11.5.2 cross-referenced existing `check_underflow` sites); EXX-hygiene per kernel-internal raise site (11.5.2 `do_overflow_error` + 11.5.6 `asm_bit_range_err` both verified primary-set-only). **Eighth consecutive epic of full retro-commitment closure.**

- **Hardware re-smoke 2026-04-29 confirmed firmware fix silicon-validated.** Story 11.8 12-line batch + Epic-11.5 verdict reproducers ran clean on real MicroBeast; previously-crashing forms (`1 2 3 ' ABORT CATCH . . . .`, `error -3085` family) no longer trigger hard-reboot or BDOS-Err-On-B chain. Three transcripts captured (`bestialitty-20260429-080502.bin`, `-080602.bin`, `-080702.bin`); Story 11.5.7 Task 5 verbatim console output table.

- **Story 11.5.3's CATCH-wrapper inversion was a small but elegant pattern.** Wrapping EVALUATE's INTERPRET call in CATCH makes `(RESTORE-INPUT)` run on **both** success and THROW paths, not just success. The fix was structurally enabled by Story 11.4.1's CATCH frame design — the foundation laid in Epic 11 paid back inside Epic 11.5. **Design-upfront keeps paying — fourth epic.**

- **Story 11.5.6 demonstrated AC-composition discipline.** Both AC #9 and AC #10 delivered full design-upfront coverage (not just one branch). New test 798 (`.bop_ixiyd` covered `.bop_ihl`, matching `feedback_design_upfront.md` precedent); tests 799/800 covered both `.pd_neg` negative-side guards. The pre-Epic 11.5 pattern of "scope to one branch, defer the other" was avoided.

- **Story 11.5.5 redraft scrubbed planning-artifact drift cleanly.** Document-only story but received full adversarial review (6 LOW findings, all in-pass fixed). The `grep -nE 'ASSEMBLER wordlist|ASSEMBLER\.FTH|auto-activat'` gate (Story 11.5.5 + re-run by 11.5.7 AC #4(c)) returned only historical / superseded-tagged hits post-redraft. asm-`#` hack memory updated to "permanent fixture" — no retirement vehicle planned.

- **Test infrastructure additions consolidated cleanly.** All 23 new tests in `tests/throw_migration_tests.fth`, REPL-piped, `\ expect:` per line, Makefile blocks numbered 779..801. Zero new assembly test threads. `feedback_repl_tests_preferred.md` validated for the second epic running.

---

## Challenges

### 1. Low-grade unglamorous donkey work — by design, but still draining

Project lead 2026-04-29: *"it all dragged because it is all low-grade, unglamorous donkey work. but it all adds to the stability and robustness of antforth, so is vital work."* Epic 11.5 was framed honestly as a stabilisation interlude from sprint-change-proposal-2026-04-27 onward — debt retirement, defensive guards, diagnostic precision, document hygiene. The "not glamorous" tax was priced in. **But the dragging is real signal**: when a stabilisation interlude is the right vehicle, it should still be tightly scoped — Epic 11.5's 7 stories (matching the Epic 11 retro's 6 anchors + 1 spawn) was the right size, but the bar should stay high to keep the donkey work's end visible. Lesson 11.5-B captures this.

### 2. Story 11.5.1 PARTIAL on `w_ACCEPT_cf` shadow preservation

The audit flagged `w_ACCEPT_cf` as `IMPLEMENTATION-RISKY` (the lone EXX-around-BDOS site for fn 10) without a targeted hardware probe. Per Epic 11 retro Action Item #5 ("PARTIAL verdicts require independent verification"), this was escalated for project-lead read. Resolution path: Story 11.5.1.2 PROBE.COM verified the firmware fix covers fn 10; transcript evidence is sufficient that the original PARTIAL is no longer load-bearing. **No follow-up needed; the action-item discipline worked exactly as designed.**

### 3. AC line-number drift recurring

Stories 11.5.1 AC #1 and 11.5.6 AC #1 both required re-anchoring line numbers per `feedback_systematic_reference_check.md` — spec-drafted figures were stale by ~6 lines vs current HEAD. Same pattern as Epic 11 challenges. The fix is the discipline: grep is source of truth, not memory. **No new action required — Epic 11 retro Action Item #6 ("inventory grep covers helpers") implicitly already mandates this; the discipline holds.**

### 4. AC test-count off-by-one errors

Stories 11.5.4 AC #6 ("22 tests" → actually 21) and 11.5.5 AC #6 (similar) both had test-count errata caught during adversarial review. Cosmetic but consistent across multiple stories. Same root cause as Epic 11 challenge #3 (AC composition vs trace errors). **The adversarial-review discipline catches these reliably; no new action needed — review finds them, in-pass fixes close them.**

### 5. Story 11.5.1.2 PROBE.COM was a separate `.COM` tool, not antforth kernel

Bookkeeping note rather than a defect: 11.5.1.2 binary delta is 0 against `build/antforth.com` because PROBE.COM is a standalone CP/M binary. Tracked separately; not a regression on antforth ROM trajectory. **Recorded for future cross-stack investigations** — when reproducers live outside the main kernel, the binary-delta accounting must reflect that.

---

## Key Insights

1. **Verdict-only audit + standalone reproducer is the right vehicle for cross-stack defects.** Story 11.5.1's discipline (no source edits during audit; deliver verdict + reproducer; spawn fix-stories from verdict) kept the antforth claim independently verifiable and gave the firmware maintainer a tractable input. 24-hour turnaround on a hardware-only crash class. **Lesson 11.5-A.**

2. **Stabilisation interlude epics are honest framing for low-glamour, high-value work.** Epic 11.5 was explicitly proposed in the Epic 11 retro as a debt-cleanup interlude; sprint-change-proposal-2026-04-27 codified it. Framing it honestly prevents misaligned expectations and protects the work from being deprioritised under feature-shipping pressure. **Lesson 11.5-B.**

3. **The Epic 11 retro proposed 6 anchors; we landed 7 stories** (6 + 1 spawn). Tight scope discipline. The retro-anchors-as-spec pattern (retro proposes; create-epics refines; story IDs match the retro's numbering) made the interlude self-documenting — anyone reading the Epic 11 retro alongside the Epic 11.5 stories sees the same skeleton.

4. **Eighth consecutive epic with full retro-commitment closure.** Adversarial review, REPL-piped tests, real-byte-count estimation, AC-composition validation, PARTIAL-verdict escalation, helper-routed grep, EXX-hygiene per site — all standing process commitments held across Epic 11.5.

5. **Cross-firmware debugging works when both sides have reproducers.** PROBE.COM (antforth-authored) gave the firmware maintainer a Z80/CP/M reproducer that exercised BDOS register preservation without antforth in the loop. The fix landed in commit `ced99d1`; verification was a single PROBE.COM run, not a multi-hour antforth smoke. **Reusable shape** for any future cross-stack work (CP/M variants, BIOS-level interactions, hardware peripherals).

6. **Design-upfront paid back inside Epic 11.5, not just across epics.** Story 11.5.3's CATCH-wrapper fix was structurally enabled by Story 11.4.1's CATCH frame design (saved-BC + SP_safe). The Epic 11 foundation reused inside the Epic 11.5 interlude — fourth epic of `feedback_design_upfront.md` paying back.

---

## Previous Retro Follow-Through (Epic 11)

| # | Action Item | Status in Epic 11.5 |
|---|-------------|---------------------|
| 1 | Adversarial review remains the standard | ✅ **Completed** — every story surfaced findings; zero-finding self-reviews escalated; eighth consecutive epic |
| 2 | REPL-piped tests as default | ✅ **Completed** — all 23 new tests in `tests/throw_migration_tests.fth`; zero new asm threads |
| 3 | Real-byte-count estimation | ✅ **Completed** — 11.5.6 hit AC #11 prediction exactly; cumulative +116B clean reconciliation, 0-byte residual |
| 4 | AC-composition validation extends AC-trace-check | ✅ **Completed** — 11.5.1 Incident #1 reproducer hardware-validated; 11.5.6 ACs #9/#10 fully scoped |
| 5 | PARTIAL verdicts require independent verification | ✅ **Completed** — 11.5.1 `w_ACCEPT_cf` PARTIAL escalated for project-lead read; 11.5.2 explicitly ruled stack-overflow OUT as Incident #1 cause |
| 6 | Inventory grep covers helpers, not just leaves | ✅ **Completed** — 11.5.2 grep on `PUSH BC` + cross-reference with existing `check_underflow` sites |
| 7 | EXX-hygiene per kernel-internal raise site | ✅ **Completed** — 11.5.2 `do_overflow_error` + 11.5.6 `asm_bit_range_err` both verified primary-set-only |

**Eighth consecutive epic with full retro-commitment closure.** All seven actions fully closed; no partials, no carry-overs.

---

## Significant Discoveries — None

Per Story 11.5.7 close-out gate AC #4(d) Epic-12-redraft consistency check: no new significant discoveries surfaced during Epic 11.5. The two Epic 11 retro discoveries (Epic 12 stale, hardware crash class) were both **closed by Epic 11.5 itself** — Story 11.5.5 redrafted Epic 12; Story 11.5.1's verdict + Story 11.5.1.2's PROBE.COM resolved the hardware crash class via firmware fix. **No epic update required for Epic 12.**

---

## Action Items

### Process Improvements (carry forward — eighth consecutive epic)

| # | Action | Owner | Success Criteria |
|---|--------|-------|------------------|
| 1 | Adversarial review remains the standard | All | Reviews surface findings; zero-finding self-reviews trigger second LLM pass / project-lead read |
| 2 | REPL-piped tests as default | Dev Agent | New functionality tested via `tests/*.fth`; zero new assembly test thread additions |
| 3 | Real-byte-count estimation | Dev Agent / SM | AC binary-delta predictions match measured deltas within ±5% |
| 4 | AC-composition validation extends AC-trace-check | SM | AC drafts pass executable validation (`printf \| iz-cpm` smoke) before dev handoff |
| 5 | PARTIAL verdicts require independent verification | SM / Dev Agent | Verdict tables flag PARTIAL rows for cross-pass; project-lead sign-off recorded |
| 6 | Inventory grep covers helpers, not just leaves | SM | Migration inventories explicitly enumerate helper-routed call sites |
| 7 | EXX-hygiene per kernel-internal raise site | Dev Agent | Each kernel-internal raise carries an EXX-state comment matching the verified caller convention |

### New Lessons Captured (Epic 11.5)

| # | Lesson | When to Apply |
|---|--------|---------------|
| 11.5-A | Verdict-only audit stories with hardware reproducers + standalone reproducer (e.g., PROBE.COM) are the right vehicle for cross-stack (firmware + kernel + BIOS) defects. Discipline: no in-pass fixes during audit; deliver verdict + reproducer; spawn fix-stories from verdict; hand external maintainers a reproducer they can run without your stack. | Any future shared-fault investigation between antforth and firmware/BIOS/peripheral; or any external-maintainer collaboration where the antforth-side claim must remain independently verifiable |
| 11.5-B | Stabilisation interlude epics deliver low-glamour, high-value work — debt retirement, defensive guards, diagnostic precision, document hygiene. Frame them honestly as such. **Reason:** prevents misaligned expectations + protects the work from being deprioritised under "we should be shipping features" pressure. **How to apply:** when accumulated debt + a forcing event coincide, propose an explicit interlude epic; don't smuggle stabilisation work into a feature epic where it competes for attention. Keep scope tight (Epic 11.5: 7 stories matched the Epic 11 retro's 6 anchors + 1 spawn). | When debt accumulates past the point of comfortable carry, OR when an external event (hardware bug, security finding, framework upgrade) forces stabilisation work; ALSO whenever a feature epic begins to harbour stealth debt-cleanup work |

### Technical Debt — Epic 11.5 retired

| # | Item (carried from Epic 11 retro) | Resolution |
|---|------|------------|
| 1 | `(` doesn't respect EVALUATE source-frame | ✅ Closed by Story 11.5.3 (hybrid (b)+(c) fix; +21 bytes; 14 new tests) |
| 2 | Stack-overflow `-3` guard not wired | ✅ Closed by Story 11.5.2 (+74 bytes; 5 hot-push sites; tests 779–782) |
| 3 | `print_throw_description` linear walk wrap-unsafe | ✅ Closed by Story 11.5.4 (16-bit ADD HL, DE form; −2 bytes) |
| 4 | `-271` collapses two distinct conditions | ✅ Closed by Story 11.5.6 (semantic split; +23 bytes; 5 new tests) |
| 5 | Epic 12 stale (ASSEMBLER rollback) | ✅ Closed by Story 11.5.5 (document-only redraft; ~8 forward-looking refs scrubbed) |
| 6 | Caught-form coverage gap for asm-error THROW codes -258..-269 | ⏳ **Unblocked** by 11.5.3 EVALUATE fix; harness deferred (low priority — judgment call for future sprint) |
| 7 | `asm_hash_dispatch_hack` retirement plan | 🔒 **Permanent** — no retirement vehicle planned (memorialised in `project_asm_hash_dispatch_hack.md` 2026-04-27) |

### Hardware-Crash Audit — Closed

| Aspect | Resolution |
|--------|------------|
| Verdict | (c) shared-fault — BDOS shadow-clobber on fns 1/2/10 + antforth assumption that CP/M 2.2 doesn't contractually grant |
| Firmware fix | Verified clean — PROBE.COM all-P 2026-04-28 (commit `ced99d1`); maintainer Andy |
| antforth-side hardening | Story 11.5.2 stack-overflow guard (cold-path defensive; not Incident #1 proximate cause) |
| Hardware re-smoke | 2026-04-29 — three transcripts captured; zero hard-reboot, zero BDOS-Err-On-B chain |
| 11.5.1.1 (antforth defensive saves) | Dropped permanently — firmware fix sufficient |

### Documented Follow-Up Opportunities (Carry Forward)

| # | Opportunity | Notes |
|---|-------------|-------|
| 1 | Caught-form coverage gap for asm-error THROW codes -258..-269 | Unblocked by 11.5.3; harness can be added in any future sprint that touches `tests/throw_migration_tests.fth` |
| 2 | Unprefixed `NUMBER?` base-specialization (Epic 9 retro carry) | Still standalone |
| 3 | `.S` migration to pictured output (~90 B) | When ROM pressure surfaces — Epic 12 / 13 the natural triggers |
| 4 | Test-numbering hygiene (9 Makefile duplicate test numbers from Story 11.3) | Cosmetic; renumber on next Makefile-touching story |

---

## Epic 12 Preparation

**Status: UNBLOCKED.** Per Story 11.5.7 close-out gate AC #6:

- Sprint-status rows aligned to redraft: 12-1 wordlist struct + FORTH-WORDLIST → 12-2 WORDLIST + SEARCH-WORDLIST → 12-3 search-order infrastructure → 12-4 compilation-wordlist control → 12-5 ONLY → 12-6 close-out gate (formerly 12.7); old 12.6 ASSEMBLER wordlist row absent
- asm-`#` hack memory marked permanent (no retirement vehicle planned)
- No orphan ASSEMBLER wordlist / `ASSEMBLER.FTH` / auto-activation references in planning artifacts or memories (only historical / superseded-tagged hits remain)
- Epic 12 is **architecturally independent** of Epic 11.5 outputs — wordlist library work on top of stabilised kernel; no hard dependencies on Epic 11.5 deliverables

**No preparation tasks. No critical-path items. No epic-update review session needed.** Epic 12 starts from `12-1-wordlist-struct-hash-parameterisation-and-forth-wordlist-bootstrap: backlog` whenever the project lead is ready.

---

## Epic 11.5 Readiness Assessment

- **Testing & Quality:** ✅ 810 PASS / 0 FAIL · zero regressions on 787-baseline · two-pass adversarial review on every story · 1 MEDIUM finding (11.5.1 `w_ACCEPT_cf` PARTIAL, escalated and resolved by firmware-fix verification); LOW counts elsewhere all in-pass fixed
- **Deployment:** ✅ Committed on `main` (HEAD `d184de4` "split THROW -271 into -271 disp range / -272 bit range" 2026-04-29)
- **Stakeholder Acceptance:** ✅ Project lead 2026-04-29: *"a fantastic effort to identify and isolate a firmware issue which was then swiftly resolved"*
- **Technical Health:** ✅ +116 bytes within debt-retirement / hardening envelope (95% of growth: 11.5.2 overflow guard + 11.5.6 semantic split — both within scope); 5 of 6 carry-over debt items retired; 6th unblocked
- **Hardware:** ✅ Real-MicroBeast re-smoke 2026-04-29 clean across Epic-11.5's expanded surface; firmware fix silicon-validated
- **Unresolved Blockers:** ✅ None

**Epic 11.5 status: COMPLETE.** Optional `git tag -a v1.11.5` at project lead's discretion — not applied by dev agent.

---

## Next Steps

1. **Mark Epic 11.5 retrospective closed** — `sprint-status.yaml`: `epic-11.5-retrospective: optional → done` (this retro saving updates the row).
2. **Apply optional `v1.11.5` tag** at project-lead discretion (proposed: `git tag -a v1.11.5 -m "Stabilisation, hardware audit, debt cleanup, Epic-12 redraft prep"`).
3. **Begin Epic 12 (Multi-Vocabulary Search-Order)** when project lead is ready — start with `bmad-bmm-create-story` on Story 12.1 (`12-1-wordlist-struct-hash-parameterisation-and-forth-wordlist-bootstrap`). Epic transitions to `in-progress` automatically when first story is created.
4. **Carry forward the 7 standing process commitments** (see Action Items §Process Improvements) into Epic 12 — eighth consecutive epic standing.
5. **Carry forward the 4 documented follow-up opportunities** as ROM pressure or scope alignment surfaces.

---

*Epic 11.5 closes Phase-2's debt-cleanup interlude — proposed in the Epic 11 retro, codified by sprint-change-proposal-2026-04-27, executed in 7 stories. The hardware crash class triggered the audit; the audit produced a verdict-with-reproducers; the firmware maintainer fixed it in 24 hours; antforth added defensive hardening alongside. Five carry-over debt items retired, sixth unblocked, asm-`#` hack permanence memorialised, Epic 12 redrafted to match the 2026-04-20 ASSEMBLER rollback. 23 new REPL tests, +116 bytes, zero regressions, hardware re-smoke clean. Eighth consecutive epic with full retro-commitment closure. Epic 12 unblocked from a known-clean baseline. Low-grade donkey work, vital outcome.*
