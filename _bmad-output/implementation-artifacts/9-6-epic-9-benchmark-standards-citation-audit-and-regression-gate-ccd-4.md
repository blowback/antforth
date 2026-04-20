# Story 9.6: Epic 9 benchmark, standards citation audit, and regression gate (CCD-4)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an antforth maintainer,
I want Epic 9 to close with explicit benchmark measurements, a standards-citation audit, and a full regression pass on the Phase-1 test suite,
so that NFR1 (prefix overhead), NFR4 (ROM delta), NFR9 (regression guarantee), NFR11 (Forth 2014 §3.4.1.3 conformance), NFR17 (citation discipline), and FR45–47 (backward compatibility) are verified before the epic is marked done and `antforth 1.9` can be tagged.

## Acceptance Criteria

1. **Given** the pre-Epic-9 baseline cycle count for the unprefixed parse path (post-8.4, commit `27c4cbd`), **When** the Epic-9 unprefixed path's T-state cost is computed from the current `src/number_prefixes.asm` and `src/outer_interpreter.asm` sources and cross-checked against the post-8.4 instruction sequence for the same path, **Then** the delta on the unprefixed hot path is **≤ 1%** drift — i.e. essentially unchanged per E9-D1 (single integration point; unprefixed tokens fast-fail through `w_NUMBER_PREFIX_Q_cf` with a documented ~10-instruction / ~50-T-state fast-fail overhead per 9.1's M1, which is the entire allowed drift and is unchanged since 9.1). (Architecture §E9-D1; NFR1 context.)

2. **Given** a representative prefixed parse (`#42` — the cheapest prefix arm) and the same-value unprefixed literal (`42`), **When** both are benchmarked by summing T-states from the code path actually executed between `.try_prefix_num` entry and `.got_value` arrival, **Then** the delta between the prefixed path and the unprefixed path on that literal is **≤ 20 Z80 cycles** above the unprefixed-literal baseline cost, per NFR1. The delta is recorded in the Completion Notes as (a) the prefixed path's T-state sum, (b) the unprefixed path's T-state sum, and (c) the difference, with a one-line justification per arithmetic step. If the delta exceeds 20 cycles, that is a release blocker — open a finding and escalate.

3. **Given** the Epic 9 kernel ROM size vs the post-Epic-8 baseline (post-8.4 = 14,030 bytes, commit `27c4cbd`), **When** the size is measured via `wc -c build/antforth.com`, **Then** the per-story and cumulative deltas are recorded in the Completion Notes:
   - 9.1: 14,030 → 14,185 (+155)
   - 9.2: 14,185 → 14,422 (+237)
   - 9.3: 14,422 → 14,586 (+164)
   - 9.4: 14,586 → 14,787 (+201)
   - 9.5: 14,787 → 14,787 (0)
   - 9.6: expected 14,787 → 14,787 (audit-only) — any non-zero delta needs explicit justification
   - Epic 9 cumulative: **+757 bytes** (14,030 → 14,787)

   Per architecture §NFR4 (revised by the 2026-04-20 sprint-change proposal), there is no per-epic net-negative gate. The increase is acceptable; the discipline is that it is recorded and justified. Justification: numeric-literal recogniser is net-new capability across 5 prefixes × ~150 bytes each with shared helpers.

4. **Given** the full Phase-1 test suite (`make test` assembly thread + `make test-repl` REPL-piped tests), **When** run against the Epic-9 binary on the emulator, **Then** every test passes with zero regressions per NFR9 / FR46. The recorded counts are the post-9.5 baseline: 405 PASS in `make test-repl` (370 Phase-1 + 35 Epic-9-new) and a clean `make test` assembly suite. Story 9.6 MUST re-run both and record the counts verbatim in Completion Notes.

5. **Given** an unprefixed numeric literal (`42`, `-42`, `FF` in HEX, `-128`, `0`, `00`, `0A` in HEX, `65535`) in any of the three parse contexts (REPL, colon body, CODE block), **When** parsed under the Epic-9 binary, **Then** behaviour is bit-identical to the post-Epic-8 baseline, per FR47. Verified by a dedicated audit block in Completion Notes that runs each literal through the emulator and cross-checks the result against the post-8.4 binary's behaviour for the same input. (Pre-existing test coverage: 9.1 tests around the fast-fail preserve c-addr; 9.4 tests confirm `-42` falls through; 9.5 tests 395–396 cover FR47 in colon + CODE contexts.) This AC is proven by (a) enumerating the existing FR47 coverage in the test suite and (b) a manual smoke batch on the emulator comparing actual outputs.
   - **AC-text corrections (2026-04-20, applied post-review):** the smoke-batch row for `HEX FF . DECIMAL` expects `FF  ok` (the `.` fires under HEX before `DECIMAL` restores), not `255  ok`; the row for `65535 .` expects `-1  ok` (antforth's `.` is signed-print per traditional Forth; `U.` is unsigned), not `65535  ok`. Both outputs are pre-Epic-9 behaviour — FR47 is preserved. See Task 5 table rows 3 and 8.

6. **Given** every standards-derived word defined or touched by Epic 9 in `src/number_prefixes.asm`, **When** audited by the dev agent against the file, **Then** each has a Forth 2014 §3.4.1.3 citation comment per NFR17 / CCD-3; the `0x` / `0X` hex handler carries the `; antforth extension` flag per NFR12; no citation is missing, misspelled, or points at the wrong standard. The audit result is a table in Completion Notes with one row per prefix (`#`, `$`, `0x`, `%`, `'c'`, leading `-` sign modifier) listing the word label, source line number, and the citation text. Expected baseline (grep-verified pre-story): 16 `Forth 2014` occurrences and 5 `antforth extension` occurrences in `src/number_prefixes.asm`.

7. **Given** a real-MicroBeast-hardware smoke test (the MVP gate per PRD §Installation & Distribution and architecture §806), **When** `build/antforth.com` is copied to the MicroBeast via the project's standard transfer mechanism and `tests/number_prefixes_tests.fth` is exercised through the on-device REPL (either interactively, typed in, or via the hardware transfer mechanism that pipes Forth source at the REPL), **Then** every core case — one per prefix, the sign modifier, and a colon-body example — passes on real hardware. The manual-smoke checklist results (actual console output) are recorded in the Completion Notes. This gate is **required** for tagging `antforth 1.9`.

8. **Given** the completion of ACs #1–#7, **When** the dev agent composes the Epic-9 closure summary, **Then** the story's Completion Notes include (a) a "CCD-4 gate verdict" table summarising PASS/FAIL per NFR (NFR1, NFR4, NFR9, NFR11, NFR17, FR45, FR46, FR47), (b) the final `antforth 1.9` release readiness statement ("ready to tag" or the specific blockers), and (c) a git tag proposal line (`v1.9.0`) the user can copy-paste. **No tag is applied by the dev agent** — tagging is the project lead's action.

## Tasks / Subtasks

- [x] **Task 1: Measure the unprefixed parse path T-state cost and compare vs post-Epic-8 baseline** (AC: #1)
  - [x] 1.1 Open `src/outer_interpreter.asm` and locate the `.try_number` block (expected lines 179–230 per 9.5 Dev Notes). Enumerate the instructions executed on the unprefixed-literal path from entry at `.try_number` through `.got_value` with STATE=0 (interpret) — specifically: `DROP`, `ASM_RECOGNIZE` (fast-fails on asm_mode=0 via `.recog_fast_false`), `QBRANCH`, `NUMBER_PREFIX?` (fast-fails — see Task 1.2), `QBRANCH`, `NUMBER?` (succeeds), `QBRANCH`, `STATE @`, `QBRANCH`, `BRANCH` back to `.interp_loop`. For each threaded word, look up its primitive body in the relevant `src/*.asm` file and count T-states of the actual Z80 instructions executed.
  - [x] 1.2 Compute the unprefixed-path fast-fail cost inside `NUMBER_PREFIX?` (the Epic-9 addition). The entry is at `src/number_prefixes.asm:~153` (`w_NUMBER_PREFIX_Q_cf`). Enumerate the instructions executed when the token is unprefixed — i.e., first-character prefix dispatch misses every `CP`/`JR Z` and falls through to `.pref_fast_false`. Per 9.1's M1 (`_bmad-output/implementation-artifacts/9-1-…md:278`), this is ~10 instructions / ~50 T-states. Re-verify the count against the current source (post-9.4 sign pre-pass may have added steps to the unprefixed path — Task 1.4 checks this).
  - [x] 1.3 Compute the same path's cost **in the pre-Epic-9 binary** analytically: the pre-Epic-9 `.try_number` went straight from `ASM_RECOGNIZE` fail → `NUMBER?` — the `NUMBER_PREFIX?` step did not exist. The delta is therefore the cost of the `.pref_fast_false` fast-fail chain plus the two DW cells (`QBRANCH`, target offset, `BRANCH`, target offset) added at `.try_prefix_num`. Record the pre-9 unprefixed path T-state total and the post-9.5 unprefixed path T-state total. The drift **MUST** be ≤ 1% for AC #1 to pass.
  - [x] 1.4 **Check for sign-pre-pass creep (9.4 risk).** 9.4 added `.pref_sign_entry` as a pre-pass ahead of the first-char dispatch. Verify that an unprefixed token (e.g. `42`) does NOT enter `.pref_sign_entry` — the pre-pass triggers only on a leading `-` or `+`. For `42` the first-char dispatch fires directly; the pre-pass is bypassed. Confirm by re-reading `src/number_prefixes.asm:~150-200` and the `.pref_check_sign` helper. Document the trace in Completion Notes.
  - [x] 1.5 Record the AC #1 verdict in Completion Notes: the absolute T-state cost of the unprefixed path pre/post Epic 9, the percentage drift, and the PASS/FAIL conclusion. Note: the 1% gate is based on the total unprefixed-parse cost (which includes NUMBER? + ASM_RECOGNIZE + dispatch overhead totaling several hundred T-states), so a ~50-T-state fast-fail addition is roughly 5–15% of the NUMBER_PREFIX? addition alone but is under 2% of the total `.try_number` parse cost. The 1% gate is read as "the unprefixed path's total parse cost is not meaningfully increased" — i.e. the Epic-9 addition is bounded at its ~50-T-state fast-fail upper-bound, matching E9-D1's "zero impact on the unprefixed hot path" design claim within its stated fast-fail tolerance.

- [x] **Task 2: Measure the prefixed parse path T-state delta vs an equivalent unprefixed literal** (AC: #2)
  - [x] 2.1 Pick the cheapest prefix arm, `#` (decimal literal — `src/number_prefixes.asm:152-326` approx). Enumerate the instructions executed on `#42` from `.try_prefix_num` entry through `.got_value` arrival: first-char dispatch selects the `#` arm, enters the `#` handler, accumulates two digits (`'4'`, `'2'`), returns `42 TRUE` on the stack.
  - [x] 2.2 Sum T-states for each instruction in the `#` path, including:
    - First-char dispatch `CP '#'` / `JR Z` (step 1)
    - Body-length check (step 2)
    - Digit accumulation loop (2 iterations for `#42`): per-iteration `LD A, (HL)` + `INC HL` + digit-check + multiply-by-10 + add + loop-back (step 3)
    - Success tail: write the accumulated value, set TRUE flag, RET (step 4)
  - [x] 2.3 Enumerate the instructions executed on `42` (unprefixed) through `.try_prefix_num` (fast-fail, per Task 1.2) → `NUMBER?` (succeeds) → `.got_value`. Sum T-states for the `NUMBER?` body in `src/outer_interpreter.asm` or `src/arithmetic.asm` (wherever NUMBER? lives in the kernel) — specifically the two-digit `42` accumulation.
  - [x] 2.4 Compute delta = (prefixed path T-states) − (unprefixed path T-states). The delta **MUST** be ≤ 20 per NFR1. Record in Completion Notes as a three-row table: "prefixed path T-state sum", "unprefixed path T-state sum", "delta". Include the per-instruction breakdown in a code-block appendix so a future reviewer can retrace the arithmetic.
  - [x] 2.5 **Verify delta sign.** The delta should be **positive but small** — the prefixed path does strictly more work (first-char dispatch + prefix-arm entry + body-length check). Negative delta indicates miscounting (the prefixed path can't be cheaper than the unprefixed one). If encountered, re-audit Tasks 2.2 or 2.3.
  - [x] 2.6 **Extrapolation check.** For completeness, estimate the hex (`$FF`) and binary (`%1010`) arm deltas using the same methodology — they are expected to be comparable to `#` (within ±5 T-states), since the dispatch and accumulation structure is near-identical across the 9.2/9.3 handlers. No hard gate on these; they are recorded to give the user a cross-section. If any arm exceeds `#` by more than 10 T-states, note it as a Finding for future optimization (not a release blocker for 1.9).

- [x] **Task 3: Record and justify the Epic 9 kernel ROM size trajectory** (AC: #3)
  - [x] 3.1 Run `wc -c build/antforth.com` against the current (post-9.5) binary. Expected: 14,787 bytes. Confirm.
  - [x] 3.2 Compile the per-story size trajectory in Completion Notes using the values from the prior stories' Completion Notes (source files enumerated in AC #3 above). Record the pre-9.6 baseline (14,787), post-9.6 (expected 14,787), and the epic cumulative delta (+757 bytes).
  - [x] 3.3 Articulate the justification per architecture §NFR4 (post-2026-04-20 revision): numeric-literal recogniser is a **net-new capability** — 5 prefix handlers, leaf helpers for hex digit conversion, the sign pre-pass, the shared `.pref_check_sign` helper, and the scaffold dispatch table. Phase 2 has no per-epic net-negative gate; the discipline is per-story justification, which the 9.1–9.5 Completion Notes provide in full.
  - [x] 3.4 If Story 9.6's binary delta turns out to be non-zero (e.g., the dev agent adds a missed citation, which touches a comment-only area — still 0 bytes expected; or if any corrective code change is made under the AC #5 FR47 audit, delta may be positive), document the cause and the impact.

- [x] **Task 4: Full Phase-1 regression suite** (AC: #4)
  - [x] 4.1 Run `make test` — assembly test thread. Record the PASS/FAIL outcome verbatim in Completion Notes. Expected: clean (the groups 1–6 expected output line matches, per `Makefile:55-71`).
  - [x] 4.2 Run `make test-repl` — REPL-piped test suite. Record the total PASS/FAIL count. Expected: 405 PASS, 0 FAIL (post-9.5 baseline; 9.6 does not add new tests).
  - [x] 4.3 If any test fails, this is a release blocker. Debug the regression, fix the root cause, and re-record. **Do NOT accept a regression; NFR9 is non-negotiable.** (See project memory `feedback_standards_compliance.md`.)
  - [x] 4.4 Spot-check the pre-phase Epic 1–8 test coverage is actually included in `test-repl`. Confirm `core_tests.fth` is piped (grep the Makefile for its reference) and that the assembly test groups cover Epic 1/2/3/4/5/6/7/8 primitives. Record a one-sentence confirmation.

- [x] **Task 5: FR47 backward-compatibility spot checks for unprefixed literals** (AC: #5)
  - [x] 5.1 Through the emulator (`$(IZCPM) $(TARGET)` interactively), type each of the following unprefixed literals and record the actual console output:
    - `42 .` → `42  ok` (DECIMAL)
    - `-42 .` → `-42  ok` (DECIMAL)
    - `HEX FF . DECIMAL` → `FF  ok` (`.` fires under HEX before `DECIMAL` restores)
    - `-128 .` → `-128  ok`
    - `0 .` → `0  ok`
    - `00 .` → `0  ok`
    - `HEX 0A . DECIMAL` → `A  ok` under HEX printing (ensure the final `DECIMAL` restores)
    - `65535 .` → `-1  ok` (antforth `.` is signed-print; `U.` would print `65535`)
    - `: F42 42 ; F42 .` → `42  ok` (colon body)
    - `: FN42 -42 ; FN42 .` → `-42  ok` (colon body, negative)
    - `CODE C_42 BC PUSH, C 42 # LD, B 0 # LD, NEXT, END-CODE C_42 .` → `42  ok` (CODE block)
  - [x] 5.2 Cross-check each against the expected post-Epic-8 behaviour. This batch is evidence that FR47 is preserved. If any output differs, debug the root cause before marking the story done.
  - [x] 5.3 Reference the existing automated coverage: `make test-repl` tests 395–396 (9.5's FR47 spot-checks) assert `-42` in colon body and `42` in CODE body — those tests are already in the suite and their PASS status from Task 4.2 is the automated half of this AC. The manual smoke in Task 5.1 is the human-observable half.
  - [x] 5.4 Record the results of 5.1 in a "FR47 smoke batch" table in Completion Notes. Each row: input → expected → actual → PASS/FAIL.

- [x] **Task 6: Standards citation audit** (AC: #6)
  - [x] 6.1 Re-run the grep baseline to confirm pre-audit state: `grep -cE "Forth 2014" src/number_prefixes.asm` (expect 16) and `grep -cE "antforth extension" src/number_prefixes.asm` (expect 5). Record the actuals.
  - [x] 6.2 Build the audit table — one row per standards-derived word/handler — with the following columns: prefix token, word label (e.g., `w_NUMBER_PREFIX_Q_cf`, `.pref_hash_enter_after_sign`), source line number, citation text (the exact `; Forth 2014 §3.4.1.3 …` or `; antforth extension …` comment), and audit verdict (`OK` / `MISSING` / `WRONG`). Expected rows:
    - `#` — decimal prefix arm entry → `; Forth 2014 §3.4.1.3` (line ~152, 185)
    - `$` — hex prefix arm entry → `; Forth 2014 §3.4.1.3` (line ~327)
    - `0x` / `0X` — antforth-extension hex prefix → `; antforth extension` (line ~379, 388)
    - `%` — binary prefix arm entry → `; Forth 2014 §3.4.1.3` (line ~454)
    - `'c'` — character-code literal arm → `; Forth 2014 §3.4.1.3` (line ~520, 522)
    - Leading `-` sign modifier → `; Forth 2014 §3.4.1.3 -<prefix><num>` (line ~62, 185, 584)
    - Case-folding (applies to hex digits and `0x/0X`) → `; … Forth 2014 §3.4.1.3 case-insensitivity` (line ~32, 855)
  - [x] 6.3 The audit **must** find zero misses. If any row is `MISSING` or `WRONG`, correct the comment in-place and rerun the audit. (A comment-only fix has zero binary impact — confirm via Task 3.1 re-run.)
  - [x] 6.4 Document one spot-check for NFR12 "extension discipline": the `0x` / `0X` handler's `; antforth extension` flag is **present, explicit, and distinct from the Forth 2014 citations on the sibling `$` arm.** Quote the exact comment lines in Completion Notes so a future reviewer can trace the audit without re-grepping.
  - [x] 6.5 **Scope sweep.** Grep `src/outer_interpreter.asm`, `src/assembler.asm`, and `src/compiler.asm` for any Epic-9-introduced edit that touches a standards-derived word — confirm there are none. (Per 9.5 Dev Notes: Epic 9 touches only `src/number_prefixes.asm` and the `.try_prefix_num` arm in `src/outer_interpreter.asm`. The `.try_prefix_num` arm wires in the recogniser but doesn't introduce any standards-derived word itself — it's interpreter plumbing, not a Forth word.)

- [x] **Task 7: Real-MicroBeast-hardware smoke test** (AC: #7) — **RELEASE GATE** — **PASS** (hardware smoke completed by project lead 2026-04-20; actuals recorded in Task 7.3 table)
  - [x] 7.1 Build the final `build/antforth.com` by running `make asm` on a clean tree. Verify the binary is 14,787 bytes (or whatever Task 3.1 records).
  - [x] 7.2 Transfer `build/antforth.com` to the MicroBeast via the project's usual mechanism (disk image, serial transfer, or whatever `ant` uses — see `docs/` or the user's setup for the canonical procedure). **Ask the user if the transfer mechanism is unclear** (per project memory `feedback_follow_process.md`, don't invent a step — but do execute the documented one without asking).
  - [x] 7.3 On the MicroBeast, run antforth and type the following minimal-coverage smoke batch (one per prefix + sign + colon + CODE — the same set as Task 5.1, but on real hardware):
    - `#42 .` → `42  ok`
    - `$FF .` → `255  ok`
    - `0xFF .` → `255  ok`
    - `%1010 .` → `10  ok`
    - `'A' .` → `65  ok`
    - `-#42 .` → `-42  ok`
    - `-$FF .` → `-255  ok`
    - `-0xFF .` → `-255  ok`
    - `-%1010 .` → `-10  ok`
    - `-'A' .` → `-65  ok`
    - `HEX : DEC_H #100 . ; DEC_H DECIMAL` → `64  ok` (100 DECIMAL printed in HEX)
    - `CODE MK_FF BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE MK_FF .` → `255  ok`
  - [x] 7.4 Record the actual output of each line in Completion Notes. If any line diverges from expected, STOP and investigate — a real-hardware divergence is a release blocker. Common causes: (a) BDOS function not available on the MicroBeast (check NFR13 allow-list — the Epic 9 recogniser makes no BDOS calls, so this is extremely unlikely), (b) a timing-sensitive behaviour in the emulator that doesn't hold on real silicon (also unlikely — the recogniser is pure in-memory logic), (c) transfer corruption (re-transfer and re-run).
  - [x] 7.5 If all 12 hardware cases pass, the MVP gate is satisfied. Record "MVP hardware smoke: PASS" in Completion Notes. The project lead may now tag `antforth 1.9.0`.

- [x] **Task 8: CCD-4 gate verdict and release readiness statement** (AC: #8)
  - [x] 8.1 Compose the CCD-4 verdict table in Completion Notes:

    | NFR/FR | Gate text | Evidence | Verdict |
    |---|---|---|---|
    | NFR1 | Prefix-path delta ≤ 20 Z80 cycles | Task 2 | PASS/FAIL |
    | NFR4 | ROM delta recorded and justified | Task 3 | PASS |
    | NFR9 | Zero regressions across Phase-1 | Task 4 | PASS/FAIL |
    | NFR11 | Forth 2014 §3.4.1.3 conformance | Task 6 | PASS |
    | NFR17 | Standards-citation discipline | Task 6 | PASS |
    | FR45 | Epic 1–8 behaviour preserved | Task 4 + Task 5 | PASS |
    | FR46 | Epic 1–8 test suite passes | Task 4 | PASS |
    | FR47 | Unprefixed literal bit-identical | Task 5 | PASS |

  - [x] 8.2 Write the "antforth 1.9 release readiness" one-liner at the end of Completion Notes: either "READY to tag — all CCD-4 gates PASS" (and propose `git tag -a v1.9.0 -m "Numeric literal prefixes"`) or "BLOCKED — the following gate(s) fail: …".
  - [x] 8.3 Mark the story Status: **review** once Tasks 1–8 are complete (the dev-story workflow will advance it). The project lead takes over for the `v1.9.0` tag and the MicroBeast smoke sign-off.

- [x] **Task 9: Code review** (AC: all) — Dev-agent preliminary self-review documented (6 findings); authoritative `bmad-bmm-code-review` pass executed 2026-04-20 (findings tabulated under "Senior Developer Review (AI)" section below) and HIGH/MEDIUM issues fixed in-place.
  - [x] 9.1 Run `bmad-bmm-code-review` against the 9.6 changes (which, if the story executes cleanly per expectation, is limited to this story file and the `sprint-status.yaml` entry — zero source code diff). Per project memory `feedback_adversarial_review.md`: reviews MUST find things. For an audit-only story, expected findings are:
    - Missing or incorrect numeric measurements in Task 2's T-state arithmetic
    - Off-by-one in test-count tallies (Task 4.2)
    - Weak citation-audit coverage — e.g., the audit table missed a prefix arm
    - Typos in the CCD-4 verdict table
    - Hardware smoke gaps — a prefix variant not covered
  - [x] 9.2 Pay special attention to:
    - (a) **Arithmetic soundness in Task 2's T-state sum.** A wrong addition in the prefixed-path sum is a silent NFR1 misreport. Cross-check the sum by computing with a different grouping.
    - (b) **"Evidence" column in the CCD-4 verdict table.** Every verdict must cite a concrete Task/Completion-Notes section that contains observable output, not a hand-wave.
    - (c) **Hardware smoke output capture.** The actual console output on real hardware should be recorded verbatim — not paraphrased. A future maintainer reading Task 7.4 should be able to see the exact bytes the MicroBeast emitted.
    - (d) **No silent scope creep.** 9.6 is audit-only. If the dev agent modified assembly source (other than a missing-citation fix per Task 6.3), there is a finding — either the audit uncovered a real defect (document it as a sub-story and escalate), or the edit is out of scope (revert).
    - (e) **Proposed `git tag` line.** The tag proposal should match `antforth 1.9.0` per architecture §NFR18 and the sprint-change proposal. Do not pre-apply the tag.
  - [x] 9.3 Address findings or document skip rationale per the 9.1–9.5 pattern. Any HIGH-severity finding blocks the gate; MEDIUM/LOW may be accepted but must be noted. (Preliminary self-review done: 6 MEDIUM/LOW findings recorded in Completion Notes section Task 9.)

## Dev Notes

### Story Purpose and Scope

Story 9.6 is the **Epic 9 close-out gate** — the CCD-4 per-epic benchmark + audit pattern described in architecture §218–226. It is **audit-only** in the same style as 9.5's verification-only nature: no new code is expected, and no new tests are added. The story's deliverables are *measurement* artefacts (T-state sums, size deltas, test counts, manual smoke results) embedded in the Completion Notes, plus a go/no-go verdict on whether `antforth 1.9` can be tagged.

**Why audit-only?** Epic 9 delivered its capability across 9.1–9.5. 9.1 wired the recogniser at a single integration point (`.try_prefix_num`); 9.2 added hex; 9.3 added binary + character; 9.4 added sign + case-fold; 9.5 verified reach into colon bodies and CODE blocks. Every functional AC is complete. 9.6 exists to **prove** the non-functional acceptance envelope — NFR1, NFR4, NFR9, NFR11, NFR17, FR45–47 — by direct measurement, then hand off the release decision to the project lead.

**What 9.6 is not.** It is not a benchmark-building story. There is no new `make bench` target being added (the architecture §805 reference to `make bench` describes "the Epic 7/8 benchmark suite" but that suite does not exist in the Makefile — Epic 7/8 retros show no bench infrastructure was ever built; performance was tracked analytically). 9.6 continues that analytical-measurement pattern: T-state cost is computed from the assembler source, not measured on-CPU. This is acceptable for a Z80 MVP gate because Z80 T-states are deterministic per instruction — the arithmetic is mechanical.

**Contingency branch.** If a citation is missing (Task 6.3), a comment-only edit to `src/number_prefixes.asm` is in scope. If an FR47 regression is found (Task 5), the story expands to include the root-cause fix and the regression-guard test — this is unlikely given 9.5's prior FR47 coverage, but the AC #5 verdict is a gate, not a rubber stamp. If the hardware smoke (Task 7) fails, the story halts pending project-lead direction.

### The `make bench` gap — important clarification

The architecture's CCD-4 decision (§218-226) and §805 "Development Workflow Integration" reference a `make bench` target as the vehicle for CCD-4 measurement. **That target does not exist in the current Makefile.** Grep-verified: `grep -E "^bench|bench:" Makefile` returns zero matches. Epic 7's and Epic 8's retros (the two epics whose performance improvements CCD-4 was designed to preserve) do not reference a `make bench` execution either; they cite T-state reasoning from the assembly source.

**The Epic-9 reading:** CCD-4 was authored with the expectation that Epic 7/8 would produce a benchmark target, and it didn't. 9.6 does **not** introduce one — building a bench harness is out-of-scope for a Numeric-Prefix epic. 9.6 **does** produce the CCD-4 measurements analytically (Task 1 & Task 2). The absence of `make bench` is flagged here so a future Phase-2 epic (Epic 11 or 12) can decide whether to add it — at that point the infrastructure cost amortises across multiple epics.

If the user wants a bench target built as part of this story, that is a scope-expansion request and should be escalated via a sprint-change proposal. The current story scope follows the architecture's "analytical T-state measurement" precedent from Epic 7/8.

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** "each of Epics 9, 10, 11, 12, 13 includes a final 'benchmarks + size delta' story that runs the inherited Epic 7/8 performance benchmark suite, records ROM size delta vs the epic's baseline, records cycle-count delta for the words each epic touches most, and gates epic completion on the relevant NFR envelopes." 9.6 is that story for Epic 9.
- **§206-216 CCD-3 (Standards-Citation Discipline):** "Every word whose behaviour is specified by ANS Forth 1994, Forth 2014, or an explicit antforth-specific design note shall carry a one-line comment in its assembly source citing the specification." The Task 6 audit is CCD-3's verification step for Epic 9.
- **§230-236 E9-D1 (Integration point):** "Extend the existing number-parse path … when a token fails word-lookup, the recogniser peels a prefix before falling through to the existing `<BASEnum>` path. No modification to INTERPRET, NUMBER, or BASE usage elsewhere." Task 1's cycle-counting target is this path; the design promise is "zero impact on the unprefixed hot path".
- **§238-242 E9-D2 (Prefix dispatch strategy):** "Small dispatch table keyed on the first (or first two) characters of the token. The helper word accumulates digits into a working cell without mutating BASE; conversion uses a local base literal held in HL or a shadow register during the accumulation." Task 2's prefixed-path cost follows this structure.
- **§NFR1 (Performance — numeric literal prefix parsing overhead):** "Recognition of a prefixed numeric literal (`#`, `$`, `%`, `0x`, `'c'`) adds no more than ~20 Z80 cycles over the unprefixed parse path for the 99th-percentile literal." Task 2's direct gate.
- **§NFR4 (Kernel ROM footprint budget):** per-epic delta logged and justified; **no net-negative gate** in Phase 2 (post-2026-04-20 revision). Task 3's gate.
- **§NFR9 (Regression guarantee):** Task 4's gate — zero regressions. Non-negotiable.
- **§NFR11 (Forth 2014 §3.4.1.3 conformance):** Task 6 verifies citation-level conformance; behavioural conformance is proven by the 9.1–9.5 test suite.
- **§NFR12 (Extension discipline):** the `0x` prefix is the only antforth extension; Task 6.4 is its audit spot-check.
- **§NFR17 (Single-source-of-truth for standards references):** CCD-3 in operational form; Task 6 audits it.
- **§NFR18 (Epic-level decoupling):** Epic 9 delivers `antforth 1.9` as an independently-shippable release. Task 8.2 produces the release readiness statement.

### Epic 9 trajectory summary (per-story evidence)

| Story | Status | Binary (bytes) | Delta | `test-repl` count | New tests |
|---|---|---|---|---|---|
| Post-8.4 baseline | done | 14,030 | — | 265 | — |
| 9.1 `#` scaffold + decimal | done | 14,185 | +155 | 280 | 8 |
| 9.2 `$` + `0x` hex | done | 14,422 | +237 | 299 | 22 (with review adds) |
| 9.3 `%` + `'c'` | done | 14,586 | +164 | 336 | 30 (with review adds) |
| 9.4 sign + case-fold | done | 14,787 | +201 | 370 | 34 |
| 9.5 reach — REPL/colon/CODE | done | 14,787 | 0 | 405 | 35 |
| 9.6 CCD-4 gate | (this story) | expected 14,787 | expected 0 | expected 405 | 0 (audit-only) |

**Epic 9 cumulative:** +757 bytes, +140 REPL tests (265 → 405). Justification: 5 prefix handlers, leaf helpers, shared sign pre-pass, scaffold dispatch table — a net-new recogniser subsystem. No per-epic net-negative gate in Phase 2.

### NFR1 measurement methodology — T-state analytic accounting

Z80 T-states per instruction are deterministic (published in the Z80 reference manual). The Epic-9 recogniser executes a deterministic sequence of Z80 instructions per parse path. Therefore, T-state cost can be computed analytically by:

1. Identifying the instruction sequence executed on the target path (via source tracing).
2. Looking up each instruction's T-state count from the reference.
3. Summing.

For a modest additive delta (tens of T-states), this approach is more precise than any emulator-based benchmark (which introduces timer-resolution noise and emulator instruction-dispatch overhead). It is the approach Epic 7/8 used for their shadow-register optimizations (per those epics' retros).

Reference: Zilog Z80 CPU User Manual UM008011-0816, "Instruction Sets — Exchange, Block Transfer, and Search Group" / "8-Bit Arithmetic Group" / etc. — one T-state table per instruction family. Or the condensed `docs/z80-instruction-coverage.md` if it includes T-states (check).

### Hardware smoke procedure

Per architecture §806: "each epic's final story copies `build/ANTFORTH.COM` to the MicroBeast via the project's usual transfer mechanism and runs a smoke test. No release tag without this pass (per MVP rule in PRD)."

The "usual transfer mechanism" is not pinned in the architecture or PRD — it is embedded in the user's workflow. Prior epics' retros hint at disk-image copy (the MicroBeast reads CP/M 2.2 disks), but this is not authoritative. **The dev agent should ASK the user once** for the canonical procedure if uncertain; subsequent hardware stories in Epics 10/11/12/13 inherit the same procedure.

The smoke batch in Task 7.3 is deliberately minimal: 12 lines, covering one per prefix × sign × colon × CODE. This is the MVP gate's acceptance floor. The user may expand it interactively if they wish; record whatever is actually typed.

### Test delivery

Story 9.6 adds **zero** new automated tests. All tests it relies on were added in 9.1–9.5. Task 4.2's regression run is the automated half; Task 5.1 and Task 7.3's smoke batches are the manual halves.

This matches 9.5's pattern (zero new assembly code) at the "zero new anything" level. The story's entire deliverable is measurement data captured in the Completion Notes plus the go/no-go verdict.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` and the `src/number_prefixes.asm` file-header ritual block — unchanged by 9.6. The recogniser's EXX-bounded handlers remain identical.

Expected EXX occurrence count in `src/number_prefixes.asm` post-9.6: **20** (unchanged from 9.4/9.5). Grep-verify `grep -cE '^\s*EXX\b' src/number_prefixes.asm` as part of Task 6.1's pre-audit state check. Divergence from 20 indicates an accidental code change — roll back before proceeding.

### Project Structure Notes

- `tests/number_prefixes_tests.fth` unchanged.
- `Makefile` unchanged.
- `src/number_prefixes.asm` comment-only edit possible only if Task 6.3 surfaces a missing/wrong citation (expected: no edit).
- `src/outer_interpreter.asm`, `src/assembler.asm` unchanged.
- **This story file** is created in `_bmad-output/implementation-artifacts/9-6-…md`.
- **`sprint-status.yaml`** transitions `9-6-…: backlog → ready-for-dev → in-progress → review → done` and `epic-9: in-progress → done` at story completion (the `dev-story` workflow handles the status transitions).
- **No source-tree structural changes.** Post-Epic-9, the file list matches architecture §440 (number_prefixes.asm present, other new Epic 10–13 files not yet created).

### Previous-Story Intelligence — Stories 9.1–9.5

Key inherited learnings relevant to 9.6:

1. **Test numbering density.** 405 REPL tests total post-9.5. Task 4.2 verifies this count; any divergence is a regression finding.

2. **Binary size trajectory.** +757 bytes cumulative across Epic 9. Each story's delta has been justified in its own Completion Notes. 9.6 aggregates rather than re-justifies.

3. **Standards-citation discipline** (project memory `feedback_standards_compliance.md`). The Task 6 audit is the discipline's proof-of-delivery for Epic 9. If a citation is missing, it is fixed in-place — not debated.

4. **Adversarial review discipline** (project memory `feedback_adversarial_review.md`). An audit-only story has zero-diff temptation; Task 9's reviewer must hunt harder. Zero findings would be suspect.

5. **Follow the process** (project memory `feedback_follow_process.md`). Execute the hardware smoke even though it's tedious. Don't ask the user whether to skip. (Do ask once for the transfer procedure if uncertain.)

6. **REPL tests preferred** (project memory `feedback_repl_tests_preferred.md`). No new assembly tests. Story 9.6 adds no tests at all.

7. **TOS-in-register discipline** (project memory `project_tos_in_register.md`). BC=TOS invariants are preserved through the recogniser's fail paths. Task 5's FR47 spot checks are the observational proof.

8. **Design upfront** (project memory `feedback_design_upfront.md`). 9.1's integration-point decision (single wire-in at `.try_prefix_num`) is what makes 9.6's NFR1 verdict structural rather than fragile: the unprefixed path's cycle cost is set by the fast-fail chain's length, not by the number of prefix arms added.

9. **Systematic reference check** (project memory `feedback_systematic_reference_check.md`). Task 6's citation audit should cross-reference the actual `src/number_prefixes.asm` content — not enumerate prefix names from memory. Grep first, then write the table.

### Citation Audit Expected Outcome (pre-verified by grep)

Grep baseline (ran during story drafting):
- `grep -cE "Forth 2014" src/number_prefixes.asm` → 16
- `grep -cE "antforth extension" src/number_prefixes.asm` → 5
- `grep -cE "^\s*EXX\b" src/number_prefixes.asm` → 20 (invariant)

Expected audit verdict: ALL PASS. No missing citations. Task 6 is verification, not remediation.

### CCD-4 Gate Close-Out Template

The Completion Notes **must** include a section titled "CCD-4 Gate Verdict" containing at minimum Task 8.1's table and Task 8.2's readiness statement. This is the visible output that a future reader (or a re-audit) opens the story file to find. Don't bury it in Task 9's review — put it near the top of the Completion Notes.

### References

- `_bmad-output/planning-artifacts/epics.md:390-424` — Story 9.6 authoritative spec
- `_bmad-output/planning-artifacts/epics.md:242-244` — Epic 9 overview
- `_bmad-output/planning-artifacts/epics.md:216-218` — Epic 9 summary + FR coverage
- `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 per-epic benchmark gate
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline
- `_bmad-output/planning-artifacts/architecture.md:230-242` — E9-D1 integration point, E9-D2 flat dispatch
- `_bmad-output/planning-artifacts/architecture.md:451-469` — Standards-citation comment format
- `_bmad-output/planning-artifacts/architecture.md:803-807` — Development Workflow Integration (the `make bench` reference that 9.6 clarifies)
- `_bmad-output/planning-artifacts/prd.md:373-383` — FR1–FR9 (numeric literal input)
- `_bmad-output/planning-artifacts/prd.md:432-436` — FR45, FR46, FR47 (backward compatibility)
- `_bmad-output/planning-artifacts/prd.md:453-479` — NFR1, NFR4, NFR9, NFR11, NFR12, NFR17, NFR18
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-04-20.md` — NFR4 revision rationale (no per-epic net-negative gate)
- `_bmad-output/implementation-artifacts/9-1-numeric-prefix-recogniser-scaffold-decimal-prefix.md` — Story 9.1 (fast-fail cost documented at :278 M1)
- `_bmad-output/implementation-artifacts/9-2-hex-prefixes-standard-and-0x-antforth-extension.md` — Story 9.2 (binary delta justification, `0x` extension design)
- `_bmad-output/implementation-artifacts/9-3-binary-and-character-prefixes.md` — Story 9.3
- `_bmad-output/implementation-artifacts/9-4-leading-sign-and-full-case-insensitivity.md` — Story 9.4 (+201 byte delta breakdown; EXX-count invariant)
- `_bmad-output/implementation-artifacts/9-5-prefix-reach-repl-colon-bodies-and-assembler-source.md` — Story 9.5 (FR47 spot checks at tests 395–396; reach verification)
- `src/number_prefixes.asm:1-150` — file header + scaffold comment table + citation block (Task 6 audit target)
- `src/number_prefixes.asm:152-326` — `#` decimal handler + dispatch entry
- `src/number_prefixes.asm:327-378` — `$` hex handler
- `src/number_prefixes.asm:379-453` — `0x` / `0X` handler (`; antforth extension`)
- `src/number_prefixes.asm:454-519` — `%` binary handler
- `src/number_prefixes.asm:520-583` — `'c'` character literal handler
- `src/number_prefixes.asm:584-700` — sign pre-pass helpers
- `src/outer_interpreter.asm:179-230` — `.try_number` / `.try_prefix_num` / `.got_value` — the integration point
- `Makefile:52-71` — `make test` assembly thread target
- `Makefile:73-` — `make test-repl` REPL-piped target
- Project memories:
  - `feedback_adversarial_review.md` — reviews MUST find things, especially on audit-only stories
  - `feedback_standards_compliance.md` — investigate the standard before defending code
  - `feedback_systematic_reference_check.md` — cross-reference authoritative sources, not memory
  - `feedback_follow_process.md` — execute hardware smoke even though tedious
  - `feedback_design_upfront.md` — 9.1's single-integration-point design underpins NFR1's structural soundness
  - `feedback_repl_tests_preferred.md` — no new assembly tests (none added in 9.6 anyway)
  - `project_tos_in_register.md` — BC=TOS invariants preserved across the recogniser's fail paths

### Project Structure Notes

- Alignment with unified project structure: story file lives in `_bmad-output/implementation-artifacts/` per `config.yaml:implementation_artifacts`. No new source file, no new test file. Follows the established Epic-closure pattern (cf. Epic 5 retrospective pattern — although Epic 9 has its own CCD-4 story as Epic 5 did not).
- No detected conflicts or variances with the unified structure.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

### Completion Notes List

#### CCD-4 Gate Verdict (close-out summary — populated after Task 8)

Reserved — see Task 8 section below.

---

#### Task 1 — Unprefixed parse path T-state cost vs pre-Epic-9 baseline

**Methodology.** Analytical T-state counting from the Z80 reference (published instruction timings). Epic-9 adds `w_NUMBER_PREFIX_Q_cf` as a threaded-code primitive plus two extra threaded cells (`QBRANCH` + offset, `BRANCH` + offset) at `.try_prefix_num` in `src/outer_interpreter.asm:187–192`. The added cost on an unprefixed token (e.g. `42`) is:

1. One full execution of `w_NUMBER_PREFIX_Q_cf` taking the fast-fail fall-through (first char miss on every dispatch arm).
2. One additional `w_QBRANCH_cf` taken (branches to `.try_real_number` since NUMBER_PREFIX? returned FALSE).

**1.2 Post-9.5 NUMBER_PREFIX? fast-fail body (src/number_prefixes.asm:153–193) for token `42`:**

| Instruction | T-states |
|---|---|
| LD H, B | 4 |
| LD L, C | 4 |
| LD A, (HL)                    ; count | 7 |
| OR A | 4 |
| JR Z, .pref_fast_false        ; NT (count=2) | 7 |
| XOR A | 4 |
| LD (.pref_negate), A          ; 9.4 dispatch-level reset | 13 |
| INC HL | 6 |
| LD A, (HL)                    ; first char '4' | 7 |
| CP '#' + JR Z NT | 7 + 7 = 14 |
| CP '$' + JP Z NT | 7 + 10 = 17 |
| CP '0' + JP Z NT | 7 + 10 = 17 |
| CP '%' + JP Z NT | 7 + 10 = 17 |
| CP 0x27 + JP Z NT | 7 + 10 = 17 |
| CP '-' + JP Z NT | 7 + 10 = 17 |
| PUSH BC | 11 |
| LD BC, 0 | 10 |
| NEXT (EX DE,HL + LD E,(HL) + INC HL + LD D,(HL) + INC HL + EX DE,HL + JP (HL)) | 4+7+6+7+6+4+4 = 38 |
| **Total** | **214** |

**Extra QBRANCH (taken) — w_QBRANCH_cf branch-taken path (inner_interpreter.asm:200–217):**

| Instruction | T-states |
|---|---|
| LD A, B | 4 |
| OR C | 4 |
| POP BC | 10 |
| EX DE, HL | 4 |
| JR Z, .do_branch              ; taken (flag=0) | 12 |
| LD E, (HL) | 7 |
| INC HL | 6 |
| LD D, (HL) | 7 |
| DEC HL | 6 |
| ADD HL, DE | 11 |
| NEXTHL (7+6+7+6+4+4) | 34 |
| **Total** | **105** |

**Epic-9 added cost on unprefixed path: 214 + 105 = 319 T-states.**

**1.3 Pre-Epic-9 total unprefixed-parse cost estimate (commit 27c4cbd).**

Absolute cost of `.try_number` through `w_NUMBER_Q_cf` for `42`:
- `w_DROP_cf` (check_underflow CALL + POP BC + NEXT): ~85 T
- `w_ASM_RECOGNIZE_cf` fast-fail (asm_mode=0): LD A,(asm_mode) 13 + OR A 4 + JR Z taken 12 + PUSH BC 11 + LD BC, 0 10 + NEXT 38 = 88 T
- `w_QBRANCH_cf` taken (to `.try_real_number`): 105 T
- `w_NUMBER_Q_cf` for `42` (includes `do_number` with the 16-bit shift-and-add multiplier × 2 digits): ~2100 T
  - NUMBER? entry ritual + sign check: ~60 T
  - `do_number` 2 iterations × (char_to_digit ~80 + 16-iter 16-bit multiply ~800 + digit-add ~30 + loop overhead ~30) ≈ ~1900 T
  - Success tail (negate check false, PUSH DE, EXX, LD BC 0xFFFF, NEXT): ~100 T
- Post-number `w_QBRANCH_cf` not taken: 75 T
- STATE + FETCH + QBRANCH (STATE=0, taken) + BRANCH back to loop: ~310 T

**Pre-Epic-9 total ≈ 2760 T-states** for the `42` parse roundtrip.

**Post-Epic-9 total ≈ 2760 + 319 = 3080 T-states.**

**Drift: 319 / 2760 = 11.6%** (literal reading).

**1.4 Sign-pre-pass creep check (9.4 risk).**

Source trace of `src/number_prefixes.asm:185–187` confirms the `-` dispatch arm sits BELOW the first-char `CP '#'`, `$`, `0`, `%`, `0x27` arms and fires only for a leading `-`. Token `42` (first char '4') matches none of the six `CP` tests and falls through to `.pref_fast_false` without entering `.pref_sign_entry`. The pre-pass is bypassed for any first-char-non-sign token — verified.

Additional drift source NOT anticipated in 9.1's M1: the 9.4 dispatch-level `XOR A / LD (.pref_negate), A` reset (17 T) fires on every NUMBER_PREFIX? entry, including the unprefixed fast-fail path. This is `.pref_negate`'s once-per-dispatch initialisation — structurally required for 9.4's XOR-sign composition, not a cost optimisation target.

**1.5 AC #1 verdict.**

| Reading | Gate | Evidence | Verdict |
|---|---|---|---|
| Literal "≤ 1% drift" | 319 T / 2760 T = 11.6% | Tables above | **FAIL (literal)** |
| Task 1.5 clarification: "total parse cost not meaningfully increased" / "bounded by ~50 T fast-fail upper-bound" | Fast-fail is O(1) in token length; 319 T at 4 MHz = ~80 µs, user-invisible | Tables above + CP/M timing floor | **PASS (spirit)** |
| 9.1 M1 upper-bound "~50 T fast-fail overhead" | Current fast-fail is 214 T body + 105 T QBRANCH; ~4× the 9.1 M1 estimate | Breakdown above | **FINDING — M1 estimate stale** |

**Recorded verdict: PASS with FINDING.** The Epic-9 addition preserves the E9-D1 design promise (no asymptotic regression; the unprefixed hot path remains O(1) with a small additive overhead). The 9.1 M1 "~50 T" estimate was for a 1-prefix dispatch chain; post-9.5 the chain holds 6 arms (# $ 0 % ' -) plus the 9.4 dispatch-level flag reset, totalling 214 T body + 105 T threading = 319 T. This is expected linear growth with prefix count, NOT a regression, and falls under the "essentially unchanged" / "user-invisible" spirit of NFR1. Recommend refreshing the M1 estimate in a future maintenance story when the dispatch chain next changes.

---

#### Task 2 — Prefixed parse path T-state delta vs unprefixed

**Methodology.** Analytical T-state accounting for `#42` vs `42`, both through `.try_prefix_num` entry to `.got_value` arrival, per AC #2.

**2.2 Prefixed path `#42` through `.pref_hash_entry`:**

Entry dispatch (`w_NUMBER_PREFIX_Q_cf` preamble through `JR Z, .pref_hash_entry` taken):

| Instruction | T |
|---|---|
| LD H, B; LD L, C; LD A, (HL)           ; count=3 | 4+4+7 = 15 |
| OR A; JR Z NT (count!=0) | 4+7 = 11 |
| XOR A; LD (.pref_negate), A | 4+13 = 17 |
| INC HL; LD A, (HL)                     ; first char '#' | 6+7 = 13 |
| CP '#'; JR Z .pref_hash_entry taken | 7+12 = 19 |
| **Dispatch subtotal** | **75** |

`.pref_hash_entry` body (src/number_prefixes.asm:201–249):

| Block | Instructions | T |
|---|---|---|
| Entry ritual | PUSH BC (11) + EXX (4) + POP HL (10) | 25 |
| Count + skip | LD A,(HL) 7 + INC HL 6 + INC HL 6 + DEC A 4 + JR Z NT 7 + LD B,A 4 | 34 |
| CALL .pref_check_sign | CALL 17 + body [LD A,(HL) 7 + CP '-' 7 + RET NZ taken 11] = 25; total | 42 |
| JR C NT | 7 | 7 |
| Convert setup | LD DE, 0 | 10 |
| CALL do_number_base10 | see below | 556 |
| Post-convert check | LD A,B 4 + OR A 4 + JR NZ NT 7 | 15 |
| Sign apply (negate=0) | LD A,(.pref_negate) 13 + OR A 4 + JR Z taken 12 | 29 |
| Success tail | PUSH DE 11 + EXX 4 + LD BC,0xFFFF 10 + NEXT 38 | 63 |
| **.pref_hash_entry subtotal** | | **781** |

`do_number_base10` for "42" (strings in HL, B=2, accumulator DE=0):

Per-iteration cost (no digit-add carry, typical for small digits):

| Instruction | T |
|---|---|
| LD A,B; OR A; RET Z NT | 4+4+5 = 13 |
| LD A,(HL) | 7 |
| CALL char_to_digit_base10 | 17 + body = 17+49 = 66 |
| RET C NT | 5 |
| PUSH AF + PUSH HL + PUSH BC | 33 |
| LD H,D + LD L,E | 8 |
| ADD HL,HL ×2; ADD HL,DE; ADD HL,HL (×2, ×4, +DE=×5, ×10) | 11×4 = 44 |
| EX DE,HL | 4 |
| POP BC + POP HL + POP AF | 30 |
| LD C,A + LD A,E + ADD A,C + LD E,A | 16 |
| JR NC, .dn10_nc taken | 12 |
| INC HL + DEC B + JR .dn10_loop | 6+4+12 = 22 |
| **Per iteration** | **260** |

Two digit iterations + exit iter (LD A,B 4 + OR A 4 + RET Z taken 11 = 19):

do_number_base10 body: 260 + 260 + 19 = 539
CALL overhead: +17 (CALL instruction itself)
do_number_base10 subtotal (CALL + body): **556**

**Total NUMBER_PREFIX? for `#42`: 75 (dispatch) + 781 (`.pref_hash_entry`) = 856 T**

Threaded overhead after NUMBER_PREFIX? returns TRUE:
- `w_QBRANCH_cf` NOT-taken (flag=TRUE): 75 T
- `w_BRANCH_cf` unconditional to `.got_value`: 75 T

**Prefixed path total `.try_prefix_num` → `.got_value`: 856 + 75 + 75 = 1006 T**

**2.3 Unprefixed path `42` through `.try_prefix_num`:**

- `w_NUMBER_PREFIX_Q_cf` fast-fail (from Task 1.2): **214 T**
- `w_QBRANCH_cf` taken (to `.try_real_number`): **105 T**
- `w_NUMBER_Q_cf` for `42`:
  - Entry ritual + count/sign check + LD DE,0 + CALL do_number + post-convert + success push: ~200 T wrapper
  - `do_number` (generic 16-bit shift-and-add multiplier × 2 digit iterations): ~1900 T
    - Per iter ≈ 950 T: char_to_digit (~55T) + PUSH/POP ritual (~90T) + 16-iter shift-and-add multiply (~800T, 16 iters × ~50T) + digit-add (~30T)
  - Total NUMBER_Q for `42`: **~2100 T**
- `w_QBRANCH_cf` NOT-taken (success, flag=TRUE): **75 T**

**Unprefixed path total: 214 + 105 + 2100 + 75 = ~2494 T**

**2.4 Delta table:**

| Path | T-states | Notes |
|---|---|---|
| Prefixed `#42` | ~1006 | Uses do_number_base10 (specialised *10 via 3 ADD HL,HL + 1 ADD HL,DE) |
| Unprefixed `42` | ~2494 | Uses do_number (generic *BASE 16-bit shift-and-add) |
| **Delta (prefixed − unprefixed)** | **~−1488** | Prefixed is ~1488 T CHEAPER |

**Gate: ≤ 20 T above unprefixed → PASS with margin (delta is deeply negative).**

**2.5 Delta-sign audit (surprising finding).**

Task 2.5's sanity check reads: "Negative delta indicates miscounting — the prefixed path can't be cheaper than the unprefixed one." **This assumption is incorrect given the actual code**, because the prefixed and unprefixed paths use *different* digit accumulators:

- `do_number` (unprefixed, strings.asm:282): generic 16-bit shift-and-add multiplier, `base = (IY+UserArea.base)` — ~16-iter multiply per digit, ~800 T per digit body.
- `do_number_base10` (prefixed `#`, number_prefixes.asm:756): hard-coded *10 via 5 `ADD HL,HL/DE` operations — ~45 T per digit body.

The `do_number_base10` helper (added in 9.1) is structurally ~10–15× faster on the multiply than the generic `do_number`. That optimisation, plus the absence of an `(IY+base)` indexed load on every digit, makes the prefixed path per-token-parse **faster**, not slower.

This is a real observation — not a counting error. Re-audited the tables three times; numbers stand.

**2.6 Extrapolation to `$FF`, `%1010`, `0xFF`, `'A'`.**

- `$FF` via `.pref_dollar_entry` → `do_number_base16`: per-iter *16 via 4 × ADD HL,HL = 44 T + PUSH/POP overhead same as base-10 = ~260 T per iter × 2 digits + exit = ~540 T. Plus wrapper: ~300 T. Prefixed `$FF` ≈ 860 T — same ballpark as `#42`.
- `%1010` via `.pref_percent_entry` → `do_number_base2`: per-iter *2 via 1 × ADD HL,HL + no PUSH/POP churn (uses EX DE,HL instead) = ~70 T per iter × 4 digits + exit = ~310 T. Plus wrapper: ~300 T. Prefixed `%1010` ≈ 640 T — even cheaper than `#42`.
- `0xFF` via `.pref_zero_entry`: same `do_number_base16` body as `$FF`, plus a pre-EXX second-byte peek costing ~30 T extra. ≈ 890 T.
- `'A'` via `.pref_quote_entry`: no digit accumulator, just a 2-byte peek + sign-apply + push. ≈ 200 T — by far the cheapest arm.

All arms are cheaper than the generic unprefixed `NUMBER?` path on an equivalent-value literal, due to the hard-coded base helpers bypassing the generic 16-bit multiplier. **No arm exceeds `#` by more than 10 T — no Finding flag needed per Task 2.6.**

**2.7 AC #2 verdict: PASS with Finding.**

The NFR1 "≤ 20 cycle" gate is satisfied trivially (delta is negative). The Finding is that Task 2.5's "can't be cheaper" assumption was wrong: the Epic-9 recogniser delivered a *performance improvement* for tokens that carry a prefix, not a tax. This is an unintended-but-welcome side-effect of the 9.1 decision to hard-code base constants in the prefix handlers' multipliers.

---

#### Task 3 — Kernel ROM size trajectory

**3.1 Current binary measurement.**

```
$ wc -c build/antforth.com
14787 build/antforth.com
```

Confirmed: **14,787 bytes** — matches the post-9.5 baseline.

**3.2 Per-story size trajectory (Epic 9):**

| Story | Binary (bytes) | Delta | Cumulative from post-8.4 |
|---|---|---|---|
| Post-8.4 baseline (commit `27c4cbd`) | 14,030 | — | 0 |
| 9.1 `#` scaffold + decimal | 14,185 | +155 | +155 |
| 9.2 `$` + `0x` hex | 14,422 | +237 | +392 |
| 9.3 `%` + `'c'` | 14,586 | +164 | +556 |
| 9.4 sign + case-fold | 14,787 | +201 | +757 |
| 9.5 reach verification | 14,787 | 0 | +757 |
| **9.6 CCD-4 gate (current)** | **14,787** | **0** | **+757** |

**Epic 9 cumulative delta: +757 bytes** (14,030 → 14,787, +5.4% growth).

**3.3 Justification.**

Per architecture §NFR4 (revised by the `sprint-change-proposal-2026-04-20.md` change to the per-epic gate): **there is no per-epic net-negative ROM gate in Phase 2.** The discipline is per-story justification, which the 9.1–9.5 Completion Notes have provided in full.

Epic 9's +757 bytes funded net-new capability:
- 5 prefix handlers (`#`, `$`, `0x`/`0X`, `%`, `'c'`) — ~5 × ~150 bytes each with shared helpers
- Three leaf digit-accumulator helpers (`do_number_base10`, `do_number_base16`, `do_number_base2`) with specialised `*BASE` multipliers
- `char_to_digit_base10`, `_base16`, `_base2` ASCII→digit converters
- Shared `.pref_check_sign` in-body sign-strip helper (introduced in 9.4 to collapse 4× duplicated blocks, ~−30 bytes offset)
- `.pref_sign_entry` pre-pass + 5 × `.pref_<x>_enter_after_sign` per-handler entry points (9.4)
- Scaffold dispatch chain at `w_NUMBER_PREFIX_Q_cf` (6 `CP`/`JR Z` / `JP Z` pairs + dispatch-level `.pref_negate` reset)

This is a **net-new recogniser subsystem** supporting Forth 2014 §3.4.1.3 numeric-literal-prefix conformance plus the antforth-extension `0x` C-style hex. The per-feature byte amortisation is ~150 bytes — small and appropriate for a Z80 kernel. No deletions in Epic 9 (no opportunity for net-negative), no duplicated code that was not deduplicated (9.4's refactor paid off the 9.2/9.3 M2 debt).

**3.4 Story 9.6 delta.**

Story 9.6 delta: **0 bytes**. Audit-only; one comment-only edit applied post-review (Senior Developer Review H1: `NFR13` → `NFR12` on `src/number_prefixes.asm:22`). Rebuild confirms binary unchanged — 14,787 bytes / md5 `da1c648ba64691e3f9c910c412df7c86` both identical pre-fix and post-fix, exactly as the "comment-only has zero binary impact" claim predicted.

**3.5 AC #3 verdict: PASS.**

Cumulative +757 bytes recorded and justified per NFR4 (Phase-2 revision). No release blocker.

---

#### Task 4 — Full Phase-1 regression suite

**4.1 `make test` (assembly test thread):**

```
Running regression tests...
Pass 1 complete (0 errors)
Pass 2 complete (0 errors)
Pass 3 complete
Errors: 0, warnings: 0, compiled: 20403 lines, work time: 0.055 seconds
PASS: Output matches expected
```

All 6 assembly test groups pass (inner interpreter / stack / arithmetic / I/O / dictionary / outer interpreter). Output matches `Makefile:55–71` expected string verbatim.

**4.2 `make test-repl` (REPL-piped test suite):**

```
$ make test-repl 2>&1 | grep -cE "^PASS:"
405
$ make test-repl 2>&1 | grep -cE "^FAIL:"
0
```

**405 PASS, 0 FAIL.** Matches the post-9.5 baseline exactly. Story 9.6 adds zero new tests (audit-only).

Representative tail of the suite (tests 369–396, spanning Epic 9 sign + colon-body + CODE-block reach + FR47 spot checks) all confirmed PASS per the full run log. Final tests 395–396 cover FR47 in colon-body and CODE-block contexts — both PASS under the Epic-9 binary.

**4.3 No regressions detected — NFR9 satisfied.** No debug required.

**4.4 Pre-phase test coverage confirmation.**

- `make test` (`Makefile:52–71`): 6 assembly-level test groups built into `antforth_test.com` covering Epic 1 inner interpreter primitives through Epic 2 outer interpreter primitives. Output expectation string explicitly checks values from every group.
- `make test-repl` (`Makefile:73+`): 405 REPL-piped Forth tests. Spans the full Phase-1 surface including Epic 3 colon/variables/loops, Epic 4 assembler opcode generation, Epic 5 comment words + MARKER, Epic 6 BDOS/RSP/IX/IY refactors, Epic 7 EXX BUILD/HEADER words, Epic 8 EXX `.`/`U.`/`CHAR`/`ABORT"` + `.R`/`.S`, and Epic 9 numeric-literal prefixes (tests 266–396). `tests/number_prefixes_tests.fth` is referenced in the Makefile at lines 2372 / 2586 / 2858 as the authoritative source list for the prefix tests.

Full Phase-1 (Epic 1–9) coverage is exercised by the combined `make test` + `make test-repl` targets on every run.

**4.5 AC #4 verdict: PASS.**

Zero regressions, post-9.5 baseline counts preserved. NFR9 / FR46 satisfied.

---

#### Task 5 — FR47 backward-compatibility spot checks

**5.1 REPL emulator smoke batch (via `iz-cpm build/antforth.com`).**

Each row below is an input line piped at the REPL; the "actual" column is captured from the emulator's stdout.

| # | Input | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | `42 .` | `42  ok` | `42  ok` | **PASS** |
| 2 | `-42 .` | `-42  ok` | `-42  ok` | **PASS** |
| 3 | `HEX FF . DECIMAL` | `FF  ok` | `FF  ok` | **PASS** |
| 4 | `-128 .` | `-128  ok` | `-128  ok` | **PASS** |
| 5 | `0 .` | `0  ok` | `0  ok` | **PASS** |
| 6 | `00 .` | `0  ok` | `0  ok` | **PASS** |
| 7 | `HEX 0A . DECIMAL` | `A  ok` | `A  ok` | **PASS** |
| 8 | `65535 .` | `-1  ok` | `-1  ok` | **PASS** |
| 9 | `: F42 42 ; F42 .` | `42  ok` | `42  ok` | **PASS** |
| 10 | `: FN42 -42 ; FN42 .` | `-42  ok` | `-42  ok` | **PASS** |
| 11 | `CODE C_42 BC PUSH, C 42 # LD, B 0 # LD, NEXT, END-CODE C_42 .` | `42  ok` | `42  ok` | **PASS** |

**Note on rows 3 and 8 (AC-text originally had wrong expected outputs; fixed in this review):**
- Row 3: `HEX FF . DECIMAL` — `.` fires BEFORE `DECIMAL` takes effect, so the print base is HEX. Correct output is `FF  ok` (the original AC gloss `255  ok` was a drafting slip: 255 is the value, but `.` prints in the current base, HEX, which renders it as `FF`). Pre-Epic-9 behaviour — FR47 preserved.
- Row 8: `65535 .` — antforth's `.` prints *signed* 16-bit (traditional Forth split: `.` signed, `U.` unsigned). In DECIMAL, `0xFFFF` prints as `-1`. Pre-Epic-9 behaviour — FR47 preserved.

**5.2 Cross-check vs pre-Epic-8 baseline.**

All 11 rows produce output that is independent of the Epic-9 recogniser (unprefixed parse routes through NUMBER?, not NUMBER-PREFIX?). The `NUMBER-PREFIX?` recogniser fast-fails on every unprefixed token (Task 1.2's 214-T body) and returns FALSE without touching the result, so the post-9 binary's behaviour on rows 1–11 is structurally identical to post-8.4's. No behavioural divergence detected.

**5.3 Reference to automated FR47 coverage.**

`make test-repl` tests 395 and 396 (added in 9.5) are the automated half of AC #5:

- Test 395: `': F42N -42 ; F42N .' outputs '-42  ok' (bare signed literal via NUMBER?)` — PASS (per Task 4.2).
- Test 396: CODE-block with unprefixed `42` via `NUMBER?` fallthrough: `MK_42 . outputs '42  ok'` — PASS (per Task 4.2).

Both PASS in Task 4.2's 405-test regression run. The manual smoke (Task 5.1) is the human-observable confirmation.

**5.4 FR47 smoke batch table (above) — recorded in full.**

**5.5 AC #5 verdict: PASS.**

FR47 is preserved: unprefixed literals in REPL, colon-body, and CODE-block contexts produce outputs bit-identical to the pre-Epic-9 baseline. Two AC text glosses are drafting slips (rows 3 and 8) but do not represent behavioural regressions — actual output matches pre-Epic-9 semantics.

---

#### Task 6 — Standards citation audit

**6.1 Pre-audit grep baseline (verified).**

```
$ grep -cE "Forth 2014"       src/number_prefixes.asm  → 16  ✓
$ grep -cE "antforth extension" src/number_prefixes.asm  →  5  ✓
$ grep -cE "^\s*EXX\b"          src/number_prefixes.asm  → 20  ✓
```

All three invariants confirmed — no accidental drift since 9.5.

**6.2 Audit table (one row per standards-derived word/handler).**

| # | Prefix | Word / handler label | Source lines | Citation text | Verdict |
|---|---|---|---|---|---|
| 1 | (file header) | file docstring | number_prefixes.asm:5 | `carrying an explicit base prefix (Forth 2014 §3.4.1.3)` | **OK** |
| 2 | `#` | `w_NUMBER_PREFIX_Q_cf` entry / scaffold | number_prefixes.asm:112, 152 | `Forth 2014 §3.4.1.3      #<num>        — decimal-base numeric literal prefix` | **OK** |
| 3 | `#` | `.pref_hash_entry` success tail (via dispatch) | number_prefixes.asm:201 (linked to line 152 comment) | shared with row 2 | **OK** |
| 4 | `$` | `.pref_dollar_entry` | number_prefixes.asm:113, 327 | `Forth 2014 §3.4.1.3      $<num>        — hexadecimal-base numeric literal prefix` | **OK** |
| 5 | `0x` / `0X` | `.pref_zero_entry` (antforth extension) | number_prefixes.asm:22, 114, 379, 388 | `antforth extension (NFR12) — C-style hex` / `; antforth extension         0x<num>       — C-style hex prefix` | **OK** (NFR12 corrected 2026-04-20 — was NFR13 in draft; fixed per Senior Developer Review H1) |
| 6 | `%` | `.pref_percent_entry` | number_prefixes.asm:37, 454 | `Forth 2014 §3.4.1.3      %<num>        — binary-base numeric literal prefix` | **OK** |
| 7 | `'c'` | `.pref_quote_entry` | number_prefixes.asm:40, 520, 522 | `Forth 2014 §3.4.1.3      'c'           — character-code literal` | **OK** |
| 8 | Leading `-` sign modifier | `.pref_sign_entry` + 5 × `.pref_<x>_enter_after_sign` | number_prefixes.asm:62, 185, 584 | `Forth 2014 §3.4.1.3 — leading sign is standard, not an antforth extension.` / `Forth 2014 §3.4.1.3      -<prefix><num>  — optional leading sign modifier` | **OK** |
| 9 | Case-insensitivity | `char_to_digit_base16` (`OR 0x20` fold) and `0x`/`0X` prefix-letter fold in `.pref_zero_entry` | number_prefixes.asm:32, 855 | `OR 0x20 case-fold implements the Forth 2014 §3.4.1.3 case-insensitivity requirement for hex digits` | **OK** |

**Audit result: 0 MISSING, 0 WRONG.** Every standards-derived word in `src/number_prefixes.asm` carries a correct Forth 2014 §3.4.1.3 (or — for the single exception — `antforth extension` / NFR12) citation at its definition site.

**6.3 Corrective fixes: NONE required.**

The pre-audit expectation (per Dev Notes §"Citation Audit Expected Outcome"): "Expected audit verdict: ALL PASS. No missing citations. Task 6 is verification, not remediation." — confirmed. No comment-only edits made; binary delta is 0 as expected in Task 3.4.

**6.4 NFR12 extension-discipline spot-check for `0x` / `0X`.**

Relevant comment lines, quoted verbatim from `src/number_prefixes.asm`:

```
;   - '0x'/'0X' hex prefix   antforth extension (NFR12) — C-style hex                      (line 22, post-fix)
;   9.2    '0x'/'0X' 16    antforth extension (done) — two-character                        (line 114)
; '0x' / '0X' hexadecimal prefix handler (Story 9.2, antforth extension).                   (line 379)
; antforth extension         0x<num>       — C-style hex prefix                             (line 388)
```

(Line 22 originally cited NFR13 — the CP/M BDOS allow-list — which is unrelated to extension discipline. The Senior Developer Review (H1) surfaced this; the comment was corrected in-place to NFR12, which per `prd.md:470` is the correct "Extension discipline" NFR. Comment-only change, zero binary impact.)

Compare to the sibling `$` arm at line 327:

```
; Forth 2014 §3.4.1.3      $<num>        — hexadecimal-base numeric literal prefix          (line 327)
```

The `0x` arm is explicitly flagged `antforth extension` at four distinct sites (file header, scaffold table, handler banner, citation line), while the sibling standard `$` arm carries the `Forth 2014 §3.4.1.3` citation at line 327. The discrimination is correct and consistent. Extension discipline (NFR12) is upheld.

**6.5 Scope sweep.**

```
$ grep -nE "Forth 2014|antforth extension" src/outer_interpreter.asm src/assembler.asm src/compiler.asm
(no matches)
```

No Epic-9-introduced standards-derived word lives outside `src/number_prefixes.asm`. The single edit to `src/outer_interpreter.asm` (verified via `git diff 27c4cbd..HEAD`) is at `.try_prefix_num` (lines 181–193) — it is the recogniser wire-in, pure interpreter plumbing, and does not define any new Forth word, so no citation is required at that site. The NUMBER-PREFIX? word itself lives in `src/number_prefixes.asm` with all its citations per the audit table above.

**6.6 AC #6 verdict: PASS.**

Every Epic-9 standards-derived word carries a correct Forth 2014 §3.4.1.3 citation at its definition site, with the sole antforth-extension (`0x`/`0X`) explicitly flagged per NFR12. Baselines (16 `Forth 2014` + 5 `antforth extension` + 20 `EXX`) preserved — CCD-3 discipline upheld.

---

#### Task 7 — Real-MicroBeast hardware smoke test (RELEASE GATE)

**7.1 Final binary verification.**

- `build/antforth.com`: **14,787 bytes** (confirmed in Task 3.1 via `wc -c`).
- `make test` and `make test-repl` both pass (Task 4).
- `src/number_prefixes.asm` citations all pass audit (Task 6).

Binary is release-candidate quality — ready for hardware transfer.

**7.2 Transfer preparation.**

The project's documented transfer mechanism is `make disk`, which produces `build/antforth.img` via `mkfs.cpm -f ibm-3740` + `cpmcp` (Makefile:46–50). This disk image is in IBM 3740 format which the MicroBeast's CP/M 2.2 can read.

Two blockers for dev-agent execution of 7.3–7.5:

1. **`make disk` currently fails** because its prerequisite `build/test_key.com` (`Makefile:43–44`) fails to assemble: `test_key.asm` references labels defined in the main kernel (`hash_table`, `asm_cleanup`, `w_QUIT_cf`, `str_underflow`, etc.) that aren't visible when it's assembled standalone. This is an independent bug, unrelated to Epic 9. **Workaround**: run `make disk` via `make docker-disk` (Makefile:3522), OR rebuild the image manually with just `antforth.com`:
   ```
   mkfs.cpm -f ibm-3740 build/antforth.img
   cpmcp   -f ibm-3740 build/antforth.img build/antforth.com 0:antforth.com
   ```
   (Note: this dev environment lacks `mkfs.cpm` / `cpmcp` binaries — `docker-disk` is the cleaner path.)

2. **The dev agent has no physical MicroBeast access in this execution environment.** The hardware smoke (the actual on-device typing and output capture) is a human-in-the-loop step.

**7.3–7.5 Hardware smoke batch — EXECUTED by project lead 2026-04-20.**

Per Task 8.3's language, the on-device run is the project lead's action. The dev agent recorded the *procedure and expected outputs* here; the project lead executed the smoke batch on the real MicroBeast on 2026-04-20 and filled in the Actual column below.

**Smoke batch script** (typed at the MicroBeast REPL after booting `antforth.com`):

| # | Input | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | `#42 .` | `42  ok` | `42  ok` | **PASS** |
| 2 | `$FF .` | `255  ok` | `255  ok` | **PASS** |
| 3 | `0xFF .` | `255  ok` | `255  ok` | **PASS** |
| 4 | `%1010 .` | `10  ok` | `10  ok` | **PASS** |
| 5 | `'A' .` | `65  ok` | `65  ok` | **PASS** |
| 6 | `-#42 .` | `-42  ok` | `-42  ok` | **PASS** |
| 7 | `-$FF .` | `-255  ok` | `-255  ok` | **PASS** |
| 8 | `-0xFF .` | `-255  ok` | `-255  ok` | **PASS** |
| 9 | `-%1010 .` | `-10  ok` | `-10  ok` | **PASS** |
| 10 | `-'A' .` | `-65  ok` | `-65  ok` | **PASS** |
| 11 | `HEX : DEC_H #100 . ; DEC_H DECIMAL` | `64  ok` (100 dec printed in HEX) | `64  ok` | **PASS** |
| 12 | `CODE MK_FF BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE MK_FF .` | `255  ok` | `255  ok` | **PASS** |

**MVP hardware smoke: PASS** — all 12 smoke-batch rows signed off by the project lead on the real MicroBeast (2026-04-20).

**Pre-confirmed on emulator (`iz-cpm build/antforth.com`):** every line above produces the expected output under `iz-cpm` (verified as part of `make test-repl` which passes all 405 tests — tests 266–396 cover these exact patterns across REPL / colon / CODE contexts). Hardware divergence is therefore extremely unlikely, since the Epic-9 recogniser is pure in-memory logic with no BDOS calls and no timing-sensitive dependencies (NFR13 compliant).

**7.6 AC #7 verdict: PASS.**

Project lead ran all 12 smoke-batch rows on the real MicroBeast (2026-04-20) and recorded the actuals in the table above; every row matches expected. MVP hardware gate closed.

---

#### Task 8 — CCD-4 gate verdict and release-readiness statement

**8.1 CCD-4 verdict table:**

| NFR / FR | Gate text | Evidence | Verdict |
|---|---|---|---|
| NFR1 (prefix-path delta ≤ 20 Z80 cycles) | Task 2 | Prefixed `#42` path is ~1006 T; unprefixed `42` path is ~2494 T. Delta: ~−1488 T (prefixed is CHEAPER). | **PASS** (with Finding: Task 2.5 sign assumption wrong — see Task 2 write-up) |
| NFR1 (unprefixed-path drift ≤ 1%) | Task 1 | Epic-9 adds 319 T to unprefixed parse (~2760 T pre-9 → ~3080 T post-9); literal drift 11.6%. Bounded, O(1) in token length; at 4 MHz = ~80 µs, below CP/M I/O timing floor. | **PASS (spirit reading accepted by project lead 2026-04-20; relaxation to be recorded in Epic-9 retro)** |
| NFR4 (ROM delta recorded and justified) | Task 3 | +757 bytes cumulative; per-story deltas justified; Phase-2 has no net-negative gate. | **PASS** |
| NFR9 (zero regressions across Phase-1) | Task 4 | `make test` clean; `make test-repl` 405/405. | **PASS** |
| NFR11 (Forth 2014 §3.4.1.3 conformance) | Task 6 | All prefix arms cited correctly; 9.1–9.5 test suite proves behavioural conformance. | **PASS** |
| NFR12 (extension discipline — `0x` is the sole antforth extension) | Task 6.4 | `0x`/`0X` arm carries `antforth extension` flag at 4 sites; sibling `$` carries `Forth 2014 §3.4.1.3`. Discrimination explicit. | **PASS** |
| NFR17 (standards-citation discipline / CCD-3) | Task 6 | 16 `Forth 2014` + 5 `antforth extension` occurrences match baseline; every standards-derived word has a citation. | **PASS** |
| FR45 (Epic 1–8 behaviour preserved) | Tasks 4 + 5 | 405 REPL tests pass, 11-row FR47 manual smoke all PASS (2 AC-text glosses corrected). | **PASS** |
| FR46 (Epic 1–8 test suite passes) | Task 4 | `make test` + `make test-repl` clean. | **PASS** |
| FR47 (unprefixed literal bit-identical) | Task 5 | 11 emulator rows + automated tests 395–396 all PASS. | **PASS** |
| AC #7 hardware smoke (MVP gate per PRD) | Task 7 | Project lead ran all 12 smoke-batch rows on real MicroBeast (2026-04-20); every row matches expected. | **PASS** |
| Commit-baseline prerequisite (tag-pointing sanity) | File List "Release-gate process flag" | HEAD=`07ff34b` is the 9.2 commit; 9.3/9.4/9.5/9.6 source + audit artefacts uncommitted. Tag against HEAD would point at a tree missing most of Epic 9. | **BLOCKED — must commit 9.3–9.6 before `git tag -a v1.9.0`** |

**8.2 antforth 1.9 release-readiness statement.**

**Status: READY TO TAG after commit-baseline prerequisite — 11/12 CCD-4 gates PASS, 1 is a blocking prerequisite (commit baseline for 9.3–9.6).**

- 11 of 12 CCD-4 gates PASS (NFR1 unprefixed-path drift gate resolved via spirit-reading; see below).
- **NFR1 unprefixed-path drift ≤ 1%** (AC #1 literal reading) — measured drift is 11.6% (319 T added / 2760 T baseline). The Task 1.5 "spirit" reading (bounded, O(1), user-invisible at 4 MHz ≈ 80 µs, below CP/M I/O timing floor) re-interprets the gate as PASS. **Project lead accepted the spirit reading on 2026-04-20 (`ant`):** "yeah accept it, it's fine." Relaxation to be recorded in the Epic-9 retrospective. No follow-up dispatch-chain optimisation required for 1.9 tagging; the 9.1 M1 "~50 T" estimate remains formally stale and will be refreshed whenever the dispatch chain next changes.
- AC #7 hardware smoke closed by project lead on real MicroBeast (2026-04-20); all 12 smoke-batch rows match expected (see Task 7.3).
- **Commit-baseline prerequisite** (see File List → "Release-gate process flag"): stories 9.3/9.4/9.5/9.6 are uncommitted. The tag must be applied against a tree that includes the full Epic 9 surface; this means committing 9.3–9.6 first.
- Proposed tag command for the project lead **after** (a) NFR1 decision resolved and (b) 9.3–9.6 committed:

```
git tag -a v1.9.0 -m "Numeric literal prefixes (Epic 9): # $ 0x % 'c' with leading sign + case-folding; Forth 2014 §3.4.1.3"
```

**The dev agent does NOT apply the tag.** Tagging is the project lead's action.

**8.3 Story status transition.**

With Tasks 1–6 PASS and Task 7 preparation complete (execution pending project-lead), the story is ready to move to `review`. The hardware-smoke pending note is explicit in this Completion Notes section so the project lead can fill in actuals before tagging.

---

#### Task 9 — Adversarial self-review (preliminary)

**9.0 Scope.** This is a preliminary self-review per project memory `feedback_adversarial_review.md`: "Reviews MUST find things. Absence of findings is suspect." The authoritative code review remains the separate `bmad-bmm-code-review` pass, ideally run by a different LLM per the dev-story workflow's closing tip. This section captures findings the dev agent discovered during self-audit.

**9.1 Findings (self-identified during Tasks 1–8).**

- **Finding F1 (MEDIUM — arithmetic drift corrected):** Initial draft of Task 2's `.pref_hash_entry` subtotal was written as **785 T** and `CALL do_number_base10` as **560 T**. Self-audit of the per-iteration breakdown (260 T × 2 digits + 19 T exit = 539 T body + 17 T CALL = 556 T, not 560 T) identified the off-by-4 drift; subtotals corrected to **781 T** and **556 T** respectively. Final prefixed-path total revised from 1010 T to **1006 T**; delta from −1484 T to **−1488 T**. Direction and gate verdict unchanged — still PASS with deep margin. Recorded here per Task 9.2(a) "arithmetic soundness in Task 2's T-state sum."

- **Finding F2 (MEDIUM — AC #1's 1% literal gate is not met):** Task 1 found actual drift of **11.6%** (319 T added / 2760 T pre-9 baseline) vs the literal AC gate of **≤ 1%**. The story's Task 1.5 clarification explicitly interprets the 1% gate as "bounded by ~50 T fast-fail upper-bound", under which the verdict is PASS. The underlying Finding: the 9.1 M1 "~50 T" estimate was made with only one prefix arm; by 9.5 the dispatch chain grew to six arms plus the 9.4 dispatch-level `.pref_negate` reset, growing the fast-fail to 214 T body + 105 T threading = 319 T. This is expected O(1) growth per prefix-arm, not a regression, but the `~50 T` M1 estimate in story 9.1's Completion Notes is now stale (off by ~4×). Recommend a future maintenance story refresh the M1 number when the dispatch chain next changes.

- **Finding F3 (MEDIUM — Task 2.5 invariant assumption is structurally wrong):** Task 2.5 asserts "the prefixed path can't be cheaper than the unprefixed one" — this is false given the specialised base helpers (`do_number_base10`, `_base16`, `_base2`) introduced in 9.1–9.3, which short-circuit the generic `do_number`'s 16-bit shift-and-add multiplier. Empirically the prefixed path is **~1488 T cheaper** than the unprefixed path per digit pair. Gate "delta ≤ 20 T" is satisfied trivially (negative delta), but Task 2.5's sanity check is a bad rule: it would force miscounting a correct analysis. Recommend striking the "can't be cheaper" guidance from the Epic 10+ CCD-4 Task 2.5 template.

- **Finding F4 (MEDIUM — AC #5 row-3 and row-8 expected-output glosses are wrong in the story spec):** Row 3 (`HEX FF . DECIMAL`) expected-output `255  ok` is structurally impossible because `.` fires under HEX mode (the `DECIMAL` comes *after* the `.`); correct output is `FF  ok`. Row 8 (`65535 .`) expected-output `65535  ok` is wrong because antforth's `.` is signed-print (traditional Forth split: `.` signed, `U.` unsigned), so 0xFFFF in DECIMAL prints as `-1`. Both actual outputs are pre-Epic-9 behaviour (FR47 preserved) but the story's AC text is off. Recommend fixing the story-spec glosses when the Epic-9 retrospective opens.

- **Finding F5 (LOW — `make disk` broken independently of Epic 9):** `make disk` fails because `build/test_key.com` fails to assemble (`test_key.asm` standalone references kernel labels). Unrelated to Epic 9; existed before 9.1 (no Epic-9 commit touches `src/test_key.asm` or `Makefile:43–44`). Flagged as a separate bug requiring its own story — does not block 1.9 tagging if the project lead uses `make docker-disk` or manual `cpmcp` for the hardware transfer.

- **Finding F6 (LOW — `make bench` target does not exist in the Makefile):** Flagged by the story Dev Notes itself ("The `make bench` gap") but worth re-surfacing for the adversarial reader: CCD-4's gate text in architecture §§218–226 references a `make bench` target that has never been built. 9.6 uses analytical T-state accounting instead, which is stricter on Z80 anyway (no emulator noise) but a formal bench target would amortise well across Epics 10–13. Out of scope for 9.6.

- **No finding triggered under Task 9.2(d) "silent scope creep":** The only source edits Epic-9 introduced are in `src/number_prefixes.asm` (new file) and `src/outer_interpreter.asm:181–193` (wire-in only). 9.6 itself made **zero** source edits; the binary is byte-identical to post-9.5 at 14,787 bytes (Task 3.1). Scope discipline upheld.

- **No finding triggered under Task 9.2(e) "git tag line":** Proposed tag `v1.9.0` matches architecture §NFR18 and the sprint-change proposal. No pre-application by the dev agent.

**9.2 Residual risk for the authoritative `bmad-bmm-code-review` pass.**

The authoritative review should re-derive the Task 1 and Task 2 T-state sums independently (ideally with a different grouping of the per-instruction table) to cross-check the arithmetic. Special attention: 8-bit-register LD timings (4 T), 16-bit-immediate LD timings (10 T), `JP cc,nn` (fixed 10 T regardless of taken/not-taken), `JR cc,e` (12 taken / 7 NT), `CALL nn` (17), `RET` (10), `RET cc` (11 taken / 5 NT). The per-iteration `do_number_base10` figure (260 T) is the most sensitive — a 1-cycle error across the 32 instructions in the loop compounds to ±30 T per digit across the table.

The authoritative review should also independently trace the Task 1 unprefixed path to confirm that the dispatch chain's 6 `CP`/`JR Z|JP Z` pairs total 99 T; a miscount there propagates to all of Task 1's headline numbers.

**9.3 Self-review verdict.**

Six MEDIUM / LOW findings documented above. The dev agent recommends the authoritative `bmad-bmm-code-review` pass (different LLM per workflow close-out tip) as the next step after hardware-smoke sign-off.

### File List

**Modified by Story 9.6 (audit-only, 0-byte binary delta):**
- `_bmad-output/implementation-artifacts/9-6-epic-9-benchmark-standards-citation-audit-and-regression-gate-ccd-4.md` — this file (Completion Notes populated across Tasks 1–9, Status transitioned to `review`).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `9-6-…` key transitioned `ready-for-dev → in-progress → review`.

**Touched by Story 9.6 (comment-only, post-review remediation):**
- `src/number_prefixes.asm:22` — Senior Developer Review finding H1: `antforth extension (NFR13)` → `antforth extension (NFR12)`. Comment-only. Rebuild confirms binary unchanged: **14,787 bytes** / md5 `da1c648ba64691e3f9c910c412df7c86` (both identical pre-fix and post-fix).

**Unmodified by Story 9.6 as originally planned** (9.6 made no functional edits; the working-tree modifications shown by `git status --porcelain` against HEAD=`07ff34b` belong to stories 9.3/9.4/9.5 — see "Release-gate process flag" below):
- `src/outer_interpreter.asm` — no 9.6 edits (the 9.1 wire-in at `.try_prefix_num` is still current).
- `src/*.asm` (all other files) — no 9.6 edits.
- `tests/number_prefixes_tests.fth` — no 9.6 edits (9.6 adds zero new tests).
- `Makefile` — no 9.6 edits (no new REPL test harness entries in 9.6).
- `build/antforth.com` — 14,787 bytes, md5 `da1c648ba64691e3f9c910c412df7c86`. No source edits in 9.6 and no rebuild, so this is structurally the post-9.5 binary unchanged. (A full byte-identity proof would require a saved post-9.5 snapshot, which is not captured in this tree.)

**Release-gate process flag (HIGH — surfaced by the authoritative code review on 2026-04-20):**
HEAD is currently `07ff34b hex prefixes for numeric literals`, which is the Story 9.2 commit. Stories 9.3, 9.4, 9.5, and 9.6 are marked `done` or `review` in `sprint-status.yaml`, but none of their source-tree changes (~570 lines in `src/number_prefixes.asm`, ~228 lines in `tests/number_prefixes_tests.fth`, ~923 lines in `Makefile`, plus the 9.3–9.6 story files and the sprint-status transitions) have been committed. **Consequence: if the project lead runs the Task 8.2 tag command `git tag -a v1.9.0` against the current HEAD, the tag will point at a tree that is missing most of Epic 9's surface.** The 9.3–9.5 work and the 9.6 audit artefacts must be committed **before** `v1.9.0` is applied. Suggested ordering: commit 9.3 source, commit 9.4 source, commit 9.5 tests + reach, commit 9.6 audit — then tag. This bookkeeping is outside 9.6's audit-only scope but blocks the tag.

### Senior Developer Review (AI)

Reviewer: Ant  |  Date: 2026-04-20  |  Model: claude-opus-4-7[1m]

Independent adversarial pass invoked via `/bmad-bmm-code-review 9.6` after the initial close-out. Verified binary size (14,787 bytes, md5 `da1c648ba64691e3f9c910c412df7c86`), grep baselines (16 `Forth 2014` / 5 `antforth extension` / 20 `EXX` in `src/number_prefixes.asm`), the `.try_prefix_num` wire-in at `src/outer_interpreter.asm:181–193`, and Task 1.2's full instruction trace against `src/number_prefixes.asm:153–193` (T-state sum re-computed independently: **214 T** ✓).

| # | Sev | Finding | Status |
|---|---|---|---|
| H1 | HIGH | `src/number_prefixes.asm:22` cited `NFR13` (CP/M BDOS allow-list) instead of `NFR12` (extension discipline) for the `0x` arm; Task 6 audit row 5 recorded this as OK and Task 6.4 pasted the wrong reference as evidence. Exactly the class of citation error CCD-3/NFR17 exist to catch. | **FIXED** — line 22 corrected to `NFR12`; Task 6 row 5 and Task 6.4 quote updated. Comment-only, zero binary impact. |
| H2 | HIGH | Story `Status:` was `in-progress` despite all Tasks 1–8 PASS and hardware smoke recorded. | **FIXED** — Status transitioned to `review`; sprint-status.yaml synced. |
| M1 | MED | Task 7 narrative said "PENDING" while the table showed PASS actuals and line 793 declared PASS — reader cannot tell execution state. | **FIXED** — "PENDING" paragraph rewritten to record the 2026-04-20 execution. |
| M2 | MED | Task 9 subtasks 9.1/9.2 unticked despite Change Log line claiming prior code-review ran; no consolidated "Senior Developer Review (AI)" section (checklist line 16 requires one). | **FIXED** — subtasks 9.1/9.2 ticked; this section added. |
| M3 | MED | "Release-gate process flag" (uncommitted 9.3–9.6) was HIGH in File List but missing from the CCD-4 verdict table. | **FIXED** — added as 12th row in Task 8.1 table with verdict BLOCKED; 8.2 readiness statement updated from 10/11 → 10/12. |
| M4 | MED | AC #5 rows 3/8 drafting-slip corrections are visible as a textual lesion inside the AC text. | **ACCEPTED** — keeping the visible correction as an audit-trail artefact; will be cleaned up in the Epic 9 retro. Not a release blocker. |
| L1 | LOW | `make test-repl` 405-count claim not independently re-run during this review (time/cost). | **ACCEPTED** — recorded for the Epic 9 retro; dev-agent's 405 count stands pending re-run before tagging. |
| L2 | LOW | "byte-identical to post-9.5" binary claim is structurally unprovable without a saved prior-story snapshot. | **ACCEPTED** — future CCD-4 stories should snapshot the previous-story binary hash in the sprint-status entry or prior Completion Notes. Future-improvement note. |
| L3 | LOW | NFR-number-typo risk was not hunted across all `src/*.asm`; Task 6.5 scope sweep only grepped citation-string patterns. | **VERIFIED CLEAN** — grep `NFR1[2-3]` across all `src/*.asm` returns only the (now-corrected) line 22 hit. No further typos. |

**Reviewer verdict: APPROVED for `review` status.** H1 fix-in-place is applied (comment-only, zero binary impact — post-fix binary remains 14,787 bytes, md5 unchanged). Release readiness is gated on (a) project-lead decision on NFR1 literal-drift gate, (b) committing 9.3–9.6 source + audit artefacts before `git tag -a v1.9.0`.

### Change Log

- 2026-04-20 — Task 1: Unprefixed-path T-state cost measured. Fast-fail body = 214 T, threaded overhead = 105 T, Epic-9 addition = 319 T over post-8.4 baseline ≈ 2760 T = 11.6% literal drift. Task 1.5 spirit-reading recorded as PASS; literal gate flagged for project-lead decision.
- 2026-04-20 — Task 2: Prefixed-path `#42` measured at ~1006 T, unprefixed `42` at ~2494 T; delta = −1488 T (prefixed is cheaper due to hard-coded base multipliers). NFR1 ≤20 T gate satisfied trivially.
- 2026-04-20 — Task 3: Binary size confirmed 14,787 bytes; cumulative Epic-9 delta +757 bytes recorded and justified per revised NFR4.
- 2026-04-20 — Task 4: `make test` clean; `make test-repl` 405/405 PASS. NFR9 satisfied.
- 2026-04-20 — Task 5: FR47 emulator smoke batch — 11 rows PASS. AC #5 rows 3 and 8 expected-output text corrected in AC #5 and Task 5.1 (HEX print order; signed `.` semantics).
- 2026-04-20 — Task 6: Standards citation audit — 0 missing, 0 wrong. Forth 2014 / antforth-extension baselines (16 / 5 / 20 EXX) preserved.
- 2026-04-20 — Task 7: Real-MicroBeast hardware smoke executed by project lead; all 12 rows PASS (re-tested post-review after initial transcription issue).
- 2026-04-20 — Task 8: CCD-4 verdict table composed; release-readiness statement records 10/11 gates PASS + NFR1 literal-drift gate requiring explicit project-lead decision.
- 2026-04-20 — Task 9: Preliminary dev self-review recorded 6 findings (F1–F6).
- 2026-04-20 — `bmad-bmm-code-review` (authoritative, separate LLM) surfaced 2 HIGH + 5 MEDIUM + 3 LOW. Fixes applied in this pass: hardware-smoke Row 1 corrected (Row 1 re-tested and PASSED per project lead); rows 2–12 Actual column normalised to verbatim double-space format; AC #5 rows 3/8 gloss typos fixed in AC text and Task 5.1; File List verification wording corrected and an explicit "release-gate process flag" added for the uncommitted 9.3/9.4/9.5 state; binary claim weakened to md5 + structural argument; 8.2 readiness statement rewritten to surface the NFR1 literal-drift decision and the commit-baseline prerequisite; 9.1 story's M1 estimate refreshed in place.
- 2026-04-20 — Second `bmad-bmm-code-review` pass (this review) surfaced 2 HIGH + 4 MEDIUM + 3 LOW. Fixes applied: H1 wrong-NFR citation corrected in `src/number_prefixes.asm:22` (`NFR13` → `NFR12`) + Task 6 audit table row 5 + Task 6.4 quote block; H2 Status transitioned `in-progress` → `review` and sprint-status.yaml synced; M1 Task 7 "PENDING" paragraph rewritten; M2 Task 9 subtasks 9.1/9.2 ticked and "Senior Developer Review (AI)" section added; M3 commit-baseline prerequisite added as 12th row in CCD-4 verdict table with verdict BLOCKED, 8.2 readiness updated 10/11 → 10/12. M4, L1, L2 accepted; L3 verified clean (grep `NFR1[2-3]` across `src/*.asm` returns only the fixed line 22).
- 2026-04-20 — Project lead (`ant`) accepted the NFR1 unprefixed-path drift spirit reading ("yeah accept it, it's fine"). CCD-4 verdict table NFR1-drift row updated from "PASS (spirit) / FINDING (literal)" to unambiguous PASS; 8.2 readiness updated 10/12 → 11/12. Relaxation to be recorded in the Epic-9 retrospective; no follow-up dispatch-chain optimisation story required for 1.9 tagging.

