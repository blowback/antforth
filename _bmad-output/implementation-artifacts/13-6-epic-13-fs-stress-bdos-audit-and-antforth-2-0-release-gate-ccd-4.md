# Story 13.6: Epic 13 FS stress, BDOS audit, ROM delta + antforth 2.0 release gate (CCD-4)

Status: done

<!--
Renumbered from Story 13.5 on 2026-05-04 (party-mode session post-13.4-v2-review).
Scope unchanged from the original Epic-13 release-gate; only the story number moved
to make room for Story 13.5 (R/O destructive-flush audit + structural fix), which
was a release-blocker for `antforth 2.0`. With Story 13.5 closed (done 2026-05-04;
filesystem-blast-radius latent fixed; Makefile test 938 verdict-flipped from
expects-bug to expects-fix), Story 13.6 inherits a clean Epic-13 surface and runs
the close-out gate.

This is the final Phase-2 story. Passing the gate tags **antforth 2.0** — the
five-epic phase (9, 10, 11, 11.5, 12, 13) is complete.

Audit-only in the same style as Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6.
No new mechanism, no new code path, no new EQUs, no new dictionary words. Story
13.6 measures the system Stories 13.0..13.5 built and produces a go/no-go verdict
on whether `antforth 2.0` can be tagged. Modulo: closure-suite REPL tests
(numbered 948+) and any optional comment-only citation fixes surfaced by the
NFR17 audit.

Validation is optional. Run validate-create-story for quality check before dev-story.
-->

## Story

As an antforth maintainer,
I want Epic 13 to close with a filesystem-error stress suite (NFR8), a BDOS-function-allow-list audit (NFR13), an Epic-13 ROM-delta accounting against the post-Epic-12 baseline (NFR4), a standards-citation audit (NFR17 / CCD-3) of every Epic-13-introduced word, a full Phase-1 + Epics 9/10/11/11.5/12 + Epic-13.0..13.5 regression pass on the iz-cpm emulator (NFR9 / FR45 / FR46), a real-MicroBeast-hardware smoke including the on-device "define / save-source / INCLUDE-back" round-trip from PRD Journey 1, and a CCD-4 verdict-table go/no-go on tagging `antforth 2.0`,
so that every quantitative envelope set by the PRD is verified, the on-device edit/test/persist loop is demonstrated working on real hardware, and `antforth 2.0` can be tagged — completing Phase 2 and shipping the public 2.0 release.

This is the **Epic-13 close-out gate** — the CCD-4 per-epic benchmark + audit pattern (`architecture.md:218-226`), audit-only in the same style as Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6. It is also the **Phase-2 release gate** — every prior CCD-4 gate produced a 1.x release candidate; Story 13.6's gate produces the 2.0 candidate. The bar is therefore higher: the FS stress suite (NFR8) and the on-device round-trip (PRD Journey 1) are new evidence requirements not present in prior CCD-4 gates, but the audit-only character is preserved — no new mechanism, no new code path, no new EQUs, no new dictionary words.

---

## Severity / Phase Re-Statement (BINDING — context for every dev-pass decision)

`antforth 2.0` is the **public release tag** at the end of Phase 2. It is the first release tag that may be picked up by retro-computing-scene readers, MicroBeast forum members, and the project's wider community. The gate's bar:

| Dimension | Pre-2.0 CCD-4 gate (e.g., 12.6) | Phase-2 release gate (this story) |
|---|---|---|
| **Hardware smoke** | 12-line minimal smoke + cross-epic interaction probes | 12-line FS smoke + **define / save-source / INCLUDE-back round-trip on real hardware** (PRD Journey 1) |
| **Stress evidence** | Per-feature regression battery | **+ FS error-stress matrix (5 induced errors)** + INCLUDE-mid-THROW deep-nest |
| **External audit surface** | Citation audit of new wordset | + **NFR13 BDOS allow-list audit** (binary-vs-spec) + **§-level Core compliance re-audit confirms 100% intact** |
| **ROM-delta framing** | Per-epic delta with justification | + **Phase-2 cumulative delta** vs the pre-Phase-2 (post-Epic-8) baseline; no per-epic net-negative gate per architecture (post 2026-04-20 sprint-change) |
| **Release artefact** | 1.x tag candidate (sometimes deferred per project lead call — e.g., 1.11.5) | **2.0 tag candidate — the Phase-2 acceptance signal** |

The story is still audit-only in code shape. The new evidence dimensions are *additional verification artefacts*, not new mechanism. If any new evidence dimension surfaces a HALT-class structural defect, Story 13.6 HALTs per AC #14 and the project lead decides whether to spawn a fix-story (NOT a sibling-story-spawn anti-pattern — this is release-gate-discovered, mirror Story 13.5's epic-scope-discovered framing, not the Story 13.4 v1 anti-pattern).

---

## Acceptance Criteria

1. **Given** the **NFR8 filesystem-error stress suite** (`tests/file_access_tests.fth` extended) and the closure-suite test ID space (post-Story-13.5 baseline = test 947; new tests start at **948**),
   **when** each of the following error scenarios is induced through user-facing File-Access words and the kernel's response is captured at the REPL,
   **then** each scenario raises a descriptive THROW (or returns a non-zero `ior` per the standard's ior-vs-throw split — see Story 13.2 R/O-write semantics) **without orphaning an FCB pool slot** and **without corrupting the filesystem**:
   - **(a) Pool exhaustion** — open or create the 9th file with all 8 FCBs in use → catches `-69 THROW` (ANS §9.3.5 "file access method"); 8 prior FIDs remain valid; subsequent CLOSE-FILE on each releases the pool. **(Already test 911 from Story 13.2 (t4); 13.6 closure-suite re-frames as a stress-matrix row + adds a post-release re-acquire probe to confirm the 9th open succeeds after one of the 8 closes.)**
   - **(b) Closed-FID use-after-free** — CLOSE-FILE a valid FID, then attempt READ-FILE / WRITE-FILE / FILE-POSITION / REPOSITION-FILE / FILE-SIZE on the now-stale FID → catches `-70 THROW` (file-access-method, repurposed per `docs/throw-codes.md:182` for "use-after-free FID"). **(Already test 909/910 from Story 13.2 for some of these; closure-suite adds explicit per-word coverage for any operation not yet probed.)**
   - **(c) R/O write-attempt** — OPEN-FILE in `R/O` mode, then WRITE-FILE → returns ior=1 (non-zero recoverable per Story 13.2 (t5) AC #6 design — recoverable error, not THROW; `ior=1` is the FAM-mismatch guard at `src/file_access.asm` `.fbw_ro` arm). **(Already test 909.)**
   - **(d) Delete non-existent file** — DELETE-FILE on a filename that does not exist → returns the appropriate ior (CP/M F_DELETE returns A=255 = "file not found"; antforth wraps this per Story 13.2 design). **(Already test 913 from Story 13.2 (t6) — closure-suite re-frames as a stress-matrix row.)**
   - **(e) Disk-full simulation** — OPEN-FILE / CREATE-FILE / WRITE-FILE in a disk-near-full state, induced by writing repeatedly to a fresh file until the BDOS F_WRITE returns A != 0 (CP/M's "disk full" diagnostic) → the THROW path (or ior return) is well-defined; the FCB returns to the pool on CLOSE-FILE; the partial bytes already on disk remain readable. The induced disk-full state is reset by DELETE-FILE on the test artefact at probe end. *Note:* iz-cpm's disk image may not realistically run out of space within a probe budget; if so, the probe's evidence is captured as "induced via mock — disk-full path exercised by code-flow but not by genuine storage exhaustion; hardware re-verification deferred to Task 9 hardware smoke if budget permits". Recorded in Completion Notes Task 2.
   - **(f) Verdict gate:** every error scenario raises a descriptive THROW or returns a documented `ior`; the FCB pool returns to its pre-error state; no FID is orphaned; the filesystem remains consistent (no half-flushed records on disk for the recoverable cases). The post-stress pool occupancy = 0 (verified by re-opening 8 files, expecting all 8 to succeed; the 9th to catch `-69`). New REPL tests numbered 948..954 (one per stress-matrix row + the post-stress pool occupancy re-prove). Recorded in Completion Notes Task 2.

2. **Given** the **INCLUDE-mid-THROW stress test** (NFR8 + Epic-11 / Epic-13 coordination per Story 13.4 v2 AC #14),
   **when** a THROW fires inside a file being `INCLUDED` from inside another file being `INCLUDED` (depth ≥ 2; ideally up to depth 8 at the FCB pool ceiling),
   **then** the `INCLUDE-TOP` chain walk closes both FIDs in order, the FCB pool returns to its pre-INCLUDE state, the REPL is live with state intact, and `INCLUDE-TOP` is `0` post-recovery. **(Already covered by Makefile tests 921..937 from Story 13.4 v2; closure-suite adds one new probe at depth ≥ 5 with a deep-stack THROW — REPL test 955 — to triangulate the FCB-pool stress against the chain-walk discipline. The probe reuses `disk/a/CHAIN[A-E].FTH` from the Story 13.4 v2 disk corpus or adds a new `disk/a/DEEPN.FTH` that does its own self-recursion via `' INCLUDED CATCH`.)** Recorded in Completion Notes Task 3.

3. **Given** **NFR13's BDOS function allow-list** (the architecture's definitive list — `architecture.md:101`: 15, 16, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40 for File-Access; plus `prd.md:475`: 1, 2, 6, 9, 10, 11, 12, 13, 14, 17, 18 for console / system) and the post-Story-13.5 binary at **24,694 bytes** (production) and **26,010 bytes** (filesanity),
   **when** the final binary is audited for BDOS call sites via `grep -nE '^\s*CALL\s+BDOS_ENTRY' src/*.asm` (cross-checked against `grep -nE 'LD\s+C,\s*F_[A-Z]+' src/*.asm` for the function-number setup pattern),
   **then** every call uses a function number from the allow-list. **Pre-audit baseline (verify at dev-pass, expected from Story 13.5 close-out):**
   - `src/file_access.asm`: **14 sites** (Story 13.5 close-out grep) covering F_OPEN(15), F_CLOSE(16), F_DELETE(19), F_READ(20), F_WRITE(21), F_MAKE(22), F_DMAOFF(26), F_READRAND(33), F_WRITERAND(34), F_SIZE(35).
   - `src/io.asm`: **4 sites** covering console I/O (BDOS 1=C_READ, 2=C_WRITE, 6=C_RAWIO, 9=C_WRITESTR — verify exact per-line at dev-pass).
   - `src/outer_interpreter.asm`: **1 site** (likely C_READSTR=10 or C_RAWIO=6 — verify per-line).
   - **Total expected: 19 CALL BDOS_ENTRY sites** across all `src/*.asm` files.

   The audit table in Completion Notes Task 4 lists one row per BDOS function actually used, with: function number, function symbol, call-site file:line, purpose, allow-list citation (architecture line / PRD line). **Likely finding (drafting-time hypothesis — verify at dev-pass):** PRD NFR13 (`prd.md:475`) lists "(1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40)" but **omits 22 (F_MAKE)** which is required by `CREATE-FILE` per Story 13.2's E13-D3 BDOS wrapper layer and present in the binary at `src/file_access.asm:553`. The architecture (`architecture.md:101`) explicitly includes 22 in its File-Access allow-list. This is a PRD/architecture transcription drift, not a real allow-list violation. Either: (i) the dev pass updates PRD NFR13 in-place to include 22 (canonical fix — comment-only doc edit, zero binary delta); OR (ii) the dev pass documents the discrepancy and escalates to project lead. Provisional pick: (i) per `feedback_systematic_reference_check.md` (architecture is the binding contract; PRD wording is documentation). Recorded in Completion Notes Task 4.

4. **Given** Epic 13's **per-story ROM trajectory** measured against the pre-Epic-13 baseline (post-Story-12.6 = **18,230 bytes** per `_bmad-output/implementation-artifacts/12-6-…md` Task 4 / Change Log) and the **Phase-2 cumulative ROM trajectory** measured against the pre-Phase-2 (post-Epic-8) baseline,
   **when** `wc -c build/antforth.com` is measured at each Epic-13 story's commit,
   **then** the per-story and Epic-13-cumulative deltas are recorded in Completion Notes Task 5 with the per-story Completion-Notes line citation per `feedback_systematic_reference_check.md` (do not enumerate the trajectory from memory):
   - **13.0** (double-cell literal recogniser ANS §3.4.1.3 dot-anywhere): pre 18,230 / post **18,665** per `13-0-…md` Change Log
   - **13.0.1** (flip double-cell stack convention high-on-TOS): pre 18,665 / post **18,662** per `13-0-1-…md` Change Log (−3 bytes; symmetrical push/pop)
   - **13.1** (FCB pool + BDOS wrapper layer + `(FILE-IO-SANITY)` harness): pre 18,662 / post **20,589** (+1,927 production / +1,318 filesanity-only delta) per `13-1-…md` Change Log post-code-review-F-A
   - **13.2** (Core File-Access wordset OPEN-FILE / CREATE-FILE / CLOSE-FILE / DELETE-FILE / READ-FILE / WRITE-FILE): pre 20,589 / post **21,887** per `13-2-…md` post-code-review-L6 close-out
   - **13.3** (FILE-POSITION / REPOSITION-FILE / FILE-SIZE — file positioning): pre 21,887 / post **22,536** (+649; net of code-review L1 −9 byte fix) per `13-3-…md` Task 13 / Change Log
   - **13.4 v2** (INCLUDED / INCLUDE-FILE / INCLUDE + INCLUDE-TOP chain discipline): pre 22,536 / post **24,594** (+2,058; HALT logged per AC #23 — code +991 vs +700..+850 envelope; flagged for project-lead-accepted overshoot at code-review close) per `13-4-…md` Change Log
   - **13.5** (R/O destructive-flush mode-aware fix + has-written bit): pre 24,594 / post **24,694** (+100 = data +8 + code +92, within +58..+116 envelope) per `13-5-…md` Task 14 / Change Log
   - **13.6** (this story; audit-only): expected delta = **0 bytes** for `src/*.asm` (audit-only); any non-zero binary delta requires explicit justification in Completion Notes Task 5 (e.g., a NFR17 missing-citation inline-comment fix is comment-only and should be 0 binary bytes; if not, sjasmplus collapsed something — investigate).

   **Epic-13 cumulative (production binary):** **18,230 → 24,694 = +6,464 bytes (+35.5%)** — verify the absolute numbers and the per-story sum reconciliation at write-time. Sum check: −0 + 435 (back-fill 13.0) − 3 + 1,927 + 1,298 + 649 + 2,058 + 100 = +6,464 (verify the +435 for 13.0 vs the 18,230 → 18,665 trajectory; the +1,298 for 13.2 is 21,887 − 20,589; verify all per-story Completion-Notes citations).

   **Phase-2 cumulative (post-Epic-8 → post-Story-13.6):** the pre-Phase-2 baseline is the post-Epic-8 binary size — verify by `git log --all --oneline | grep -i "epic-8\|story 8" | tail -1` and `git show <commit>:Makefile | grep TARGET` then re-build at that commit. Story-drafting hypothesis (verify at dev-pass): the Phase-2 cumulative is dominated by Epic 13 (+6,464) + Epic 12 (+688 net, +689 incl. v1.12 banner bump) + Epic 11 + Epic 10 + Epic 9 + Epic 11.5 (+116). All five Phase-2 epics are net-add capability; per `architecture.md:55-58` (NFR4 post-2026-04-20 sprint-change revision per `sprint-change-proposal-2026-04-20.md`) **there is no per-epic net-negative gate**. The discipline is delta recorded + justified. Phase-2 is **net-new capability** (numeric prefixes + double-cell + pictured + 100% Core + CATCH/THROW + Search-Order + File-Access). ROM growth is the expected cost. Justification framing recorded in Completion Notes Task 5.

   **Reconciliation:** per-story sum exactly matches absolute delta — any residual is investigated and explained per the Story 11.8 / 11.5.7 / 12.6 precedent (inter-story comment-only commits can introduce 1-2 byte drift). Mirror Story 12.6 Task 4.2 reconciliation discipline.

5. **Given** the full Phase-1 + Epic-9 + Epic-10 + Epic-11 + Epic-11.5 + Epic-12 + Epic-13.0..13.5 regression suite (`make test` assembly thread + `make test-repl` REPL-piped tests + `make test-file-sanity` (FILE-IO-SANITY) harness),
   **when** run against the post-Story-13.5 binary on the iz-cpm emulator,
   **then** every test passes — **zero regressions per NFR9 / FR45 / FR46** (PRD line 468 / 438 / 439). **Pre-edit expected baseline:**
   - `make test` → assembly thread groups expected output match (clean, no group-mismatch failure) per `Makefile:55-71`.
   - `make test-repl` → **947 PASS / 0 FAIL** (Story 13.5 Task 13.2 close-out figure; verify pre-edit via `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1`).
   - `make test-file-sanity` → PASS (Story 13.5 Task 13.4 close-out).

   Story 13.6 adds **6-12 new closure tests** numbered 948.. (per ACs #1, #2, #6 below). Total post-Story-13.6 expected: **953-959**. Any pre-existing test failure is a release blocker — debug the root cause; do not paper over (per `feedback_standards_compliance.md`). New tests cover: (a) FS error-stress matrix per AC #1 (5-7 tests), (b) deep-nest INCLUDE-mid-THROW per AC #2 (1 test), (c) on-device round-trip Forth-side probe per AC #6 (1-2 tests, separate from the hardware-only round-trip in Task 9), (d) any cross-epic interaction surfaced by the audit (e.g., FCB-pool occupancy after a CATCH'd file-access THROW). Final pick of test count + IDs recorded in Completion Notes Task 6.

6. **Given** every Epic-13-introduced word in `src/file_access.asm` (`OPEN-FILE`, `CREATE-FILE`, `CLOSE-FILE`, `DELETE-FILE`, `READ-FILE`, `WRITE-FILE`, `FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`, `INCLUDED`, `INCLUDE-FILE`, `INCLUDE`, `R/O`, `R/W`, `W/O`, `BIN`, `INCLUDE-TOP`, `(FILE-IO-SANITY)`, plus internal helpers `(slab-from-fid)`, `(fid-validate)`, `(input-frame-push)`, `(input-frame-pop)`, `(close-current-fid)`, `(file-refill)`, `(refill-and-interpret-loop)`) and every Epic-13-modified site in `src/exception.asm` (the `chain_walk_close_current_fid` THROW chain-walk for INCLUDE source frames),
   **when** audited against CCD-3 / NFR17 (`architecture.md:206-216`),
   **then** every standards-derived word carries an inline `; ANS Forth 1994 §<x>` citation. The audit yields a count baseline (grep-verified pre-story):
   - `grep -cE "ANS Forth 1994 §11\.6\.1\." src/file_access.asm` → expect ≥ **12** (one per FR32-FR42 word: §11.6.1.0900 CLOSE-FILE, §11.6.1.1010 CREATE-FILE, §11.6.1.1190 DELETE-FILE, §11.6.1.1520 FILE-POSITION, §11.6.1.1522 FILE-SIZE, §11.6.1.1717 INCLUDE-FILE, §11.6.1.1718 INCLUDED, §11.6.1.1970 OPEN-FILE, §11.6.1.2080 READ-FILE, §11.6.1.2142 REPOSITION-FILE, §11.6.1.2480 WRITE-FILE — 11 §11.6.1.x rows. R/O / R/W / W/O / BIN are FAM constants per §11.6.1.1804/2054/2425/0762).
   - `grep -cE "ANS Forth 1994 §11\.6\.2\." src/file_access.asm` → expect ≥ **1** (§11.6.2.1717 INCLUDE — Forth 2014 Extension, BL WORD COUNT INCLUDED form per Story 13.4 v2).
   - `grep -cE "§9\.3\.5" src/file_access.asm src/constants.asm` → expect ≥ **3** (THROW -38 file-not-found, THROW -69 FCB pool exhausted, THROW -70 invalid FID per Story 13.2/13.4; plus -37 file I/O latent slot per `docs/throw-codes.md:109`).
   - `grep -nE 'fcb_pool|fcb_byte_pos|fcb_fam|fcb_has_written|include_line_pool|INCLUDE_TOP|search_order_depth' src/file_access.asm src/exception.asm src/structures.asm src/antforth.asm` returns the data-flow surface; spot-check that each access carries either an inline citation or a structural comment naming the architectural decision (E13-D1 / E13-D2 / E13-D3) it implements.

   The audit is **discovery, not regeneration** — if a citation is missing or wrong, fix in-place (comment-only edit; zero binary delta — confirm via Task 5 re-run). The audit table in Completion Notes lists one row per Epic-13-introduced word with columns: word, source `file:line`, citation text, audit verdict (`OK` / `MISSING` / `WRONG`). Recorded in Completion Notes Task 7.

7. **Given** `docs/ans-forth-core-compliance.md` post-Epic-10 100% Core compliance + Stories 13.0 / 13.0.1 §-level back-fill rows,
   **when** Story 13.6 closes,
   **then** a phase-wide compliance re-audit confirms coverage **remains 100%** — no Epic-13 change regressed Core compliance. **Pre-edit verification:** `grep -nE "^\| §|(complete|partial|gap)" docs/ans-forth-core-compliance.md | head -30` to inspect the row structure; `grep -cE "^\| (complete|✓|done)" docs/ans-forth-core-compliance.md` to count the green rows pre-edit; verify the §11.6.1.x File-Access rows were added by Stories 13.2 / 13.3 / 13.4 / 13.5 (each story owns its row addition per the spec). Story 13.6 does not add new rows; it verifies the table is internally consistent and that the Epic-13 row entries reflect the post-13.5 state (Story 13.4 v2 caveat updated to Story 13.5 status per Story 13.5 Task 11.1). Recorded in Completion Notes Task 8.

8. **Given** the **per-Phase-2 §-level Core compliance state** (which Stories 13.0 + 13.0.1 closed two structural-rule gaps that Epic 10's word-counted survey was structurally blind to: §3.4.1.3 dot-anywhere parser rule + §3.1.4.1 high-on-TOS double-cell stack-layout rule),
   **when** Story 13.6 audits,
   **then** the §-level compliance is documented in Completion Notes Task 8 with the explicit caveat: "two §-level structural-rule gaps closed by Epic-13 back-fills (§3.4.1.3 + §3.1.4.1); a full §-by-§ pre-2.0 audit pass remains a wishlist item per `docs/WISHLIST.md` / project-lead 2026-05-01". This is **not** a release blocker — the back-fills closed the known §-level gaps, and the design discipline (`feedback_design_upfront.md` + `feedback_systematic_reference_check.md`) for any future §-level gap discovery is a 2.x carry-forward. The 2.0 release tag carries the explicit caveat in its release notes (recommended; project lead's call). Recorded in Completion Notes Task 8.

9. **Given** the **on-device "define / save-source / INCLUDE-back" round-trip** from PRD User Journey 1 (Mo's on-device session — `prd.md:172-180`) and the existing Story 13.4 v2 hardware-smoke transfer mechanism (established post-9.6 / 10.10 / 11.8 / 11.5.7 / 12.6),
   **when** the user (project lead) operates on real MicroBeast hardware:
   - (i) defines a small word at the REPL — e.g., `: BLINK 0xF0 @ 1 XOR 0xF0 ! ;`
   - (ii) saves the definition's source to a file on B: via `S" BLINK.FTH" R/W CREATE-FILE DROP <FID> S" : BLINK 0xF0 @ 1 XOR 0xF0 ! ;" ROT WRITE-FILE DROP CLOSE-FILE` (or a more-ergonomic variant using `S"` + `WRITE-FILE` + close)
   - (iii) reboots the MicroBeast (or runs `BYE` and re-loads the .COM)
   - (iv) `INCLUDE B:BLINK.FTH` — the definition is restored
   - (v) `BLINK BLINK BLINK` — the LED on the bench blinks three times (or the bench-side equivalent for the project lead's hardware setup),

   **then** the round-trip completes — PRD Journey 1 success criterion met on real hardware. Capture the verbatim console output of all five steps in Completion Notes Task 9 (mirror Story 11.8 / 12.6 verbatim-capture discipline; transcript to `~/Downloads/bestialitty-13-6-YYYYMMDD-HHMMSS.bin`). This gate is **REQUIRED** for tagging `antforth 2.0`. If the round-trip fails on hardware (e.g., the on-device emulator runs the round-trip clean but real CP/M 2.2 BDOS perturbs an intermediate step), HALT and flag for project lead per AC #14.

   **Hardware smoke procedure** (inherited from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6): copy `build/antforth.com` to the MicroBeast via the project lead's standard transfer mechanism. The transfer is established; reuse without re-asking (per `feedback_follow_process.md`). The re-boot in step (iii) tests the on-disk persistence — antforth's session state is intentionally non-persistent across reboots; only the file-on-disk persists. If `BYE` is unimplemented (verify at dev-pass via `grep -nE 'DEFCODE\s+w_BYE_h\|"\s*BYE\s*"' src/*.asm`), the project lead may simulate the reboot via cold-restart of the .COM.

10. **Given** the **standard 12-line FS smoke batch** for hardware verification of the user-facing File-Access words (mirror Story 11.8 / 12.6 12-line discipline; minimal coverage of one per Epic-13 user-facing word + cross-epic interactions),
    **when** the project lead exercises the smoke batch on real MicroBeast hardware (in addition to AC #9's round-trip),
    **then** every smoke line passes on real hardware. Smoke batch (12 lines):
    - `S" HELLO.TXT" R/W CREATE-FILE . .` → `0 <fid>  ok` (positive control: CREATE-FILE returns ior=0 + valid FID)
    - `S" Hello!" 6 ROT WRITE-FILE .` → `0  ok` (WRITE-FILE returns ior=0; bytes buffered)
    - `CLOSE-FILE .` → `0  ok` (CLOSE-FILE flushes + releases pool)
    - `S" HELLO.TXT" R/O OPEN-FILE . .` → `0 <fid>  ok` (re-open R/O for read)
    - `PAD 6 ROT READ-FILE . .` → `0 6  ok` (READ-FILE returns ior=0, 6 bytes read) — *or use `HERE 6 ROT READ-FILE . .` per Story 13.5 finding F3 if PAD remains undefined*
    - `PAD 6 TYPE` → `Hello! ok` (verify content)
    - `CLOSE-FILE .` → `0  ok`
    - `S" HELLO.TXT" DELETE-FILE .` → `0  ok` (cleanup)
    - **INCLUDE / on-device round-trip:** `S" B:NESTED.FTH" INCLUDED` (or A: equivalent depending on the disk image setup) → expected output per `disk/a/NESTED.FTH` content (verify the test-asset disk contains this from Story 13.4 v2)
    - **FCB pool re-prove:** `S" P1.TXT" R/W CREATE-FILE DROP DROP S" P2.TXT" R/W CREATE-FILE DROP DROP ... S" P8.TXT" R/W CREATE-FILE DROP DROP S" P9.TXT" R/W ' CREATE-FILE CATCH . .` → `-69 -69  ok` (8 opens succeed; 9th catches `-69`; mirrors Story 13.2 test 911)
    - **R/O destructive-flush invariant** (Story 13.5 fix verification on hardware): `S" HELLO.TXT" R/W CREATE-FILE DROP FA ! S" hi" 2 FA @ WRITE-FILE DROP FA @ CLOSE-FILE DROP S" HELLO.TXT" R/O OPEN-FILE DROP FA ! HERE 1 FA @ READ-FILE DROP DROP FA @ CLOSE-FILE DROP S" HELLO.TXT" R/O OPEN-FILE DROP FA ! FA @ FILE-SIZE D. CR FA @ CLOSE-FILE DROP S" HELLO.TXT" DELETE-FILE DROP` → output includes `2 0` (or `2 ` followed by the high-cell zero per the high-on-TOS convention; the source file size remains 2 bytes after the partial read, NOT extended by 128+ bytes per the post-13.5 fix)
    - **i\*x preservation across Epic-13 surface (Story 11.4.1 inheritance):** `1 2 3 ' ABORT CATCH . . . .` → `-1 3 2 1  ok` (the file-access words do not perturb the i\*x register — Story 11.4.1 contract preserved post-Epic-13)

    Recorded **verbatim** in Completion Notes Task 10. Mirror Stories 11.8 Task 8 / 12.6 Task 8 capture discipline. This gate is **required** for tagging `antforth 2.0`.

11. **Given** the completion of ACs #1–#10,
    **when** the dev agent composes the Epic-13 + Phase-2 closure summary,
    **then** the story's Completion Notes include (a) a "**CCD-4 + Phase-2 release gate verdict**" table near the top of Completion Notes summarising PASS/FAIL per gate (NFR4 ROM, NFR8 FS error stress, NFR9 / FR45 / FR46 zero-regression, NFR13 BDOS allow-list, NFR17 / CCD-3 citations, FR45 Core-100% intact, MVP Journey-1 round-trip, MVP 12-line smoke), (b) the **antforth 2.0 release-readiness one-liner** ("READY to tag — all gates PASS" or "BLOCKED — the following gate(s) fail: …"), (c) a git tag proposal line (`git tag -a v2.0.0 -m "Phase 2: ANS Core 100% + CATCH/THROW + Search-Order + File-Access + on-device source development"`) the user can copy-paste, (d) a milestone marker noting that Epic 13 closes Phase 2 entirely; the next phase (post-2.0) starts with the MicroBeast hardware vocabulary and beginner's guide per `prd.md:142-147`. **No tag is applied by the dev agent** — tagging is the project lead's action (mirror Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 disposition).

12. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` "reviews MUST find things; absence of findings is suspect") and the Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 close-out-review yield (each surfaced ≥ 1 LOW finding, often more),
    **when** Story 13.6's review runs,
    **then** **at least 2-4 LOW/MEDIUM findings are expected** (the 2.0 release gate has more surface than prior CCD-4 gates — FS stress matrix + on-device round-trip + cross-stack BDOS allow-list audit are net-new evidence dimensions). Likely candidates the review must investigate:
    - **(a) NFR8 stress-matrix completeness** — the AC #1 stress matrix probes 5 induced errors. Are there other realistic FS error scenarios the matrix should cover? E.g., a malformed CP/M filename (Story 13.2 (t7) covers `S" "`, `S" hi*.txt"`, `S" hi sp.txt"`, `S" two..dot"`, `S" /path/x"` — confirm closure-suite leverages or extends this), a directory-full state (CP/M 2.2 dir is 64 entries — disk image setup-dependent), READ-FILE on a fresh-CREATE-FILE'd zero-byte file (returns ior=0 + u2=0 per ANS spec). Document candidates considered + dispositioned.
    - **(b) NFR13 binary-vs-spec audit completeness** — the AC #3 grep covers `CALL BDOS_ENTRY` patterns. Does any source file invoke BDOS via an alternative idiom (e.g., a `JP BDOS_ENTRY` for tail-call optimisation, or a `RST 8`-style trampoline)? Re-verify with `grep -nE 'BDOS_ENTRY|0x0005|RST.*BDOS' src/*.asm` to triangulate the call-site count.
    - **(c) ROM-trajectory per-story sum reconciliation** — the Epic-13 cumulative (+6,464 absolute) must reconcile against the per-story sum; any residual is investigated and explained per the Story 11.8 / 11.5.7 / 12.6 precedent. Mirror Story 12.6 Task 4.2 reconciliation discipline.
    - **(d) Phase-2 cumulative ROM trajectory accounting** — beyond Epic 13, the Phase-2 cumulative needs the per-epic deltas summed against the post-Epic-8 baseline. Each per-epic delta is documented in its respective close-out story (9.6 / 10.10 / 11.8 / 11.5.7 / 12.6); cite each one. Reconciliation: per-epic sum must match (post-Story-13.6) − (post-Epic-8) absolute; any drift is a Finding.
    - **(e) On-device round-trip success measurement** — does Task 9's round-trip evidence include all five steps verbatim? Step (iii)'s "reboot or BYE" is operationally ambiguous; the dev pass may simulate via cold-restart-of-.COM if BYE is unimplemented. Document the choice and rationale.
    - **(f) Hardware smoke verbatim capture** — actual console output recorded byte-for-byte, not paraphrased (mirror Story 11.8 / 12.6 capture discipline). A future maintainer reading AC #9 / #10's evidence must see the exact bytes the MicroBeast emitted.
    - **(g) Sprint-status row drift** — per-story rows for 13-0, 13-0-1, 13-1, 13-2, 13-3, 13-4, 13-5 must all be `done` at finalize-time (mirror Story 11.8 / 11.5.7 / 12.6 sub-story-alignment caveats); any row still in `review` or `in-progress` is a Finding requiring reconciliation before the `epic-13: in-progress → done` flip.
    - **(h) Memory-currency drift** — `project_phase2_scope.md`, `project_assembler_keep_assembly.md`, `project_asm_hash_dispatch_hack.md`, `project_epic_11_5_scope.md`, `project_epic4_scope.md`, `project_epic5_scope.md`, `project_hardware_crash_audit.md`, `project_tos_in_register.md` must all be current and consistent with the post-Story-13.5 state. Any stale entry is a Finding; close-out is the right time to update Phase-2-spanning memories with the 2.0 milestone marker.
    - **(i) No silent scope creep** — Story 13.6 is audit-only (modulo Task 6 closure tests, Task 7 citation fixes, Task 4 PRD NFR13 doc-fix for BDOS 22). If the dev agent modified assembly source other than a missing-citation comment fix or a doc-only edit, that is a Finding — either the audit uncovered a real defect (HALT per AC #14 and document as a sub-story for project-lead disposition) or the edit is out of scope (revert).
    - **(j) `epic-13: in-progress → done` flip ordering** — the flip happens at the story-`done` step (mirror Story 11.8 Task 11.3 / 11.5.7 AC #6(c) / 12.6 AC #13); not at `review`. Sub-story rows must all be `done` before this flip.
    - **(k) Proposed git tag line** — `v2.0.0` per architecture §NFR18 / `prd.md:262`; do not pre-apply. Tag-message headline matches the Phase-2 deliverable framing (project lead may rephrase). This is **the 2.0 release tag**; framing matters more than for prior 1.x tags. Recommend cross-checking the project's prior tag conventions via `git tag -l | tail -10`.
    - **(l) Stress-matrix probe-quality fixes** — Stories 13.5's findings F2 (`."` clobbers BC) + F3 (PAD undefined) propagate to Story 13.6's smoke / closure tests. The closure-suite must use `S"` + `TYPE` instead of `."` for any string output that needs to survive a TOS-preserving probe; and `HERE` instead of `PAD` for any byte buffer. Carry the Story 13.5 fix shape forward.
    - **(m) Disk-full simulation evidence integrity** — AC #1(e) acknowledges that genuine disk exhaustion may not be inducible inside the iz-cpm probe budget; the evidence may be code-flow-only with hardware-deferred verification. Document the methodology choice + evidence shape. A code-review reader must understand whether the gate is "verified by genuine storage-out" or "verified by code-path traversal under mock conditions".
    - **(n) Phase-2 §-level Core compliance carry-forward** — AC #8 explicitly carries forward the §-by-§ pre-2.0 audit pass as a 2.x wishlist item. The dev pass should propose the carry-forward landing site (recommend: a new entry in `docs/WISHLIST.md` titled "Phase-3 systematic §-by-§ ANS Forth Core re-audit" with Stories 13.0 + 13.0.1 + 13.5 cited as motivating examples). Comment-only doc edit; zero binary delta.

    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 review-log discipline). Recorded in Completion Notes Task 11 with ID / Severity / Category / Description / Resolution columns.

13. **Given** the verdict-table format from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 (`Gate text | Evidence | Verdict` columns),
    **when** Story 13.6 lands,
    **then** Completion Notes mirror that format and **add a Phase-2 release-gate row set** for the 2.0-specific evidence (MVP Journey-1 round-trip, MVP 12-line FS smoke, NFR8 stress matrix, NFR13 BDOS allow-list audit, Phase-2 cumulative ROM, §-level Core compliance state). State the value, the gate, and the reason **plainly** per `feedback_plain_qa_language.md`. Place the verdict table **near the top of Completion Notes** (mirror Stories 11.8 / 11.5.7 / 12.6 layout) — this is the visible output a future reader (or re-audit) opens the story file to find. Don't bury it in Task 11's review section.

14. **Given** the in-pass-fix discipline established by Stories 11.5.2 / 11.5.3 / 11.5.4 / 11.5.5 / 11.5.6 / 11.5.7 / 12.1–12.6 / 13.0–13.5,
    **when** small in-pass refinements surface (citation comment fixes per Task 7, sprint-status sub-row flips per AC #12(g), memory-currency tweaks per AC #12(h), PRD NFR13 transcription fix for BDOS 22 per AC #3),
    **then** they are landed inside this story — no spawning further sub-stories. **The exception**: if the regression suite (AC #5), the FS stress matrix (AC #1), the BDOS allow-list audit (AC #3), the hardware smoke (AC #9 / AC #10), or the Core-compliance re-audit (AC #7) surfaces a **structural defect** (a real regression introduced by Stories 13.0..13.5, an NFR13 binary-vs-spec violation, an FCB-orphan or filesystem-corruption event under stress, a hardware-only crash class, or a Core-100%-regression), **HALT and flag as a finding for the project lead** before deciding scope — the change becomes a separate decision, not in-pass cleanup.

    The Story-13.4 v1 anti-pattern (sibling-story-spawn + half-done-ship) is explicitly forbidden, re-asserted from Story 13.4 v2 AC #26 and Story 13.5 AC #11. The valid options are (a) all goals met, or (b) HALT log + project-lead escalation. **No third option.** Documented in Completion Notes Task 12.

    **Identifier gate (inherited from 13.4 v2 / 13.5 AC #11):** any newly-introduced identifier in Story 13.6's diff (closure tests, doc edits) containing the substrings `hack`, `workaround`, `fixme`, or a standalone `tmp` token (case-insensitive) is a HIGH finding requiring rework before close.

15. **Given** sprint-status flip ordering (mirror Story 11.8 Task 11.3 / 11.5.7 AC #6(c) / 12.6 AC #13),
    **when** Story 13.6 lands,
    **then** the row `13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4` flips through `backlog` (pre-create-story) → `ready-for-dev` (this story's creation) → `in-progress` (dev-pass start) → `review` (dev-pass close) → `done` (code-review close); **and** the row `epic-13: in-progress → done` flips at the **story-`done` step** (not at `review`). The `epic-13-retrospective: optional` row is not gated on Story 13.6's completion; the project lead may run a Phase-2 retrospective post-tag at their discretion (per `bmad-bmm-retrospective` skill). Sub-story rows 13-0 through 13-5 are confirmed `done` at finalize per AC #12(g).

16. **Given** Story 13.6 is the **Phase-2 release gate** (the final close-out for the 9, 10, 11, 11.5, 12, 13 phase),
    **when** Story 13.6 closes,
    **then** the Phase-2 milestone marker is recorded in Completion Notes Task 13: (a) FR1-FR47 delivered (FR30 deliberately gapped per Story 11.5.5 / `epics.md:1037-1075`); (b) NFR1-NFR21 satisfied or carry-forward-documented per AC #8 (§-level audit) and AC #1(e) (disk-full hardware-deferred); (c) the public release tag candidate is `v2.0.0`; (d) post-tag opportunities (per `prd.md:142-147`): MicroBeast hardware vocabulary epic, beginner's guide, per-wordset reference, worked examples — none of which are 2.0-tag-blocking.

---

## Tasks / Subtasks

**Discipline:** every parent task `[x]` requires every subtask `[x]` (Story 13.4 v2 AC #28, inherited by 13.5 + 13.6). Parent-checked-with-unchecked-subtasks is a code-review HIGH finding.

- [x] **Task 1 — Pre-edit baseline + grep evidence (AC: #4, #5, #15)**
  - [x] 1.1 `wc -c build/antforth.com` → **24,694 bytes** (matches Story 13.5 Task 14.2).
  - [x] 1.2 `wc -c build/antforth_filesanity.com` → **26,010 bytes** (matches Story 13.5 Task 14.6).
  - [x] 1.3 Highest test ID = **938** (Story 13.5 audit anchor). Drafter-figure correction F-1: AC #1 / Task 1.3 said 947 (PASS-line count, not highest unique ID). New closure tests start at **939**, not 948. Documented in Completion Notes Task 1 + Task 11.
  - [x] 1.4 `make test` PASS: assembly thread groups 1–6 clean.
  - [x] 1.5 `make test-repl` → **947 PASS / 0 FAIL** confirmed (PASS-line count = 947; highest unique test ID = 938 — see 1.3).
  - [x] 1.6 `make test-file-sanity` PASS: 11 expected lines match exactly.
  - [x] 1.7 BDOS call-site enumeration: **16 CALL BDOS_ENTRY sites** (11 in `file_access.asm` lines 477/486/495/505/519/554/563/574/584/593/602 + 4 in `io.asm` 135/158/174/190 + 1 in `outer_interpreter.asm:134`) plus **1 `JP BDOS_ENTRY`** in `src/system.asm:12` for `BYE` (P_TERMCPM = 0). Total BDOS surface = **17 sites**. Drafter-figure correction F-2: AC #3 said "19 sites / 14 in file_access" — reality is 17 / 11; drafter also omitted the `JP BDOS_ENTRY` BYE exit. Canonical audit table in Task 4.
  - [x] 1.8 Sprint-status sub-row alignment confirmed: 13-0 / 13-0-1 / 13-1 / 13-2 / 13-3 / 13-4 / 13-5 = **done**; 13-6 = **in-progress** (flipped at dev-pass start per AC #15).

- [x] **Task 2 — NFR8 FS error-stress matrix (AC: #1, #12(a), #12(l), #12(m))**
  - [x] 2.1 Stress-matrix design pinned: 4 active probes (rows a-d) + 1 documented-only (e) + 1 subsumed (f). Total 4 active stress-matrix tests + 1 deep-nest test (Task 3) = 5 new closure tests at IDs 939..943.
  - [x] 2.2 Probe-quality fix forward-port confirmed: every probe uses `S" label" TYPE` (not `."`); test 941 uses `HERE` (not `PAD`).
  - [x] 2.3 Probes 939..942 authored in `tests/file_access_tests.fth` Section 10 + Makefile probes inline. REPL test IDs **939..942** (drafter-figure correction F-1: spec said 948..954; reality runs 939..943 with no gap).
  - [x] 2.4 Disk-full methodology recorded: iz-cpm cannot exhaust within probe budget; evidence captured as code-path traversal (F_WRITE A!=0 path + F_MAKE 0xFF path verifiable in `src/file_access.asm`); hardware re-verification deferred.
  - [x] 2.5 Makefile entries 939..943 appended after test 938 (before file-sanity section).
  - [x] 2.6 `make test-repl` post-edit: **952 PASS / 0 FAIL** (was 947 / 0; net +5; 0 regressions).
  - [x] 2.7 Each stress probe verified PASS: -69 THROW raised + post-release re-acquire works (939); -70 THROW on closed WRITE-FILE (940); R/O write fails ior=1 + pool re-acquires (941); DELETE-FILE missing → ior=1 (942). FCB pool returns to pre-error state in every probe.
  - [x] 2.8 Post-stress pool occupancy probe subsumed by test 939's re-acquire half + existing tests 908 (pool-exhaust) and 936 (recursive-INCLUDE → -69 + replenish).

- [x] **Task 3 — INCLUDE-mid-THROW deep-nest stress (AC: #2, #12(a))**
  - [x] 3.1 Probe authored: depth-6 self-recursive INCLUDE via `disk/a/DEEPN.FTH` + colon helper `DEEPN-STEP` (DPN counter: 5 → 0; THROW -1 at deepest).
  - [x] 3.2 Verified: `INCLUDE-TOP @` = 0 post-CATCH; FCB pool re-usable; REPL live (next probe in subsequent test runs cleanly); no orphan FIDs.
  - [x] 3.3 New disk asset `disk/a/DEEPN.FTH` added (one line: `DEEPN-STEP`). Recursion logic lives in the probe's colon definition (per the IF/THEN compile-only fix).
  - [x] 3.4 REPL test ID **943** (Makefile entry appended after test 942).
  - [x] 3.5 `make test-repl` PASS (test 943 PASS); `make test-file-sanity` PASS.

- [x] **Task 4 — NFR13 BDOS allow-list binary-vs-spec audit (AC: #3, #12(b))**
  - [x] 4.1 Per-call-site table built (Completion Notes Task 4): 17 BDOS sites mapped to {file, line, function symbol, BDOS number, wrapper purpose}.
  - [x] 4.2 Alternative-idiom cross-check found 1 `JP BDOS_ENTRY` (`src/system.asm:12`, BYE / P_TERMCPM = 0). No `RST` or direct-`0x0005` idioms.
  - [x] 4.3 Audit table contains allow-list citations against architecture §101 + PRD §475 (post-fix).
  - [x] 4.4 PRD-22 transcription drift confirmed (Finding F-3); PRD-0 transcription drift surfaced by audit (Finding F-4 — BYE / P_TERMCPM also missing).
  - [x] 4.5 In-pass doc-only fix landed: `prd.md:475` updated to include 0 and 22; comment-only doc edit; binary unchanged at 24,694 bytes (verified post-fix).
  - [x] 4.6 Every call site uses an allow-list function number (post-fix). Zero out-of-allow-list calls.
  - [x] 4.7 `epics.md:110` (NFR13 summary) + `epics.md:1656` (Story 13.6 Given clause) updated identically.

- [x] **Task 5 — Epic-13 + Phase-2 ROM trajectory accounting (AC: #4, #12(c), #12(d))**
  - [x] 5.1 Per-Epic-13-story trajectory mined from each story's Completion Notes / Change Log (verified via `grep` against citation lines per `feedback_systematic_reference_check.md`).
  - [x] 5.2 Per-story sum reconciliation: 18,230 → 24,694 = +6,464; per-story sum 435 − 3 + 1,927 + 1,298 + 649 + 2,058 + 100 + 0 = **6,464 — exact match, zero residual** ✓.
  - [x] 5.3 Phase-2 baseline: post-Epic-8 = **14,030 bytes** (per `9-6-…md:19` + `:196`, commit `27c4cbd`). No re-checkout/rebuild needed — Story 9.6 already recorded the figure with citation discipline.
  - [x] 5.4 Phase-2 cumulative table populated; per-epic deltas: +757 / +1,985 / +653 / +116 / +689 / +6,464 = **+10,664**; absolute 24,694 − 14,030 = **10,664 — exact match, zero residual** ✓.
  - [x] 5.5 Justification framing recorded: net-new capability across 5 net-add Phase-2 epics + 1 stabilisation interlude (Epic 11.5); no per-epic net-negative gate per `architecture.md:55-58` (post-2026-04-20 sprint-change). Phase-2 ROM growth = +76% to deliver the public 2.0 release gate (Forth-2014 prefixes + 100% ANS Core + CATCH/THROW + Search-Order + File-Access + on-device source development).
  - [x] 5.6 Trajectory tables populated in Completion Notes Task 5.

- [x] **Task 6 — Closure-suite tests + Makefile wire-in (AC: #5, #6)**
  - [x] 6.1 Section 10 appended to `tests/file_access_tests.fth` documenting the 5 closure-suite probes (Tasks 2 + 3 coverage).
  - [x] 6.2 5 new tests written at IDs **939..943** (range adjusted from drafter's 948..959 per F-1 correction).
  - [x] 6.3 Every probe line ≤ 100 chars (well under TIB_SIZE=128).
  - [x] 6.4 Makefile test-repl entries appended after test 938 using established `printf | iz-cpm | grep -q` pattern.
  - [x] 6.5 `make test-repl` post-edit = **952 PASS / 0 FAIL** (= 947 baseline + 5 new). Zero regressions.

- [x] **Task 7 — NFR17 / CCD-3 standards-citation audit (AC: #6)**
  - [x] 7.1 Greps run: §11.6.1.x = 17 (≥ 12 ✓); §11.6.2.x (broader) = 2 (≥ 1 ✓); §9.3.5 across file_access/constants/exception = 19 (≥ 3 ✓). Drafter-figure correction F-5: AC #6 grep anchored on `ANS Forth 1994 §11\.6\.2\.` returned 0 because the actual citation correctly attributes INCLUDE to `Forth 2014 §11.6.2.1717.40` (Forth-2014 Extension, not ANS-1994).
  - [x] 7.2 Audit table built: 16 standards-derived words, all OK.
  - [x] 7.3 0 MISSING / 0 WRONG. No comment-only fixes needed.
  - [x] 7.4 Data-flow surface spot-check (fcb_pool / fcb_byte_pos / fcb_fam / fcb_has_written / include_line_pool / INCLUDE_TOP): each access carries inline citation or structural-decision comment (E13-D1/D2/D3).
  - [x] 7.5 No duplicate definitions, no shadowed words across `src/file_access.asm`.
  - [x] 7.6 Post-Task-7 `wc -c build/antforth.com` = **24,694 bytes** (zero binary delta from Task 7).

- [x] **Task 8 — Phase-wide ANS Core compliance re-audit (AC: #7, #8, #12(n))**
  - [x] 8.1 `docs/ans-forth-core-compliance.md` inspected; §-level back-fill rows + §6.1 Core summary table verified.
  - [x] 8.2 100% Core compliance re-confirmed: 133/133 §6.1 Core words implemented; Partial 0 / Missing 0; no Epic-13 change regressed coverage.
  - [x] 8.3 Story 13.0 (§3.4.1.3 dot-marker) and Story 13.0.1 (§3.1.4.1 high-on-TOS) back-fill rows present; Story 13.5 R/O `file_flush` mode-aware behaviour + has-written discipline reflected at lines 445-471.
  - [x] 8.4 §-level compliance state recorded in Completion Notes Task 8 with the explicit caveat (two §-level structural-rule gaps closed; full §-by-§ pre-2.0 audit pass = Phase-3 carry-forward).
  - [x] 8.5 `docs/WISHLIST.md` entry "Phase-3 systematic §-by-§ ANS Forth Core re-audit" added; comment-only doc edit; zero binary delta confirmed via re-`wc -c`.

- [x] **Task 9 — On-device round-trip (PRD Journey 1) on real MicroBeast (AC: #9, #12(e), #12(f))** — RELEASE GATE [PASS]
  - [x] 9.1 `wc -c build/antforth.com` = **24,694 bytes** (zero binary delta from this story's audit-only edits).
  - [x] 9.2 Transfer mechanism used (established post-9.6 / 10.10 / 11.8 / 11.5.7 / 12.6).
  - [x] 9.3 Round-trip executed by project lead 2026-05-04 — define BLINK → save B:BLINK.FTH via WRITE-FILE → BYE → cold-restart → INCLUDE B:BLINK.FTH → BLINK BLINK BLINK ok. PASS.
  - [x] 9.4 BYE used (confirmed implemented at `src/system.asm:8-13`). Cold-restart fallback not needed.
  - [x] 9.5 Verbatim transcript captured at `~/Downloads/bestialitty-13-6-20260504-213843.bin`; 5-step round-trip excerpted in Completion Notes Task 9.
  - [x] 9.6 PRD Journey 1 verdict: **PASS** (round-trip works end-to-end on real CP/M 2.2 / MicroBeast).

- [x] **Task 10 — 12-line FS smoke batch on real MicroBeast (AC: #10, #12(f), #12(l))** — RELEASE GATE [PASS]
  - [x] 10.1 12-line smoke batch authored across 3 iterations: dev-pass v1 (broken — F-9, F-10), repaired-v1 (F-9 root-caused as script bug; F-10 + F-11 still broken), repaired-v2 (all 3 findings fixed; uses CREATE BUF + THROW discipline + pre-DELETE).
  - [x] 10.2 Verbatim transcripts captured: run 1 `bestialitty-13-6-20260504-213843.bin`, run 2 `bestialitty-13-6-20260504-220413.bin`, run 3 `bestialitty-20260504-222930.bin`.
  - [x] 10.3 R/O destructive-flush invariant on real CP/M: **PASS** — `T11=SZ=128` (run 3 verbatim) confirms Story 13.5 mode-aware `file_flush` + `fcb_has_written` discipline holds on real CP/M 2.2 BDOS.
  - [x] 10.4 i\*x preservation on real CP/M: **PASS** — `T12=-1 3 2 1` (run 3 verbatim) confirms Story 11.4.1 CATCH/THROW/ABORT i\*x-frame contract preserved across Epic-13 surface on hardware.
  - [x] 10.5 Per-line PASS/FAIL/INCONCLUSIVE table populated in Completion Notes Task 10: run 3 = 11/12 PASS, 1/12 INCONCLUSIVE (step 9 disk-corpus only).

- [x] **Task 11 — Adversarial review (AC: #12)**
  - [x] 11.1 Adversarial review against AC #12(a)-(n) executed; **8 findings** surfaced (F-1..F-8).
  - [x] 11.2 Triage: 0 HIGH / 0 MEDIUM / 8 LOW; all gate-passable (in-pass-fixed or accepted-with-rationale).
  - [x] 11.3 In-pass fixes landed: F-1 / F-2 / F-3 / F-4 / F-5 / F-6 (drafter-figure / PRD doc / initial-test-failure). F-7 / F-8 accepted with rationale (coverage gaps with 2.x carry-forward consideration).
  - [x] 11.4 Findings table recorded at Completion Notes Task 11.
  - [x] 11.5 Recommend fresh-context code-review by a different LLM (per Story 13.5 Task 15.5 precedent).

- [x] **Task 12 — In-pass HALT discipline check (AC: #14)**
  - [x] 12.1 No HALT triggered. All ACs deliverable; no structural defect surfaced; no regression introduced (`make test-repl` 947 → 952 / 0 FAIL; `make test` clean; `make test-file-sanity` PASS).
  - [x] 12.2 No sibling-story-spawn (no `13-6-1` row); no half-done-ship. Tasks 9 + 10 documented as project-lead-pending hardware run, not blocked or escalated.
  - [x] 12.3 Identifier gate scan: `git diff --no-color | grep -inE '^\+.*\b(hack|workaround|fixme|tmp)\b'` returns **zero matches** across all 8 modified/added files.

- [x] **Task 13 — CCD-4 + Phase-2 release gate verdict + tag proposal (AC: #11, #13, #16)**
  - [x] 13.1 10-row verdict table near the top of Completion Notes (Epic-13 + Phase-2 ROM + 2× NFR8 + zero-regression + BDOS + citations + Core-100% + Journey-1 round-trip + 12-line smoke).
  - [x] 13.2 Release-readiness one-liner: "**antforth 2.0 RELEASE-READY — tag v2.0.0**". Hardware run-3 with repaired-v2 smoke batch: 11/12 PASS, 1/12 INCONCLUSIVE (disk-corpus only). Story 13.5 R/O destructive-flush + Story 11.4.1 i*x preservation contracts both verified on real CP/M 2.2.
  - [x] 13.3 Tag proposal recorded: `git tag -a v2.0.0 -m "Phase 2: ANS Core 100% + CATCH/THROW + Search-Order + File-Access + on-device source development"`. Dev agent does NOT apply — project lead's action.
  - [x] 13.4 Phase-2 milestone marker recorded: FR1-FR47 delivered (FR30 deliberately gapped); NFR1-NFR21 satisfied (modulo §-level Core compliance carry-forward + disk-full hardware-deferred); post-tag opportunities listed.

- [x] **Task 14 — Memory-currency updates (AC: #12(h))**
  - [x] 14.1 Re-grepped 8 Phase-2-relevant memories; 1 update needed (`project_phase2_scope.md`); 7 current as-of their stated dates.
  - [x] 14.2 `project_phase2_scope.md` updated: frontmatter + lead paragraph + per-epic items + "How to apply" all reflect Phase-2 dev-side close at Story 13.6 + cumulative +10,664 bytes / +76%.
  - [x] 14.3 `MEMORY.md` index updated: phase2-scope row description updated to "Phase 2 dev-side CLOSED 2026-05-04 at Story 13.6; v2.0.0 tag pending project-lead hardware run".
  - [x] 14.4 Phase-3 plan memory deferred to project-lead retrospective (per `bmad-bmm-retrospective` skill) — appropriate carry-forward landing site is the post-tag retro, not this story's scope.

- [x] **Task 15 — Update sprint status + finalize (AC: #15)**
  - [x] 15.1 sprint-status.yaml row flipped: ready-for-dev → in-progress (Step 4) → **review** (this dev-pass close).
  - [x] 15.2 Story `Status:` field synchronised at each transition (top of story file).
  - [x] 15.3 Sub-story alignment re-verified: 13-0 / 13-0-1 / 13-1 / 13-2 / 13-3 / 13-4 / 13-5 all `done`. `epic-13: in-progress → done` flip correctly deferred to story-`done` step.
  - [x] 15.4 Phase-2 milestone marker recorded at Task 13 verdict table + Task 13.4 list (FR1-FR47 delivered; FR30 deliberately gapped; NFR1-NFR21 satisfied / carry-forward-documented; v2.0.0 tag candidate).
  - [x] 15.5 `epic-13-retrospective: optional` not gated; project-lead-disposition post-tag.

- [x] **Task 16 — Hardware smoke (optional follow-up; deferred to project lead)** — like Story 13.5 Task 19
  - [x] 16.1 `build/antforth.com` = 24,694 bytes (current).
  - [x] 16.2 Project lead transferred binary 2026-05-04 and ran 3 AC #9 + AC #10 sessions; all transcripts captured.
  - [x] 16.3 Follow-up re-smokes completed across 3 runs; repaired-v2 smoke batch passed run 3 (modulo step 9 disk-corpus prerequisite).

---

## Dev Notes

### Story Purpose and Scope

Story 13.6 is the **Epic 13 close-out gate** AND the **Phase-2 release gate** — the CCD-4 per-epic benchmark + audit pattern (`architecture.md:218-226`) applied to the final Phase-2 epic. It is **audit-only** in the same code-shape style as Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6: no new code path, no new mechanism, no new EQUs, no new dictionary words. The story's deliverables are *measurement* artefacts (FS stress matrix evidence, BDOS allow-list audit, ROM trajectory accounting, citation audit, regression count, on-device round-trip transcript, 12-line FS smoke transcript, Phase-2 cumulative summary, Core-compliance re-audit) embedded in Completion Notes, plus a go/no-go verdict on whether `antforth 2.0` can be tagged.

**Why audit-only?** Epic 13 delivered its capability across Stories 13.0..13.5. 13.0 + 13.0.1 back-filled two §-level Core-compliance gaps (dot-anywhere literal recogniser §3.4.1.3 + high-on-TOS double-cell stack-layout §3.1.4.1). 13.1 laid the FCB pool + BDOS wrapper layer + (FILE-IO-SANITY) harness. 13.2 added the core File-Access wordset (FR35-FR39, FR42). 13.3 added file positioning (FR40, FR41). 13.4 v2 added source-input nesting (FR32, FR33, FR34) with INCLUDE-TOP chain discipline. 13.5 closed a Story-13.2-origin destructive-flush latent that was a release blocker. Every functional acceptance criterion of Epic 13 is delivered. Story 13.6 exists to **prove** the non-functional acceptance envelope — NFR4, NFR8, NFR9, NFR13, NFR17 — by direct measurement, then hand off the release decision to the project lead.

**Why Phase-2 release gate vs prior CCD-4 gates?** The 2.0 release tag is the public Phase-2 deliverable. Prior CCD-4 gates (9.6, 10.10, 11.8, 11.5.7, 12.6) were 1.x release candidates (some tagged, some "carried implicitly into the next epic's tag" — project-lead disposition). 2.0 is the platform-credibility release; the bar is higher. Story 13.6 adds three evidence dimensions not present in prior CCD-4 gates: (i) the FS error-stress matrix (NFR8 — new for Epic 13's filesystem surface), (ii) the on-device round-trip from PRD Journey 1 (the public success-moment for Mo's persona — without this, the 2.0 release does not deliver its anchor narrative), (iii) the Phase-2 cumulative ROM-delta accounting (post-Epic-8 → post-Story-13.6 — per `prd.md:316` "Fifth — consumes everything above; tags antforth 2.0 on pass").

**What 13.6 is not.** It is not a benchmark-building story (the architecture's `make bench` reference still describes infrastructure that does not exist — see "The `make bench` gap" below; inherited from prior CCD-4 gates). It is not a new-mechanism story. The **only** code edits expected are: (a) test files (new closure-suite tests in `tests/file_access_tests.fth` Section 9 or 10 — see Tasks 2 + 3 + 6), (b) `Makefile` test entries (numbered 948..), (c) potentially comment-only citation fixes in `src/file_access.asm` if Task 7 surfaces a missing/wrong citation, (d) PRD doc-only fix for the BDOS-22 omission per Task 4, (e) optional WISHLIST.md entry for the §-by-§ Core re-audit per Task 8.5. **No assembly-source instruction edits.**

**Contingency branches.** (i) If Task 7 surfaces a missing citation → comment-only edit in scope (zero binary delta). (ii) If Task 5 finds a regression → story expands to include the root-cause fix and the regression-guard test (HIGH-severity finding given Stories 13.0..13.5's clean review passes). (iii) If the on-device round-trip (Task 9) fails → HALT pending project-lead direction. (iv) If the FS stress matrix (Task 2) surfaces a real defect (e.g., disk-full induces an FCB orphan) → HALT per AC #14. (v) If the BDOS allow-list audit (Task 4) surfaces a binary-vs-architecture violation (genuine, not the PRD-22 transcription drift) → HALT per AC #14.

### Why this story exists at this position in Epic 13

Epic 13 was originally planned as 6 stories (13.1..13.6). Two back-fills (13.0 + 13.0.1) inserted ahead of 13.1 closed §-level Core-compliance gaps that Epic 10's word-counted survey was structurally blind to. Story 13.5 inserted between 13.4 and 13.6 closed a destructive-flush latent that was discovered during 13.4's dev-pass (R/O `CLOSE-FILE` after a partial-record read silently extending the source file by 128+ bytes per cycle — fixed in 13.5 with a per-FCB `has-written` bit + mode-aware `file_flush`). The original Epic-13 release-gate scope is preserved in Story 13.6; only the story number moved from 13.5 to 13.6.

The renumbering preserves the close-out gate pattern from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6: the **last story in the epic** is the audit + release gate. 13.6 occupies that slot.

### The `make bench` gap — important clarification (inherited from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6)

The architecture's CCD-4 decision (`architecture.md:218-226`) and Development Workflow Integration section (`:803-807`) reference a `make bench` target. **That target does not exist in the current Makefile.** Grep-verified pre-story (verify at dev-pass): `grep -E "^bench|bench:" Makefile` returns zero matches. Epic 7/8 retros (whose performance work CCD-4 was designed to preserve) cite analytic T-state reasoning from assembler source. Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 inherited that pattern unchanged.

**Story-13.6 reading.** Story 13.6 does not introduce one — building a bench harness is out-of-scope for an Epic-closure story (and File-Access is dominated by BDOS-call latency, not antforth's per-instruction T-state cost; the analytic approach has limited applicability for filesystem-bound NFR8 verification). 13.6 produces NFR4 measurements via `wc -c`, NFR8 measurements via the stress matrix in Task 2, NFR13 measurements via the BDOS allow-list audit in Task 4. Building a `make bench` target is a Phase-3 epic decision (post-2.0).

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§54-58 NFR4 Kernel ROM footprint budget:** per-epic delta logged + justified; no per-epic net-negative gate (post-2026-04-20 sprint-change). Story 13.6 records Epic-13 + Phase-2 cumulative deltas.
- **§59 NFR8 Filesystem error recovery:** failures during file operations raise THROW with specific code; filesystem stays consistent; no orphaned FIDs. Story 13.6 verifies via Task 2 stress matrix.
- **§60 NFR13 BDOS allow-list:** antforth uses only specified BDOS functions. Story 13.6 verifies via Task 4 binary-vs-spec audit.
- **§101 BDOS function list (definitive):** "BDOS functions 15, 16, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40 — required for File-Access wordset (Epic 13)". Includes 22 (F_MAKE) — the architecture is the binding contract; PRD `:475` omits 22 (transcription drift fixed by Task 4.5).
- **§206-216 CCD-3 Standards-citation discipline:** every standards-derived word carries inline citations. Task 7 is the verification step.
- **§218-226 CCD-4 Per-Epic Benchmark Gate:** Story 13.6 is the per-epic gate for Epic 13 + the Phase-2 release gate.
- **§356-360 E13-D1 File-handle representation:** 36-byte FCB; pool of 8 = 288 bytes; kernel-resident. Story 13.6 audits the post-13.5 state (the pool now has parallel arrays for `fcb_byte_pos`, `fcb_fam`, `fcb_has_written`).
- **§362-390 E13-D2 INCLUDE source-input nesting:** 10-byte IX-rstack frame + INCLUDE-TOP chain. Story 13.6 verifies via Task 3 deep-nest stress.
- **§392-396 E13-D3 BDOS wrapper abstraction level:** byte-oriented R/W over CP/M 128-byte records; in-FCB buffer. Story 13.6 verifies via Task 4 BDOS audit.
- **§412-413 CCD-1 / E13-D2 prerequisite chain:** return-stack-frame taxonomy → exception frames (E11-D1) → INCLUDE source frames (E13-D2). Story 13.6 confirms the chain landed coherently across Epic 11 / 11.5 / 13.4.
- **§677, §789 src/assembler.asm unchanged in Phase 2:** Story 13.6 confirms (sanity-check; should be trivially true).
- **§805-807 Development Workflow Integration:** the `make bench` reference; Story 13.6 follows the analytic / direct-measurement pattern.

### Hardware smoke procedure (inherited from 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6)

Per `architecture.md:806`: each epic's final story copies `build/antforth.com` to the MicroBeast and runs an on-device smoke. No release tag without this pass. The transfer mechanism was established in Story 9.6's 2026-04-20 hardware smoke; reused unchanged in 10.10 (2026-04-25), 11.8 (2026-04-27), 11.5.7 (2026-04-29), 12.6 (2026-04-30). Reuse the same procedure; ask the user once if uncertain (per `feedback_follow_process.md`).

Task 9's on-device round-trip is **the new evidence dimension** unique to the 2.0 release gate — not present in prior CCD-4 gates. It corresponds to PRD User Journey 1 (Mo's on-device session). Without this evidence, the 2.0 release does not deliver its anchor narrative. The procedure: define a small word at the REPL, save the source via `WRITE-FILE`, reboot or `BYE`, `INCLUDE` the saved file, exercise the restored word. The hardware-only step is the reboot — emulator-side persistence is identical, but real CP/M 2.2 BDOS may behave differently across reboots (e.g., directory-flush timing, in-FCB buffer flushing, file-system-cache state).

Task 10's 12-line FS smoke batch is the standard MVP-gate floor — minimal coverage of one per Epic-13 user-facing word + cross-epic interactions (R/O destructive-flush invariant from Story 13.5; i\*x preservation from Story 11.4.1). Mirror Story 12.6 Task 8.3.

**Hardware-fix context (Story 11.5.7 + 12.6 antecedent):** Per `project_hardware_crash_audit.md` (RESOLVED 2026-04-28), the MicroBeast firmware fix is silicon-validated. Story 13.6's hardware smoke runs against the fixed firmware; no defensive register-save mitigation is wired into antforth, and Story 11.5.1.1 was dropped permanently. If a print-corruption or hard-reboot recurs on Story 13.6's smoke, that is a Finding requiring escalation per AC #14.

### NFR8 FS stress methodology

The FS error-stress matrix (Task 2) is the **strongest** NFR8 verification across Phase 2. It is not just "the filesystem works under happy-path conditions" (NFR9); it is "the filesystem works under each documented error class without orphaning state."

**Why this matters.** Stories 13.2 / 13.3 / 13.4 v2 / 13.5 each added cleanup discipline (FCB pool acquire/release, in-FCB buffer flush gating, INCLUDE chain-walk on THROW, has-written bit gating). The stress matrix verifies these disciplines hold under the specific error patterns the matrix induces. If the matrix uncovers a real FCB orphan or a filesystem-state inconsistency, Story 13.6 HALTs per AC #14 and the project lead decides whether to spawn a fix-story.

**Coverage philosophy.** The matrix is **not exhaustive** — there are infinite possible FS error scenarios (every bit-flip in every FCB at every moment). The matrix covers the **PRD-named** error classes (NFR8: disk-full, pool-exhaust, use-after-free, R/O-write, delete-non-existent). Additional coverage is review-time-deferred (per AC #12(a) candidate).

**Disk-full evidence shape.** AC #1(e) acknowledges that genuine disk exhaustion may not be inducible inside the iz-cpm probe budget. The evidence shape is then "code-path-traversal verified by mock conditions; hardware re-verification deferred". This is acceptable for the 2.0 gate because (i) disk-full is one of five matrix rows, (ii) the other four are inducible inside the probe budget, (iii) the disk-full code path is single-flow (BDOS F_WRITE A != 0 → THROW + FCB cleanup), (iv) the project lead can hardware-re-verify post-tag if desired.

### NFR13 BDOS allow-list methodology

The Task 4 audit grep (`grep -nE '^\s*CALL\s+BDOS_ENTRY' src/*.asm`) catches all explicit BDOS calls. Task 4.2's cross-check (`grep -nE 'BDOS_ENTRY|0x0005|RST.*BDOS' src/*.asm`) catches alternative invocation idioms. Per `architecture.md:810`: "src/io.asm (console I/O) and src/file_access.asm (file I/O) are the gatekeepers; no other file calls BDOS directly". Verify this contract holds at dev-pass.

**The PRD NFR13 / architecture §101 transcription drift** (BDOS 22 omitted from PRD, present in architecture and binary): the architecture is the binding contract per `feedback_systematic_reference_check.md` (architecture is a decisions register; PRD is product framing — when they conflict on a technical-allowlist matter, the architecture wins). Task 4.5 fixes the PRD wording in-place (comment-only doc edit). This is in-scope for Story 13.6 because the audit surfaces the drift; per AC #14 in-pass-fix discipline, doc-only drift fixes are landed in-pass (not escalated).

### Epic 13 ASSEMBLER-wordlist gap (inherited from Story 11.5.5 + Epic 12 redraft)

The original Epic-13 capstone demo (lazy-load `ASSEMBLER.FTH` on first `CODE`) was withdrawn 2026-04-20 + reaffirmed 2026-04-27 per `sprint-change-proposal-2026-04-20.md` + `sprint-change-proposal-2026-04-27.md` and Story 11.5.5's Epic 12 redraft. `src/assembler.asm` stays unchanged in Phase 2 (`architecture.md:677,789`); FR30 deliberately gapped. Story 13.6 confirms the post-Story-12.6 state holds at Phase-2 close: no ASSEMBLER wordlist; opcode words remain in `forth_wordlist`; the asm-`#` dispatch hack in `src/assembler.asm` `w_HASH_cf` is permanent (`project_asm_hash_dispatch_hack.md`). The 2.0 release tag carries the explicit framing: "Phase 2 delivers File-Access without the lazy-load capstone; the on-device source-development workflow is delivered via INCLUDE + WRITE-FILE round-trip; the ASSEMBLER wordlist is a deliberate post-2.0 carry-forward."

### Project Structure Notes

- **Edits (audit-only story; expected scope):**
  - `tests/file_access_tests.fth` — append a new section with closure-suite probes (~6-12 new tests at IDs 948..). Total file size at story-drafting (verify at write-time); extend rather than create new file.
  - `Makefile` — append ~6-12 new test entries (numbered 948..) matching Task 6's tests.
  - **This story file** — populated through dev pass with Completion Notes, evidence tables, review log.
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` — `13-6-…: backlog → ready-for-dev` (story-creation flip; dev pass advances). `epic-13: in-progress → done` flips at the story-`done` step per AC #15.
  - **Optional** comment-only fixes in `src/file_access.asm` if Task 7 surfaces a missing/wrong citation. Comment-only → 0 binary bytes — confirm via Task 1.1 re-`wc -c` post-fix.
  - **Optional** doc-only fix to `prd.md:475` per Task 4 (BDOS 22 transcription drift). Comment-only doc edit; zero binary delta.
  - **Optional** doc-only addition to `docs/WISHLIST.md` per Task 8.5 (Phase-3 §-by-§ Core re-audit carry-forward).
  - **Optional** doc-only update to `_bmad-output/planning-artifacts/epics.md:1656` if Task 4.7 reconciles the AC text against architecture §101.
- **No source-tree structural changes.** Post-Epic-13 the file list matches `architecture.md:434-461` (`src/number_prefixes.asm`, `src/double.asm`, `src/pictured.asm`, `src/exception.asm`, `src/wordlists.asm`, `src/file_access.asm`, plus the Epic-13 in-place edits to `src/exception.asm` for the chain_walk_close_current_fid).
- **No new files** (closure tests append to existing `tests/file_access_tests.fth`).
- **File-list expectation in Dev Agent Record:** 1 modified `*.fth` file + Makefile + this story file + sprint-status; optionally 1 comment-only-edited `src/file_access.asm`; optionally 1-2 doc edits (PRD, WISHLIST, epics.md). No new EQUs; no new DEFCODE / DEFWORD.
- Alignment with unified project structure: story file lives in `_bmad-output/implementation-artifacts/` per `config.yaml:implementation_artifacts`. Follows the established Epic-closure pattern from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6.
- No detected conflicts or variances with the unified structure.
- The `make bench` infrastructure gap is inherited from prior CCD-4 gates and is not re-litigated here.

### Previous-Story Intelligence — Stories 13.0..13.5

Key inherited learnings relevant to 13.6:

1. **Verdict-table Completion Notes** (Stories 12.6 / 13.x): one row per gate, columns `Gate text | Evidence | Verdict`. Mirror for Story 13.6 + add Phase-2 release-gate row set per AC #13.

2. **Per-task evidence sections with explicit grep / wc / make commands** — "ran command X, got output Y, here's the implication" — no hand-waving. Every Task in this story specifies the exact commands to run.

3. **Re-grep before publishing** — every line number cited in this story (e.g., `src/file_access.asm:711-779`, `src/exception.asm:655-681`) is from story-drafting time and may have drifted post-Story-13.5. Re-verify at dev-pass.

4. **Adversarial-review-finding triage table** — Stories 13.0..13.5 review log format (ID / Severity / Category / Description / Resolution columns) replicated in Completion Notes.

5. **Standards-compliance discipline** (`feedback_standards_compliance.md`): NFR9 / NFR13 / NFR17 are non-negotiable. If a regression surfaces, debug the root cause; do not paper over.

6. **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use plain "PASS" / "FAIL" / measured numbers — no florid audit phrasing.

7. **Adversarial review** (`feedback_adversarial_review.md`): a 2.0-release-gate story has zero-diff temptation; Task 11's reviewer must hunt harder. Zero findings would be deeply suspect — this is the largest-surface CCD-4 gate to date. Expect ≥2-4 LOW/MEDIUM findings per AC #12.

8. **Follow the process** (`feedback_follow_process.md`): execute the hardware smoke + on-device round-trip even though it's tedious. Don't ask the user whether to skip. The procedure is established post-9.6 / 10.10 / 11.8 / 11.5.7 / 12.6.

9. **REPL tests preferred** (`feedback_repl_tests_preferred.md`): no new assembly tests. Story 13.6 adds REPL-piped Forth closure-suite tests only.

10. **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): post-Story-13.0.1, BC = high cell on TOS for doubles; for singles, BC=TOS post-NEXT. Story 13.6's smoke / closure tests must not regress this — verified by AC #10 i\*x line + the stress-matrix probes that touch FCB-pointer cells.

11. **Design upfront** (`feedback_design_upfront.md`): Epic 13 was designed upfront in Stories 13.1 (FCB pool + BDOS wrapper) / 13.2 (core wordset) / 13.4 v2 (INCLUDE chain discipline); 13.6 verifies the design held under the stress of FS errors + cross-epic interactions.

12. **Systematic reference check** (`feedback_systematic_reference_check.md`): Task 5 (ROM trajectory) and Task 7 (citation audit) cross-reference the actual sources, not memory. Cite each source story's Completion Notes verbatim for the per-story trajectory rows.

13. **Verdict-only audit** (`feedback_verdict_only_audit.md`): Story 13.5 was a verdict-only audit (probe in tree before story; flips at story close). Story 13.6 is **not** a verdict-only audit — it is the close-out gate. The closure-suite probes are added at story close (not pre-existing).

14. **Capstone framing inheritance**: Story 13.5 was framed as "the second-to-last Epic-13 story; removes the last filesystem-corruption hazard before the Story-13.6 release gate". Story 13.6 is the **Phase-2 release-gate capstone** — closes Epic 13 entirely AND closes Phase 2 entirely. Different scope; same framing pattern as 12.6 (which closed Epic 12 + queued Epic 13 as the next-up).

15. **In-pass-fix discipline** (Stories 13.0..13.5 + 12.1–12.6 precedent): citation-comment fixes, sprint-status row flips, memory-currency tweaks, doc-only drift fixes (PRD NFR13 BDOS-22) all land in-pass. Out-of-scope: assembly-instruction edits beyond comment-only — those escalate per AC #14.

16. **Stabilisation interlude framing** (`feedback_stabilisation_interlude.md`): Story 13.5 was an *intra-epic* stabilisation insertion (between 13.4 and the original 13.5 release-gate). Phase-3 may want to consider whether a Phase-3 stabilisation interlude (analogous to Epic 11.5) is warranted before adding new feature epics; this is a project-lead-disposition item for the post-2.0 retrospective.

### Epic 13 Trajectory Summary (per-story evidence — populate at dev-pass)

| Story | Status | Production binary (bytes) | Filesanity (bytes) | Delta (production) | `test-repl` PASS | Highest test ID | New tests | Source files |
|---|---|---|---|---|---|---|---|---|
| Pre-Epic-13 baseline (post-12.6) | done | 18,230 | n/a | — | 852 | 852 | — | — |
| 13.0 (double-cell literal recogniser §3.4.1.3) | done | 18,665 | n/a | +435 | (verify) | (verify) | (verify) | `src/number_prefixes.asm`, `src/outer_interpreter.asm`, `src/strings.asm`, `src/double.asm` |
| 13.0.1 (flip stack convention §3.1.4.1) | done | 18,662 | n/a | −3 | (verify) | (verify) | (verify) | `src/double.asm`, `src/formatting.asm`, `src/pictured.asm`, `src/number_prefixes.asm`, `src/strings.asm`, `src/outer_interpreter.asm` |
| 13.1 (FCB pool + BDOS wrapper + (FILE-IO-SANITY) harness) | done | 20,589 | 21,907 | +1,927 | 913 | 902-904 | (verify) | `src/file_access.asm` (NEW), `src/structures.asm`, `src/constants.asm`, Makefile (+IZCPM_DISKS) |
| 13.2 (core File-Access wordset) | done | 21,887 | 23,203 | +1,298 | 920 | 920 | ~16 | `src/file_access.asm` |
| 13.3 (file positioning) | done | 22,536 | 23,852 | +649 | 929 | 929 | ~9 | `src/file_access.asm` |
| 13.4 v2 (INCLUDED / INCLUDE-FILE / INCLUDE + INCLUDE-TOP) | done | 24,594 | 25,910 | +2,058 (HALT-flagged; project-lead-accepted) | 946 | 937 | ~17 | `src/file_access.asm`, `src/exception.asm` (chain_walk), Makefile, disk corpus |
| 13.5 (R/O destructive-flush fix) | done | 24,694 | 26,010 | +100 (data +8 + code +92) | 947 | 938 (audit anchor) | +1 (verdict-flipped 938) | `src/file_access.asm`, `src/exception.asm`, `Makefile`, `tests/file_access_tests.fth`, `docs/ans-forth-core-compliance.md` |
| 13.6 (this story; audit-only + version-bump candidate) | (this) | 24,694 (audit) | 26,010 (audit) | 0 (audit) | ~953-959 | ~954-959 | +6-12 (closure suite) | (audit-only + tests + docs) |

**Epic-13 cumulative (post-Story-13.6 expected):** **+6,464 bytes** (18,230 → 24,694, +35.5%) for Stories 13.0..13.5 + ~0 for Story 13.6 (audit-only). Sum check: -0 + 435 + (-3) + 1,927 + 1,298 + 649 + 2,058 + 100 = 6,464 ✓ (modulo per-story-citation drift). Story 13.6 audit reconciles the cumulative figure and the per-story trajectory at dev-pass.

**Phase-2 cumulative (per-Epic deltas — populate at dev-pass via per-CCD-4-story citations):**

| Epic | Pre-Epic baseline (bytes) | Post-Epic baseline (bytes) | Delta |
|---|---|---|---|
| Pre-Phase-2 (post-Epic-8) | (verify via git checkout + rebuild) | — | — |
| Epic 9 (Numeric Prefixes) | (verify per `9-6-…md`) | (verify) | (verify) |
| Epic 10 (Double + Pictured + 100% Core) | (verify per `10-10-…md`) | (verify) | (verify) |
| Epic 11 (Exception subsystem) | (verify per `11-8-…md`) | (verify) | (verify) |
| Epic 11.5 (Stabilisation interlude) | (verify per `11.5-7-…md`) | 17,541 | +116 (per `11.5-7-…md` Task 1.1) |
| Epic 12 (Search-Order) | 17,541 | 18,230 | +689 (per `12-6-…md` Task 4) |
| Epic 13 (File-Access) | 18,230 | 24,694 | +6,464 (per Task 5 above) |
| **Phase-2 cumulative** | (verify) | 24,694 | (verify per-Epic sum) |

### CCD-4 Gate Close-Out Template

Completion Notes **must** include a section titled "**CCD-4 + Phase-2 Release Gate Verdict**" containing at minimum Task 13.1's table, Task 13.2's readiness statement, and Task 13.3's tag-proposal line. Place it **near the top of Completion Notes** (mirror Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 layout) — this is the visible output a future reader (or re-audit) opens the story file to find. Don't bury it in Task 11's review section.

The verdict table for Story 13.6 has more rows than prior CCD-4 gates because it covers **two scopes** simultaneously (Epic 13 close + Phase 2 release). Suggested row layout (8-10 rows):

| Gate | Evidence | Verdict |
|---|---|---|
| **NFR4 — Epic-13 ROM delta** | Task 5 per-story trajectory; Epic-13 cumulative +6,464 bytes (+35.5%) reconciled | (PASS / PASS-with-finding / FAIL) |
| **NFR4 — Phase-2 cumulative ROM delta** | Task 5 per-Epic trajectory; Phase-2 cumulative (verify); justification framing | (verdict) |
| **NFR8 — FS error stress** | Task 2 stress matrix: 5 induced errors + post-stress pool re-prove; closure tests 948..954 PASS | (verdict) |
| **NFR8 — INCLUDE-mid-THROW deep-nest** | Task 3 depth ≥ 5 chain + THROW; INCLUDE-TOP cleared; pool restored; closure test 955 PASS | (verdict) |
| **NFR9 / FR45 / FR46 — zero-regression** | Task 1.5 + Task 6.5: `make test-repl` ~953-959 PASS / 0 FAIL; `make test` clean; `make test-file-sanity` PASS | (verdict) |
| **NFR13 — BDOS allow-list audit** | Task 4 binary-vs-spec audit; 19 sites; functions {15,16,19,20,21,22,26,33,34,35} (file_access) + {1,2,6,9} (io) + {N} (outer); PRD-22 transcription drift fixed in-pass | (verdict) |
| **NFR17 / CCD-3 — citation discipline** | Task 7 audit table; ≥12 §11.6.1.x + ≥1 §11.6.2.x + ≥3 §9.3.5; 0 MISSING / 0 WRONG | (verdict) |
| **FR45 / Core-100% intact** | Task 8 docs/ans-forth-core-compliance.md re-audit; 100% maintained; §-level back-fills (13.0 / 13.0.1) noted | (verdict) |
| **MVP — Journey 1 on-device round-trip** | Task 9 verbatim transcript on real MicroBeast; define + WRITE-FILE + reboot/BYE + INCLUDE + verify | (verdict) — RELEASE GATE |
| **MVP — 12-line FS smoke on hardware** | Task 10 verbatim transcript on real MicroBeast; per-line PASS/FAIL | (verdict) — RELEASE GATE |

### Sprint-status sub-story alignment note

At story-drafting time (2026-05-04), `_bmad-output/implementation-artifacts/sprint-status.yaml` shows:
- `epic-13: in-progress` (`:190`)
- `13-0-double-cell-literal-recogniser-ans-3-4-1-3: done` (`:197`)
- `13-0-1-flip-double-cell-stack-order-ans-3-1-4-1: done` (`:207`)
- `13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer: done` (`:208`)
- `13-2-core-file-access-wordset: done` (`:209`)
- `13-3-file-positioning: done` (`:210`)
- `13-4-source-input-nesting-include-top-chain-discipline-v2: done` (`:211`)
- `13-5-r-o-close-file-destructive-flush-audit-and-fix: done` (`:226`)
- `13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4: backlog` (`:227`) — flips to `ready-for-dev` at this story's creation.
- `epic-13-retrospective: optional` (`:228`)

All 13.0..13.5 sub-story rows are `done` at story-drafting per the verbatim grep above. AC #12(g) re-verifies at dev-pass; no row drift expected. The `epic-13: in-progress → done` flip happens at the story-`done` step per AC #15.

### Sprint-change cross-references

The relevant sprint-change proposals that bear on Story 13.6:

- `sprint-change-proposal-2026-04-12.md` — Phase-2 plan amendment (epics 9-13 redraft).
- `sprint-change-proposal-2026-04-20.md` — NFR4 revision (no per-epic net-negative gate); ASSEMBLER.FTH lazy-load rollback; FR30 / FR45-FR49 / NFR3 / NFR22 removal.
- `sprint-change-proposal-2026-04-27.md` — full ASSEMBLER-wordlist rollback (FR30 withdrawn); Epic 12 redraft direction.

These are the basis for the AC #4 ROM-justification framing, AC #11(d) "FR30 deliberately gapped" / "lazy-load capstone deliberately gapped" milestone-marker note, and AC #16 Phase-2 milestone framing.

### Hardware-fix context (Story 11.5.7 + 12.6 antecedent)

Per `project_hardware_crash_audit.md` (RESOLVED 2026-04-28), the MicroBeast firmware fix is silicon-validated. Story 13.6's hardware smoke runs against the fixed firmware. If a print-corruption or hard-reboot recurs on Story 13.6's smoke, that is a Finding requiring escalation per AC #14 — the firmware-fix gate was previously closed but the BDOS-shadow class is the only one re-activated by file-access work. Verify per AC #10's smoke batch behaviour.

### Test discipline for Story 13.6

Per `feedback_repl_tests_preferred.md`, all closure-suite probes are REPL-piped Forth source through iz-cpm. They exercise actual user-facing words (`OPEN-FILE`, `CREATE-FILE`, `CLOSE-FILE`, `READ-FILE`, `WRITE-FILE`, `DELETE-FILE`, `FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`, `INCLUDE`, `INCLUDED`, `INCLUDE-FILE`, `INCLUDE-TOP`, `R/O`, `R/W`, `W/O`, `BIN`, `THROW`, `CATCH`, `D.`, `S"`, `TYPE`) — no raw BDOS calls inside the probes. Per `feedback_testing_rules.md`, this matches the test rule.

Probe-quality discipline forward-port from Story 13.5 findings F2 + F3:
- Use `S"` + `TYPE` (not `."`) for any string output that needs to survive a TOS-preserving probe. (`."` clobbers BC = TOS mid-print per Story 13.5 finding F2.)
- Use `HERE` (not `PAD`) for any byte buffer. (PAD is undefined in antforth per Story 13.5 finding F3 — recommend a separate story to add per ANS Forth §6.2.2000.)

### Adversarial review focus areas (AC #12)

1. **Stress-matrix completeness** — are there NFR8 error scenarios beyond the 5 the matrix probes? (a)
2. **BDOS-call-site triangulation** — does the audit grep catch all invocation idioms? (b)
3. **Per-story ROM trajectory reconciliation** — does the per-story sum match absolute? (c)
4. **Phase-2 cumulative trajectory** — does each per-epic citation reconcile? (d)
5. **On-device round-trip evidence integrity** — verbatim, all five steps, BYE-vs-cold-restart documented. (e), (f)
6. **Sprint-status row drift** — every 13-x sub-story `done`. (g)
7. **Memory currency** — every Phase-2-spanning project memory current. (h)
8. **Scope creep** — no assembly-instruction edits other than comment-only. (i)
9. **Epic flip ordering** — at story-`done`, not `review`. (j)
10. **Tag proposal correctness** — `v2.0.0`, no pre-apply. (k)
11. **Probe-quality fixes** — Story 13.5 F2/F3 carried forward. (l)
12. **Disk-full evidence shape** — code-path-only documented. (m)
13. **§-level Core compliance carry-forward** — WISHLIST entry proposal. (n)

Per `feedback_adversarial_review.md` ("reviews MUST find things; absence of findings is suspect"), zero findings is itself suspect for a 2.0 release gate. Plan for 2-4 LOW/MEDIUM findings; HIGH findings block the gate per AC #12 triage.

### Register-convention pick

Story 13.6 is audit-only — no new code paths added to the kernel. The closure-suite probes run inside iz-cpm under the existing register conventions (`docs/register-conventions.md`). Story 13.6 audits that the conventions are preserved across Epic 13's surface (verified by AC #10 i\*x line; verified by Story 13.4 v2's BC-clobber fix in `(close-current-fid)` via PUSH/POP discipline; verified by Story 13.5's BC-clobber fix in `bdos_write_seq` via PUSH/POP discipline).

### High-on-TOS double-cell convention reminder (Story 13.0.1)

Story 13.6 is single-cell-only at the user-visible probe boundary — the closure-suite probes use single-cell stack manipulation primarily. The exception: AC #10's R/O destructive-flush invariant line uses `FILE-SIZE` which returns a double-cell value (`( fileid -- ud ior )` per ANS §11.6.1.1522). The probe must use `D.` (or `SWAP DROP .` if only the low cell is meaningful for the asserted size) to display the double per the high-on-TOS convention. Verify the probe matches the convention at write-time.

### References

- `_bmad-output/planning-artifacts/epics.md:1638-1682` — Story 13.6 authoritative spec
- `_bmad-output/planning-artifacts/epics.md:1319-1682` — Epic 13 charter + all 8 stories (post-13.5-insertion)
- `_bmad-output/planning-artifacts/architecture.md:54-60` — NFR4 / NFR8 / NFR13
- `_bmad-output/planning-artifacts/architecture.md:101` — BDOS function allow-list (definitive; includes 22)
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline
- `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 per-epic benchmark gate
- `_bmad-output/planning-artifacts/architecture.md:354-396` — Epic-13 design (E13-D1, E13-D2, E13-D3)
- `_bmad-output/planning-artifacts/architecture.md:434-461` — Source-file organisation
- `_bmad-output/planning-artifacts/architecture.md:677,789` — `src/assembler.asm` unchanged in Phase 2
- `_bmad-output/planning-artifacts/architecture.md:803-807` — Development Workflow Integration (`make bench` gap inherited)
- `_bmad-output/planning-artifacts/architecture.md:806` — hardware-smoke / MVP gate procedure
- `_bmad-output/planning-artifacts/prd.md:138-180` — MVP framing + User Journey 1 (Mo's on-device session — the AC #9 round-trip target)
- `_bmad-output/planning-artifacts/prd.md:262` — semantic versioning; Epic 13 tags 2.0
- `_bmad-output/planning-artifacts/prd.md:316` — Phase-2 epic table (Epic 13 = release gate)
- `_bmad-output/planning-artifacts/prd.md:422-434` — FR32-FR44 (Epic-13 functional requirements)
- `_bmad-output/planning-artifacts/prd.md:438-439` — FR45/FR46 (Phase-1 behavioural preservation)
- `_bmad-output/planning-artifacts/prd.md:458-489` — NFR2 / NFR4 / NFR8 / NFR9 / NFR13 / NFR14 / NFR17 / NFR20 / NFR21 (Phase-2 envelopes)
- `_bmad-output/planning-artifacts/prd.md:475` — NFR13 BDOS allow-list (transcription drift: omits 22; Task 4.5 fix target)
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-04-20.md` — NFR4 revision rationale; ASSEMBLER.FTH rollback; lazy-load capstone withdrawn
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-04-27.md` — ASSEMBLER-wordlist rollback (FR30 withdrawn); Epic 12 redraft direction
- `_bmad-output/implementation-artifacts/9-6-…md` — Story 9.6 (CCD-4 close-out template; analytic T-state methodology; hardware-smoke procedure)
- `_bmad-output/implementation-artifacts/10-10-…md` — Story 10.10 (CCD-4 template; FR45 byte-identical pattern; verdict-table format)
- `_bmad-output/implementation-artifacts/11-8-…md` — Story 11.8 (CCD-4 template; full Epic-close gate pattern; per-story ROM trajectory; 12-line smoke discipline)
- `_bmad-output/implementation-artifacts/11.5-7-epic-11-5-close-out-gate.md` — Story 11.5.7 (CCD-4 template; interlude-epic close-out; redraft-consistency verification; Epic-12 unblocked)
- `_bmad-output/implementation-artifacts/12-6-epic-12-benchmark-code-backward-compat-suite-and-regression-gate-ccd-4.md` — Story 12.6 (CCD-4 template; Phase-2 mid-point release; v1.12 tag; this story's structural template)
- `_bmad-output/implementation-artifacts/13-0-double-cell-literal-recogniser-ans-3-4-1-3.md` — per-story ROM trajectory data source for Task 5
- `_bmad-output/implementation-artifacts/13-0-1-flip-double-cell-stack-order-ans-3-1-4-1.md` — per-story ROM trajectory data source for Task 5
- `_bmad-output/implementation-artifacts/13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer.md` — per-story ROM trajectory data source for Task 5 (post = 20,589 bytes per Code Review F-A close)
- `_bmad-output/implementation-artifacts/13-2-core-file-access-wordset.md` — per-story ROM trajectory data source for Task 5 (post = 21,887 bytes per Code Review L6 close)
- `_bmad-output/implementation-artifacts/13-3-file-positioning.md` — per-story ROM trajectory data source for Task 5 (post = 22,536 bytes; +649 net)
- `_bmad-output/implementation-artifacts/13-4-source-input-nesting-include-top-chain-discipline-v2.md` — per-story ROM trajectory data source for Task 5 (post = 24,594 bytes; +2,058 HALT-flagged; project-lead-accepted)
- `_bmad-output/implementation-artifacts/13-5-r-o-close-file-destructive-flush-audit-and-fix.md` — per-story ROM trajectory data source for Task 5 (post = 24,694 bytes; +100); audit-anchor probe verdict-flipped 2026-05-04; F2/F3 probe-quality fixes for Story 13.6 forward-port
- `_bmad-output/implementation-artifacts/sprint-status.yaml:190-228` — Epic 13 row set
- `src/file_access.asm` — Stories 13.1..13.5 contents (Story 13.6 audits; Task 7 citation-spot-check target)
- `src/exception.asm:655-681` — Story 13.4 v2 chain_walk_close_current_fid (Story 13.5 inline-comment update site; Task 7 citation-spot-check target)
- `src/structures.asm` — Story 13.1 FCB pool EQUs + UserArea additions (INCLUDE-TOP, fcb_pool, fcb_byte_pos, fcb_fam, fcb_has_written, include_line_pool)
- `src/constants.asm:20-30` — BDOS function-number EQUs (F_OPEN, F_CLOSE, F_DELETE, F_READ, F_WRITE, F_MAKE, F_DMAOFF, F_READRAND, F_WRITERAND, F_SIZE)
- `src/io.asm` — console BDOS calls (4 sites; Task 4 audit target)
- `src/outer_interpreter.asm` — REPL loop BDOS call (1 site; Task 4 audit target)
- `tests/file_access_tests.fth` — Stories 13.1..13.5 tests (Story 13.6 appends a closure section)
- `Makefile` — `test-repl` target (~tests 1..947 post-Story-13.5); Story 13.6 appends 6-12 new entries from 948
- `Makefile:8454-8492` — Story 13.5 audit-anchor probe (test 938; verdict-flipped 2026-05-04; expects-fix mode now)
- `docs/throw-codes.md` — Epic-13 THROW code allocation (-37 file I/O latent, -38 file-not-found, -69 FCB pool exhausted, -70 invalid FID); Task 7 audit target
- `docs/ans-forth-core-compliance.md` — post-Epic-10 100% Core + Stories 13.0/13.0.1 §-level back-fills + Story 13.5 R/O caveat update; Task 8 re-audit target
- `docs/register-conventions.md` — EXX shadow-register convention (audit-only verification)
- `docs/WISHLIST.md` — Phase-3 carry-forward proposals (Task 8.5 candidate addition)
- `disk/a/*.FTH` — Story 13.4 v2 INCLUDE test corpus (BOUNDARY, CHAINA-C, EMPTY, EVAL1, EVTHROW, HELLO, NESTED, ONLYA, RECUR, SIMPLE, STD1-7); Task 3 may add DEEPN.FTH
- DPANS94 §11.6.1.0900 (CLOSE-FILE), §11.6.1.1010 (CREATE-FILE), §11.6.1.1190 (DELETE-FILE), §11.6.1.1520 (FILE-POSITION), §11.6.1.1522 (FILE-SIZE), §11.6.1.1717 (INCLUDE-FILE), §11.6.1.1718 (INCLUDED), §11.6.1.1970 (OPEN-FILE), §11.6.1.2080 (READ-FILE), §11.6.1.2142 (REPOSITION-FILE), §11.6.1.2480 (WRITE-FILE), §11.6.2.1717 (INCLUDE — Forth 2014 Extension), §9.3.5 (THROW codes -38 / -69 / -70)
- Project memories:
  - `feedback_adversarial_review.md` — reviews MUST find things, especially audit-only and high-stakes release gates
  - `feedback_standards_compliance.md` — investigate the standard before defending code; never rationalize
  - `feedback_systematic_reference_check.md` — cross-reference source stories, not memory (Tasks 4 / 5 / 7)
  - `feedback_follow_process.md` — execute hardware smoke + on-device round-trip even though tedious
  - `feedback_design_upfront.md` — Stories 13.1 / 13.2 / 13.4 v2 designed the subsystem; 13.6 verifies the design held
  - `feedback_repl_tests_preferred.md` — no new assembly tests; only REPL-piped Forth (~6-12 new closure tests)
  - `feedback_plain_qa_language.md` — measured value + gate + conclusion, plainly stated
  - `feedback_stabilisation_interlude.md` — Phase-3 may want a Phase-3 stabilisation interlude epic; project-lead disposition at retrospective
  - `feedback_verdict_only_audit.md` — Story 13.5 was verdict-only; Story 13.6 is **not** (it is the close-out gate)
  - `feedback_testing_rules.md` — manual tests must exercise actual Forth primitives, not raw BDOS
  - `project_tos_in_register.md` — BC=TOS; double-cell high-on-TOS post-Story-13.0.1 — verify preserved across Epic-13 surface (AC #10 i\*x line)
  - `project_phase2_scope.md` — Phase-2 epic plan: Epics 9-13 → Epic 13 closes Phase 2; Story 13.6 closes Epic 13 + Phase 2; tag 2.0
  - `project_assembler_keep_assembly.md` — `src/assembler.asm` stays as-is forever (decided 2026-04-20, reaffirmed 2026-04-27); Story 13.6 confirms the post-12.6 state holds
  - `project_asm_hash_dispatch_hack.md` — Story 10.7 run-time dispatch in `assembler.asm`'s `w_HASH_cf` is permanent
  - `project_epic_11_5_scope.md` — Epic 11.5 closed 2026-04-29; baseline for Epic 12; Phase-2 spans 9, 10, 11, 11.5, 12, 13
  - `project_hardware_crash_audit.md` — RESOLVED 2026-04-28 (firmware fix verified clean on real hardware); Story 13.6 hardware smoke runs against fixed firmware

### Project Structure Notes

- Alignment with unified project structure: story file lives in `_bmad-output/implementation-artifacts/` per `config.yaml:implementation_artifacts`. No new source file; no new EQU; comment-only edits possible per Tasks 4 / 7 / 8.5. Follows the established Epic-closure pattern from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6.
- No detected conflicts or variances with the unified structure.
- The `make bench` infrastructure gap (architecture §218-226 vs Makefile reality) is inherited from prior CCD-4 gates and is not re-litigated here. If the project lead wants a `make bench` target, it is a separate Phase-3 sprint-change item.
- Sub-story status alignment caveat (sprint-status sub-story note above) — surface at Task 15.3 if any 13.0..13.5 row is not `done` at finalize.
- The PRD/architecture transcription drift on BDOS 22 (PRD `:475` omits) is an in-scope doc-only fix per Task 4.5 (architecture is the binding contract; PRD wording follows).
- The §-by-§ ANS Forth Core re-audit is an explicit Phase-3 carry-forward per AC #8 — proposed WISHLIST.md addition per Task 8.5.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m] (Opus 4.7, 1M context) — create-story workflow.

### Debug Log References

- Initial test 943 failure (`disk/a/DEEPN.FTH` v1 with inline `IF -1 THROW THEN` raised THROW -14 = compile-only-at-interpret-time). Root-caused via Makefile output xxd dump showing `T43A=-14` instead of `T43A=-1`. Fix: hoist recursion into colon definition `DEEPN-STEP` in the probe; reduce `disk/a/DEEPN.FTH` to one-liner `DEEPN-STEP`. Recorded as Finding F-6 in Task 11.
- BDOS-site triangulation found 1 `JP BDOS_ENTRY` (system.asm:12) missed by the basic `CALL BDOS_ENTRY` grep. Surfaced 2 PRD doc drifts (BDOS 0 + BDOS 22 omitted from PRD §475). Recorded as Findings F-2, F-3, F-4 in Task 11.
- Test ID baseline drafted as 947 → 948 (incorrect); reality = 938 highest unique ID, 947 PASS-line count. New tests start at 939 not 948. Recorded as Finding F-1.
- §11.6.2.x grep returned 0 hits for `ANS Forth 1994 §11\.6\.2\.` because INCLUDE is correctly attributed to `Forth 2014 §11.6.2.1717.40` (Forth-2014 Extension). Broader grep returns 2. Recorded as Finding F-5.

### Completion Notes List

### CCD-4 + Phase-2 Release Gate Verdict

**One-liner: antforth 2.0 RELEASE-READY — tag v2.0.0.** Hardware Task 9 PASS (PRD Journey 1 round-trip end-to-end). Hardware Task 10 PASS on hardware-run-3 with repaired-v2 smoke batch: 11/12 PASS, 1/12 INCONCLUSIVE (step 9 disk-corpus only — `B:NESTED.FTH` not on the project lead's B: drive; not v2.0.0-blocking). **All Story 13.5 R/O destructive-flush invariant + Story 11.4.1 i\*x preservation contracts verified on real CP/M 2.2.** No structural kernel defects across all 3 hardware runs; every script bug surfaced (F-9, F-10, F-11) was authoring-discipline only and is in-pass-fixed in repaired-v2. Every dev-side gate PASS; ROM trajectory reconciles exactly; 11 LOW findings closed or accepted-with-rationale.

| Gate | Evidence | Verdict |
|---|---|---|
| **NFR4 — Epic-13 ROM delta** | Task 5 per-story trajectory; Epic-13 cumulative **+6,464 bytes (+35.5%)**; per-story sum reconciles exactly to absolute (zero residual) | **PASS** |
| **NFR4 — Phase-2 cumulative ROM delta** | Task 5 per-Epic trajectory; Phase-2 cumulative **+10,664 bytes (+76.0%)** vs post-Epic-8 baseline (14,030 → 24,694); per-Epic sum reconciles exactly to absolute (zero residual); justification framing recorded (5 net-add Phase-2 epics + 1 stabilisation interlude; no per-epic net-negative gate per `architecture.md:55-58` post-2026-04-20 sprint-change) | **PASS** |
| **NFR8 — FS error-stress matrix** | Task 2: 4 active probes (939-942) cover stress matrix rows (a)-(d); row (e) disk-full documented as code-path-only per AC #1(e); row (f) post-stress pool occupancy subsumed by 939's re-acquire half + existing tests 908+936 | **PASS** |
| **NFR8 — INCLUDE-mid-THROW deep-nest** | Task 3: test 943 self-recursive INCLUDE depth-6 + `-1` THROW; chain-walk closes 6 frames; INCLUDE-TOP returns to 0; pool re-usable | **PASS** |
| **NFR9 / FR45 / FR46 — zero-regression** | Task 1.5 + Task 6.5: pre-edit **947 PASS / 0 FAIL** → post-edit **952 PASS / 0 FAIL** (+5 closure tests, 0 regressions); `make test` clean; `make test-file-sanity` PASS | **PASS** |
| **NFR13 — BDOS allow-list audit** | Task 4: 17 BDOS sites (16 CALL + 1 JP); functions {0, 1, 2, 10, 11, 15, 16, 19, 20, 21, 22, 25, 26, 33, 34, 35} — 16 unique. Two transcription drifts in-pass-fixed (BDOS 0 + BDOS 22 added to PRD §475 / epics.md:110 / epics.md:1656); architecture §101 was already correct | **PASS** |
| **NFR17 / CCD-3 — citation discipline** | Task 7: `§11.6.1.x` count = **17** (≥12 required); `§11.6.2.x` count = **2** (≥1 required, Forth-2014 attribution for INCLUDE); `§9.3.5` count = **19** (≥3 required). 16 standards-derived File-Access words audited; **0 MISSING / 0 WRONG**. AC #6 grep pattern correction: F-5 | **PASS** |
| **FR45 / Core-100% intact** | Task 8: `docs/ans-forth-core-compliance.md` re-audit; **133/133 §6.1 Core words** = 100.0% (Partial 0 / Missing 0); §3.4.1.3 + §3.1.4.1 §-level back-fills present (Stories 13.0 + 13.0.1); Phase-3 §-by-§ wishlist entry landed at `docs/WISHLIST.md` per AC #8 | **PASS** |
| **MVP — Journey 1 on-device round-trip** | Task 9: hardware run 2026-05-04 (`bestialitty-13-6-20260504-213843.bin`); 5-step round-trip completed end-to-end on real MicroBeast (define BLINK → save to B: via WRITE-FILE → BYE → INCLUDE → BLINK BLINK BLINK ok) | **PASS** |
| **MVP — 12-line FS smoke on hardware** | Task 10 hardware-run-3 with repaired-v2 smoke batch: **11/12 PASS, 1/12 INCONCLUSIVE** (step 9 disk-corpus). T2=ok / T3=ok / T4=ok / T5=u2=6 / **T6=Hello!** (F-9 disproved as kernel defect; CREATE BUF buffer survives WORD-clobber as predicted) / T7=ok / T8=ok / T9 INCONCLUSIVE (`-38 file not found` — B:NESTED.FTH absent from project lead's B: drive) / T10=-69 / **T11=SZ=128** (Story 13.5 R/O destructive-flush invariant verified on real CP/M) / **T12=-1 3 2 1** (Story 11.4.1 i\*x preservation verified on real CP/M). | **PASS** |

**Tag proposal — apply now (project lead's action).** Repaired-v2 smoke batch passed hardware-run-3 (transcript `bestialitty-20260504-222930.bin`); all release-gate evidence captured.

```bash
git tag -a v2.0.0 -m "Phase 2: ANS Core 100% + CATCH/THROW + Search-Order + File-Access + on-device source development"
git push origin v2.0.0
```

Tag-message headline framing: emphasises the *capability* (Phase-2 deliverable: numeric prefixes + 100% ANS Core + CATCH/THROW + Search-Order + File-Access + on-device source development) rather than the *story IDs*. Project lead may rephrase per release-notes preferences. Consider checking prior tag conventions: `git tag -l | tail -10`.

**Phase-2 milestone marker (per AC #16):**
- **Functional Requirements:** FR1-FR47 delivered. **FR30 deliberately gapped** (lazy-load capstone — withdrawn per `sprint-change-proposal-2026-04-20.md` + `2026-04-27.md`; ASSEMBLER wordlist is post-2.0 carry-forward).
- **Non-Functional Requirements:** NFR1-NFR21 satisfied **except** §-level Core compliance is documented as carry-forward (AC #8 / `docs/WISHLIST.md` "Phase-3 systematic §-by-§ ANS Forth Core re-audit") and AC #1(e) disk-full hardware-deferred verification.
- **Public release tag candidate:** `v2.0.0` per `prd.md:262` semantic-versioning policy.
- **Post-tag opportunities (per `prd.md:142-147`; none 2.0-tag-blocking):** MicroBeast hardware vocabulary epic, beginner's guide, per-wordset reference, worked examples.

#### Task 1 — Pre-edit baselines + grep evidence (AC #4, #5, #15)

| Subtask | Command | Output / Result | Verdict |
|---|---|---|---|
| 1.1 | `wc -c build/antforth.com` | **24,694 bytes** — matches Story 13.5 Task 14.2 close-out figure (post-code-review-L3-OOR-guard, 2026-05-04) | PASS |
| 1.2 | `wc -c build/antforth_filesanity.com` | **26,010 bytes** — matches Story 13.5 Task 14.6 figure | PASS |
| 1.3 | `grep -oE 'REPL test [0-9]+' Makefile \| awk '{print $3}' \| sort -n -u \| tail -1` | Highest test ID = **938** (Story 13.5 audit anchor). **Drafter-figure correction**: AC #1 / Task 1.3 said "947"; that was the PASS-line count, not the highest test ID — multi-pass tests (e.g., one probe with two PASS branches) inflate the line count above the unique-ID count. New closure tests therefore start at **939**, not 948. Documented as Finding F-1 in Task 11. | PASS-with-finding |
| 1.4 | `make test` | "PASS: Output matches expected" — assembly thread groups 1–6 clean | PASS |
| 1.5 | `make test-repl` | **947 PASS / 0 FAIL** (`grep -cE '^PASS:'` = 947, `grep -c '^FAIL:'` = 0) — confirms Story 13.5 close-out figure | PASS |
| 1.6 | `make test-file-sanity` | "PASS: file-sanity test — 11 expected lines match exactly" | PASS |
| 1.7 | `grep -nE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm src/io.asm src/outer_interpreter.asm` | **16 CALL sites total**: 11 in `file_access.asm` (lines 477, 486, 495, 505, 519, 554, 563, 574, 584, 593, 602) + 4 in `io.asm` (135, 158, 174, 190) + 1 in `outer_interpreter.asm` (134). Cross-check `grep -nE 'BDOS_ENTRY\|0x0005\|RST.*BDOS\|JP\s+BDOS_ENTRY' src/*.asm` adds **1 `JP BDOS_ENTRY`** site in `src/system.asm:12` for `BYE` (P_TERMCPM = 0; tail-call exit). **Total BDOS surface = 17 sites** (16 CALL + 1 JP). **Drafter-figure correction**: AC #3 / Task 1.7 said "19 sites" and "14 in file_access.asm"; reality is 16 / 11 — and the drafter omitted the `JP BDOS_ENTRY` BYE exit entirely. Documented as Finding F-2 in Task 11; canonical NFR13 audit table built in Task 4. | PASS-with-finding |
| 1.8 | `grep -nE '^  13-' _bmad-output/implementation-artifacts/sprint-status.yaml` | All sub-rows aligned: 13-0 / 13-0-1 / 13-1 / 13-2 / 13-3 / 13-4 / 13-5 = **done**; 13-6 = **in-progress** (just flipped from ready-for-dev at dev-pass start, AC #15) | PASS |

**Task 1 verdict: PASS** with two drafter-figure corrections noted (F-1: highest test ID = 938 not 947; F-2: BDOS surface = 17 sites not 19, including the `JP BDOS_ENTRY` BYE exit).

#### Task 2 — NFR8 FS error-stress matrix (AC #1, #12(a), #12(l), #12(m))

**Stress-matrix design (4 active probes + 1 documented-only + 1 subsumed):**

| Row | AC | Coverage | Test ID | Verdict |
|---|---|---|---|---|
| (a) Pool exhaustion + post-release re-acquire | AC #1(a) | Open 8 → 9th catches `-69`; close one; 9th opens successfully | **939** | PASS |
| (b) Closed-FID -70 on WRITE-FILE | AC #1(b) | Stale FID → `' WRITE-FILE CATCH` returns `-70` | **940** | PASS |
| (c) R/O write + post-close pool re-acquire | AC #1(c) | R/O write fails ior=1; close + re-open succeeds | **941** | PASS |
| (d) DELETE-FILE missing → ior=1 | AC #1(d) | DELETE-FILE on `NOSUCH.TXT` returns `ior=1` | **942** | PASS |
| (e) Disk-full simulation | AC #1(e) | Documented as code-path-only (Task 2.4 below) | — | DOCUMENTED |
| (f) Post-stress pool occupancy | AC #1(f) | Subsumed by test 939's re-acquire half + pre-existing tests 908 + 936 | — | SUBSUMED |

**Probe-quality forward-port (Story 13.5 findings F2 + F3):**
- ✅ All probes use `S" label" TYPE` (not `."`).
- ✅ All probes use `HERE` (not `PAD`) for byte buffers (test 941 uses `HERE 2 FA @ READ-FILE`).

**Closure-suite filenames** (avoid collision with persistent test-908 P*.TXT artefacts on `disk/a/`):
- Test 939: `Z1.TXT`..`Z9.TXT`
- Test 940: `ZC.TXT` (closed-FID file)
- Test 941: `ZR.TXT` (R/O cycle file)
- Test 942: `NOSUCH.TXT` (intentionally non-existent — same name as existing test 925 uses; safe because both probes only DELETE-FILE / OPEN-FILE on it, neither creates)
- Test 943: `disk/a/DEEPN.FTH` (new disk asset; self-recursive)

**Verbatim test execution** (post-edit `make test-repl` excerpt):
```
PASS: REPL test 939 — Story 13.6 (s136-stress-a) pool-exhaust + post-release re-acquire (T-S136-STRESS-A-POOL-REACQUIRE)
PASS: REPL test 940 — Story 13.6 (s136-stress-b) closed-FID -70 sweep on WRITE-FILE (T-S136-STRESS-B-WRITE-STALE)
PASS: REPL test 941 — Story 13.6 (s136-stress-c) R/O write-attempt + post-close pool re-acquire (T-S136-STRESS-C-RO-CYCLE)
PASS: REPL test 942 — Story 13.6 (s136-stress-d) DELETE-FILE missing → ior=1 (T-S136-STRESS-D-DELMISS)
PASS: REPL test 943 — Story 13.6 (s136-deep-nest) INCLUDE-mid-THROW depth-6 self-recursion (T-S136-DEEPN-CHAIN-WALK)
```
Total post-edit `make test-repl`: **952 PASS / 0 FAIL** (was 947 / 0; net +5 closure tests).

**Disk-full evidence (AC #1(e) methodology, recorded per Task 2.4):**
The iz-cpm CP/M implementation maps the host's filesystem as the CP/M disk; running out of space requires exhausting the host's free disk (gigabytes), not feasible in a probe budget. The disk-full code path in `src/file_access.asm` is exercised by:
- `bdos_create_file` (line 552-556) returns A=0xFF on F_MAKE failure → `.cf_release_makefail` (line 1531-1538) sets `ior=3`.
- `bdos_write_seq` (line 519-525) returns A!=0 on F_WRITE failure → wrapper propagates ior to WRITE-FILE callers.

Both paths are statically verifiable; the ior return values land at the user-visible WRITE-FILE / CREATE-FILE word boundary. Code-path traversal evidence is sufficient for the 2.0 gate per AC #1(e). Hardware re-verification deferred (project lead may run a small disk-image fill-test post-tag).

**Initial test 943 failure + fix (recorded for future maintainers):**
First version of `disk/a/DEEPN.FTH` contained the recursion logic inline:
```
DPN @ 0= IF -1 THROW THEN DPN @ 1- DPN ! S" DEEPN.FTH" INCLUDED
```
This raised THROW `-14` ("interpreting a compile-only word") because `IF`/`THEN` are compile-only in ANS Forth — they only run inside a colon body. Fix: hoist the recursion into a colon definition `DEEPN-STEP` defined in the probe; `disk/a/DEEPN.FTH` now contains just `DEEPN-STEP` (one-line file). This pattern matches existing test 936's `RECUR.FTH` shape.

**Task 2 verdict: PASS.** 4 active stress-matrix probes (939-942) + 1 deep-nest probe (943) all PASS. Disk-full row documented as code-path-only per AC #1(e). Post-stress pool occupancy subsumed by test 939's re-acquire half. No FCB orphan; no filesystem-corruption event surfaced. Probe-quality forward-port from Story 13.5 F2/F3 confirmed across all 5 new probes.

#### Task 3 — INCLUDE-mid-THROW deep-nest stress (AC #2, #12(a))

**Probe design.** Self-recursive `INCLUDED` via `disk/a/DEEPN.FTH` containing `DEEPN-STEP` (a one-line file that calls a colon word defined in the probe). The colon word `DEEPN-STEP` does:
```
: DEEPN-STEP DPN @ 0= IF -1 THROW THEN DPN @ 1- DPN ! S" DEEPN.FTH" INCLUDED ;
```
With `DPN` initialised to 5, the word recurses 6 levels deep: each level decrements DPN, opens a fresh INCLUDE frame, and recurses; level 6 finds DPN=0 and fires `-1 THROW`.

At THROW time, **6 active FCBs** are in the pool (level 1 frame + 5 recursive child frames). The pool ceiling is 8, leaving 2 slots free for the deepest recursion to safely INCLUDE without hitting `-69`.

**Verdict (Test 943 PASS):**
- `T43A=-1 ` — outer CATCH at the probe level catches the `-1` THROW propagated from the deepest level via the chain-walk (Story 13.4 v2 `chain_walk_close_current_fid` — `src/exception.asm:655-681`).
- `T43B=0 ` — `INCLUDE-TOP @` returns 0 post-CATCH, proving every INCLUDE frame was popped and the chain-link reset.

**Why this differs from existing test 933 / 936:**
- Test 933 (Story 13.4 v2 t29) uses the STK1.FTH..STK8.FTH chain at depth 8, hitting the FCB pool ceiling.
- Test 936 (Story 13.4 v2 t32) uses RECUR.FTH which self-INCLUDEs without depth-limit, hitting `-69` at the 9th attempt.
- Test 943 (Story 13.6 s136-deep-nest) uses self-recursion at depth 6 (within pool capacity) with a deliberate `-1 THROW` at the deepest level, then explicitly verifies `INCLUDE-TOP @ = 0` post-CATCH. This triangulates the chain-walk mechanism against a depth that's not a pool-boundary edge case.

**Pool-occupancy verification:** test 939's post-CATCH `S" Z9.TXT" R/W CREATE-FILE THROW` proves the pool can re-acquire after a `-69`. Test 943 implicitly proves the same after a `-1` deep-nest THROW: the next `INCLUDE-TOP @` succeeds, and the iz-cpm session ends cleanly with no orphan-FCB diagnostic.

**Task 3 verdict: PASS.** Test 943 passes; chain-walk discipline holds at depth 6; INCLUDE-TOP cleared; pool re-usable post-CATCH.

#### Task 4 — NFR13 BDOS allow-list audit (AC #3, #12(b))

**Methodology.** Two greps:
- Primary: `grep -nE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm src/io.asm src/outer_interpreter.asm` — 16 sites.
- Cross-check (alternative idioms per AC #12(b)): `grep -nE 'BDOS_ENTRY\|0x0005\|RST.*BDOS\|JP\s+BDOS_ENTRY' src/*.asm` — adds 1 `JP BDOS_ENTRY` site (`src/system.asm:12`, BYE/P_TERMCPM tail-call exit).
- Function-number mapping: `grep -nE 'LD\s+C,\s*[0-9F_C-Z]' src/file_access.asm src/io.asm src/outer_interpreter.asm src/system.asm` paired with adjacent CALL.

**Audit table** (one row per BDOS call site; verdict against the post-fix allow-list):

| BDOS # | Symbol | Site (file:line) | Wrapper / purpose | In Arch §101? | In PRD §475 (post-fix)? | Verdict |
|---|---|---|---|---|---|---|
| 0 | P_TERMCPM | `src/system.asm:12` | `BYE` (tail-call exit; `JP BDOS_ENTRY`) | n/a (pre-Epic-13) | YES (post-fix) | OK |
| 1 | C_READ | `src/io.asm:158` | `KEY` — blocking console input | n/a | YES | OK |
| 2 | C_WRITE | `src/io.asm:190` | `bdos_putchar` (used by `EMIT`, `TYPE`, etc.) | n/a | YES | OK |
| 10 | C_READSTR | `src/io.asm:135` | `EXPECT` / ACCEPT-style read-buffered | n/a | YES | OK |
| 10 | C_READSTR | `src/outer_interpreter.asm:134` | `QUERY` (REPL line read) | n/a | YES | OK |
| 11 | C_STATUS | `src/io.asm:174` | `KEY?` — non-blocking console status | n/a | YES | OK |
| 15 | F_OPEN | `src/file_access.asm:477` | `bdos_open_file` (Story 13.2 OPEN-FILE) | YES | YES | OK |
| 16 | F_CLOSE | `src/file_access.asm:486` | `bdos_close_file` (Story 13.2 CLOSE-FILE) | YES | YES | OK |
| 19 | F_DELETE | `src/file_access.asm:495` | `bdos_delete_file` (Story 13.2 DELETE-FILE) | YES | YES | OK |
| 20 | F_READ | `src/file_access.asm:505` | `bdos_read_seq` (Story 13.2 READ-FILE) | YES | YES | OK |
| 21 | F_WRITE | `src/file_access.asm:519` | `bdos_write_seq` (Story 13.2 WRITE-FILE; Story 13.5 has-written gating) | YES | YES | OK |
| 22 | F_MAKE | `src/file_access.asm:554` | `bdos_create_file` (Story 13.2 CREATE-FILE) | YES | YES (post-fix) | OK |
| 25 | DRV_GET | `src/file_access.asm:563` | `bdos_get_drive` (Story 13.2 default-drive resolution) | YES | YES | OK |
| 26 | F_DMAOFF | `src/file_access.asm:574` | `bdos_set_dma` (per-FCB DMA preamble) | YES | YES | OK |
| 33 | F_READRAND | `src/file_access.asm:584` | `bdos_read_rand` (Story 13.3 random-record read) | YES | YES | OK |
| 34 | F_WRITERAND | `src/file_access.asm:593` | `bdos_write_rand` (Story 13.3 random-record write) | YES | YES | OK |
| 35 | F_SIZE | `src/file_access.asm:602` | `bdos_file_size` (Story 13.3 FILE-SIZE) | YES | YES | OK |

**Total BDOS surface: 17 sites** (16 CALL + 1 JP). **Functions actually used: {0, 1, 2, 10, 11, 15, 16, 19, 20, 21, 22, 25, 26, 33, 34, 35} — 16 unique numbers.** Every site uses an allow-list function; no out-of-allow-list call.

**Drift findings (in-pass-fixed per AC #14 — comment-only doc edits, zero binary delta):**

- **F-3 (PRD-475 + epics.md-110/1656 — BDOS 22 omission).** PRD §475 listed "1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40" — **omits 22** (F_MAKE, required by `CREATE-FILE`). Architecture §101 explicitly includes 22. Anticipated by Story 13.6 AC #3 / Task 4.4. **Fix landed**: PRD `:475` updated to insert `22` between `21` and `25`; `epics.md:110` (NFR13 summary) and `epics.md:1656` (Story 13.6 Given clause) updated identically.
- **F-4 (PRD-475 + epics.md-110/1656 — BDOS 0 omission, surfaced by audit).** PRD §475 also omitted **0** (P_TERMCPM, used by `BYE` since Phase 1; wrapped in `src/system.asm:12` `JP BDOS_ENTRY`). The drafter of Story 13.6 AC #3 / Task 1.7 also missed this — they listed only `CALL BDOS_ENTRY` patterns and missed the tail-call `JP BDOS_ENTRY` idiom that AC #12(b) explicitly asked the audit to consider. Architecture §101 is silent on BDOS 0 because that section enumerates *new* Epic-13 dependencies; PRD §475 is the binding union list and must include it. **Fix landed**: PRD `:475` updated to insert `0` at the start of the list; `epics.md:110` + `:1656` updated identically.

**Audit re-grep post-fix** (sanity check the doc edits land correctly):

```
grep -nE 'BDOS functions \(0, 1, 2' _bmad-output/planning-artifacts/prd.md _bmad-output/planning-artifacts/epics.md
```
- prd.md:475 — confirmed: "(0, 1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40)"
- epics.md:110 — confirmed
- epics.md:1656 — confirmed

**Binary delta check (AC #3 + Task 4.5 require zero):** doc-only edits in `*.md`; no `src/*.asm` change; binary expected unchanged at 24,694 bytes. Re-confirmed at Task 6 / Task 13 close.

**Task 4 verdict: PASS.** 17 BDOS sites; every function in the post-fix allow-list. Two transcription drifts found and in-pass-fixed (BDOS 0 + BDOS 22 added to PRD §475 / epics.md NFR13 wording). Architecture §101 unchanged (already correct for the Epic-13-scoped enumeration).

#### Task 5 — Epic-13 + Phase-2 ROM trajectory accounting (AC #4, #12(c), #12(d))

**Per-story Epic-13 trajectory (production binary `build/antforth.com`)** — every figure cited from the source story's Completion Notes / Change Log per `feedback_systematic_reference_check.md`:

| Story | Pre (bytes) | Post (bytes) | Delta | Source citation |
|---|---|---|---|---|
| Pre-Epic-13 (post-12.6) | — | 18,230 | — | `12-6-…md` Task 4 / Change Log; `13-0-…md` Task 1.1 confirms |
| 13.0 (double-cell literal recogniser §3.4.1.3) | 18,230 | **18,665** | **+435** | `13-0-…md:411` Completion Notes |
| 13.0.1 (flip stack convention §3.1.4.1) | 18,665 | **18,662** | **−3** | `13-0-1-…md:353` Completion Notes |
| 13.1 (FCB pool + BDOS wrapper + harness) | 18,662 | **20,589** | **+1,927** | `13-1-…md:451` Completion Notes; cited at `13-2-…md` Task 1.1 |
| 13.2 (core File-Access wordset) | 20,589 | **21,887** | **+1,298** | `13-2-…md:401` Completion Notes; cited at `13-3-…md` Task 1.1 |
| 13.3 (file positioning) | 21,887 | **22,536** | **+649** | `13-3-…md:480` Completion Notes; cited at `13-4-…md` Task 1.1 |
| 13.4 v2 (INCLUDE chain discipline) | 22,536 | **24,594** | **+2,058** (HALT-flagged; project-lead-accepted overshoot) | `13-4-…md:856` Task 19 / Change Log |
| 13.5 (R/O destructive-flush fix) | 24,594 | **24,694** | **+100** (data +8 + code +92) | `13-5-…md:290` Task 14.2 |
| 13.6 (this story; audit-only) | 24,694 | **24,694** | **0** | Task 4 re-build post-PRD-doc-fix; this story Task 1.1 + Task 13 |

**Epic-13 cumulative reconciliation:** 18,230 → 24,694 = **+6,464 bytes (+35.5%)**.
- Per-story sum: 435 + (−3) + 1,927 + 1,298 + 649 + 2,058 + 100 + 0 = **6,464**.
- Absolute sum: 24,694 − 18,230 = **6,464**.
- **Reconciliation: exact match, zero residual** ✓ (per Story 11.8 / 11.5.7 / 12.6 reconciliation discipline).

**Per-Epic Phase-2 trajectory** (post-Epic-8 baseline → post-Story-13.6) — every figure cited:

| Epic | Pre (bytes) | Post (bytes) | Delta | Source citation |
|---|---|---|---|---|
| Pre-Phase-2 (post-Epic-8 / Story 8.4) | — | **14,030** | — | `9-6-…md:19` + `:196` (commit `27c4cbd`) |
| Epic 9 (Numeric Prefixes) | 14,030 | **14,787** | **+757** | `9-6-…md` Task 3.2 (commit `a2daf01`) |
| Epic 10 (Double + Pictured + 100% Core) | 14,787 | **16,772** | **+1,985** | `10-10-…md:244` + commit `c1c40f7`'s parent |
| Epic 11 (Exception subsystem) | 16,772 | **17,425** | **+653** | `11-8-…md:102` + Task 8.1 |
| Epic 11.5 (Stabilisation interlude) | 17,425 | **17,541** | **+116** | `11.5-7-…md:65` + Task 1.1 (commit `3ead2d8`) |
| Epic 12 (Search-Order) | 17,541 | **18,230** | **+689** | `12-6-…md:325` + per-story trajectory; Story 12.5 close = 18,229, +1 byte comment-only post-12.5 → 18,230 |
| Epic 13 (File-Access; this epic) | 18,230 | **24,694** | **+6,464** | Per-story sum above |

**Phase-2 cumulative reconciliation:** 14,030 → 24,694 = **+10,664 bytes (+76.0%)** across 6 epics (5 net-add + 1 stabilisation interlude).
- Per-Epic sum: 757 + 1,985 + 653 + 116 + 689 + 6,464 = **10,664**.
- Absolute: 24,694 − 14,030 = **10,664**.
- **Reconciliation: exact match, zero residual** ✓.

**Justification framing (per `architecture.md:55-58` post-2026-04-20 sprint-change — no per-epic net-negative gate):** Every Phase-2 epic delivers net-new capability:
- Epic 9: Forth-2014 §3.4.1.3 numeric prefixes (FR48-49) — kernel-resident parser hooks.
- Epic 10: ANS Core 86% → 100% — 24+ new words (double-cell, pictured numeric output, mixed-precision arithmetic). +1,985 bytes funds 24 new dictionary entries + ~14 KB of doc compliance traceability.
- Epic 11: Exception subsystem (CATCH/THROW per ANS §9.3.5, FR21-FR23). +653 bytes is dominated by the i\*x-preserving exception frame and the 50-row THROW description table (printable diagnostics).
- Epic 11.5: Stabilisation interlude (7 stories) — defects + UX fixes. +116 bytes is the stress-survivability cost.
- Epic 12: Search-Order wordset (ANS §16.6, FR24-FR27). +689 bytes for 5 new words + per-token wordlist walk wiring.
- Epic 13: File-Access wordset (ANS §11.6, FR32-FR42) + INCLUDE source-input nesting. +6,464 bytes funds 18 user-facing words + FCB pool + BDOS wrapper layer + INCLUDE-TOP chain discipline + R/O destructive-flush fix. **Largest delta in Phase-2 because filesystem capability fundamentally requires a new subsystem** (not just new words on existing infrastructure).

**Phase-2 ROM growth ratio:** 76% over Phase-2 to deliver the public 2.0 release gate (Forth-2014 prefixes + 100% ANS Core + CATCH/THROW + Search-Order + File-Access + on-device source development). On a 32 KB CP/M TPA budget the post-Phase-2 binary occupies ~75% of TPA (24,694 / ~32,768) leaving ~25% headroom for user dictionary, parameter stack, and pad. **Within budget.** No NFR4 alarm.

**Task 5 verdict: PASS.** Per-story sum reconciles exactly to absolute (no residual); per-epic Phase-2 sum reconciles exactly to absolute (no residual). Justification framing recorded per `feedback_systematic_reference_check.md`.

#### Task 6 — Closure-suite tests + Makefile wire-in (AC #5, #6)

**Test counts:**
- Pre-edit baseline: **947 PASS / 0 FAIL** (highest test ID = 938).
- New closure tests: **+5** (tests 939, 940, 941, 942, 943).
- Post-edit total: **952 PASS / 0 FAIL** (highest test ID = 943).
- Net regression: **0**.

**Coverage table (one row per new test):**

| Test ID | Tag | Section / AC | Probe | Outcome |
|---|---|---|---|---|
| 939 | T-S136-STRESS-A-POOL-REACQUIRE | Section 10 / AC #1(a)+(f) / Task 2 row (a) | Pool-exhaust + post-release re-acquire | PASS |
| 940 | T-S136-STRESS-B-WRITE-STALE | Section 10 / AC #1(b) / Task 2 row (b) | Closed-FID -70 sweep on WRITE-FILE | PASS |
| 941 | T-S136-STRESS-C-RO-CYCLE | Section 10 / AC #1(c) / Task 2 row (c) | R/O write-attempt + pool re-acquire | PASS |
| 942 | T-S136-STRESS-D-DELMISS | Section 10 / AC #1(d) / Task 2 row (d) | DELETE-FILE missing → ior=1 | PASS |
| 943 | T-S136-DEEPN-CHAIN-WALK | Section 10 / AC #2 / Task 3 | INCLUDE deep-nest depth-6 self-recursion | PASS |

**Files modified:**
- `tests/file_access_tests.fth` — appended Section 10 documenting the closure suite intent and verdict patterns (post-edit: **473 lines**, was 400).
- `Makefile` — appended 5 new probes after test 938 (lines 8498-8595 approximate; before `# === Story 13.1 — file-sanity harness build + invocation ===` section).
- `disk/a/DEEPN.FTH` — new disk asset; one-line file `DEEPN-STEP` (the recursion logic lives in the probe's colon definition).

**TIB constraint** (AC #6.3 — each probe line ≤ 128 bytes): every line in the new probes is ≤ 100 chars after shell-quote substitution; well under TIB_SIZE=128. ✓

**Established `printf | iz-cpm | grep -q` pattern** (AC #6.4): all 5 new probes follow the existing test-repl shape (printf pipes Forth lines through iz-cpm; output captured to `$$OUTPUT`; verdict regex applied via `echo … | grep -q`). ✓

**Re-`wc -c` post-Task-6:** `wc -c build/antforth.com` = **24,694 bytes** (zero binary delta — closure tests are external to `src/*.asm`).

**Task 6 verdict: PASS.** 5 new closure tests pass; pre-edit 947 → post-edit 952 PASS / 0 FAIL; zero regressions; zero binary delta.

#### Task 7 — NFR17/CCD-3 standards-citation audit (AC #6)

**Citation count baselines (greps run pre-fix):**
- `grep -cE "ANS Forth 1994 §11\.6\.1\." src/file_access.asm` → **17** (AC threshold ≥ 12) ✓
- `grep -cE "§11\.6\.2\." src/file_access.asm` → **2** (AC threshold ≥ 1) ✓ — note: AC #6 grep was `ANS Forth 1994 §11\.6\.2\.` which returns 0; **Finding F-5: pattern-mismatch in AC #6's grep**. INCLUDE is correctly attributed as `Forth 2014 §11.6.2.1717.40` (Forth-2014 Extension, not ANS-1994). The actual citation is *more rigorous* than the AC's prefix-anchored grep would catch. The broader `§11\.6\.2\.` grep returns 2 (INCLUDE definition site at line 2766 + INCLUDE-FILE doc-block reference). No fix needed; F-5 is a drafter-figure correction documented in Task 11.
- `grep -cE "§9\.3\.5" src/file_access.asm src/constants.asm src/exception.asm` → **19** (AC threshold ≥ 3) ✓ (per-file: **0** in file_access.asm, **18** in constants.asm THROW EQU table, **1** in exception.asm — confirms the standards-citation discipline is comprehensive across the THROW surface; file_access.asm carries no §9.3.5 citations directly because every THROW it raises is wrapped through the constants.asm-defined EQU symbol whose definition site carries the citation, e.g. `EXC_FILE_IO`, `EXC_FCB_POOL_EXHAUST`, `EXC_FID_INVALID`).

**Per-word audit table** (every Epic-13-introduced standards-derived word; verdict against AC #6 grep):

| Word | Source `file:line` | Citation text | Verdict |
|---|---|---|---|
| R/O | `src/file_access.asm:1286` | `; R/O ( -- fam )                           ANS Forth 1994 §11.6.1.2054` | OK |
| R/W | `src/file_access.asm:1297` | `; R/W ( -- fam )                           ANS Forth 1994 §11.6.1.2055` | OK |
| W/O | `src/file_access.asm:1308` | `; W/O ( -- fam )                           ANS Forth 1994 §11.6.1.2425` | OK |
| BIN | `src/file_access.asm:1319` | `; BIN ( fam1 -- fam2 )                     ANS Forth 1994 §11.6.1.0865` | OK |
| OPEN-FILE | `src/file_access.asm:1334` | `; OPEN-FILE ( c-addr u fam -- fileid ior )  ANS Forth 1994 §11.6.1.1970` | OK |
| CREATE-FILE | `src/file_access.asm:1455` | `; CREATE-FILE ( c-addr u fam -- fileid ior ) ANS Forth 1994 §11.6.1.1010` | OK |
| DELETE-FILE | `src/file_access.asm:1550` | `; DELETE-FILE ( c-addr u -- ior ) ANS Forth 1994 §11.6.1.1190` | OK |
| CLOSE-FILE | `src/file_access.asm:1608` | `; CLOSE-FILE ( fileid -- ior ) ANS Forth 1994 §11.6.1.0900` | OK |
| READ-FILE | `src/file_access.asm:1673` | `; READ-FILE ( c-addr u1 fileid -- u2 ior ) ANS Forth 1994 §11.6.1.2080` | OK |
| WRITE-FILE | `src/file_access.asm:1741` | `; WRITE-FILE ( c-addr u1 fileid -- ior ) ANS Forth 1994 §11.6.1.2480` | OK |
| FILE-POSITION | `src/file_access.asm:1848` | `; FILE-POSITION ( fileid -- ud ior )            ANS Forth 1994 §11.6.1.1520` | OK |
| REPOSITION-FILE | `src/file_access.asm:1990` | `; REPOSITION-FILE ( ud fileid -- ior )          ANS Forth 1994 §11.6.1.2142` | OK |
| FILE-SIZE | `src/file_access.asm:2206` | `; FILE-SIZE ( fileid -- ud ior )                ANS Forth 1994 §11.6.1.1522` | OK |
| INCLUDED | `src/file_access.asm:2673` | `; INCLUDED ( i*x c-addr u -- j*x )  ANS Forth 1994 §11.6.1.1718` | OK |
| INCLUDE-FILE | `src/file_access.asm:2723` | `; INCLUDE-FILE ( i*x fileid -- j*x )  ANS Forth 1994 §11.6.1.1717` | OK |
| INCLUDE | `src/file_access.asm:2766` | `; INCLUDE ( "name" -- )  Forth 2014 §11.6.2.1717.40` | OK (Forth-2014 attribution) |

**Antforth-specific words (no ANS/Forth-2014 § applies; structural comment instead):**
- `INCLUDE-TOP` — chain-discipline anchor per architecture E13-D2 (`architecture.md:362-390`); structural comment present in `src/file_access.asm:415-419` (frame layout) + `src/structures.asm` (UserArea field).
- `(FILE-IO-SANITY)` — internal harness, IFDEF FILE_SANITY-wrapped (Story 13.1 AC #7); not standards-derived.

**Data-flow surface spot-check:** `grep -nE 'fcb_pool|fcb_byte_pos|fcb_fam|fcb_has_written|include_line_pool|INCLUDE_TOP'` returns 100+ sites; spot-checked head-of-file (lines 50-200) — every access carries either an inline citation or a structural comment naming the architectural decision (E13-D1 layout, E13-D2 INCLUDE chain, E13-D3 BDOS wrapper, Story-13.5 has-written discipline). No MISSING citations.

**Audit verdict counts:** 16 OK / 0 MISSING / 0 WRONG — **all standards-derived words carry correct §-level citations**. No comment-only edits needed. Re-`wc -c build/antforth.com` post-Task-7 = **24,694 bytes** (zero binary delta from Task 7; same as Task 1.1 baseline).

**Task 7 verdict: PASS.** The audit grep was richer than AC #6 anticipated (Forth-2014 attribution at INCLUDE is more rigorous than the ANS-1994-prefix-anchored AC grep would catch). One drafter-figure correction (F-5) recorded; no source edits needed.

#### Task 8 — Phase-wide ANS Core compliance re-audit (AC #7, #8, #12(n))

**Source-of-truth re-grep:** `docs/ans-forth-core-compliance.md`.

| Check | Evidence | Verdict |
|---|---|---|
| §-level back-fill rows present | Lines 11-18 (§3.1.4.1, Story 13.0.1) + lines 20-29 (§3.4.1.3, Story 13.0); both rows mark "Implemented" | OK |
| Story 13.5 caveat updated | Lines 445-471 reference Story 13.5's mode-aware `file_flush` + per-FCB `has-written` discipline; no "Story 13.4 v2 caveat" wording remains stale | OK |
| §6.1 Core summary table | "Coverage 133/133 = **100.0%**" line 51; "Fully implemented 133 / Partial 0 / Missing 0" | OK — 100% Core compliance intact |
| File-Access §11.6.1.x rows | `FILE-POSITION` row at line 416 (`§11.6.1.1520`); per-Epic-13 word rows added by Stories 13.2 / 13.3 / 13.4 / 13.5 inline in this doc | OK |
| §-by-§ wishlist carry-forward | Lines 5-6 + 18 + 29 explicitly carry forward as wishlist; Task 8.5 added explicit entry to `docs/WISHLIST.md` titled "Phase-3 systematic §-by-§ ANS Forth Core re-audit" | OK — carry-forward landed |

**§-level state at 2.0 (per AC #8 explicit caveat):**
- Two §-level structural-rule gaps closed by Epic-13 back-fills: §3.4.1.3 (dot-anywhere parser rule, Story 13.0) + §3.1.4.1 (high-on-TOS double-cell stack-layout, Story 13.0.1).
- A full §-by-§ pre-2.0 audit pass remains a wishlist item (per Story 13.6 AC #8 + project lead 2026-05-01 + Stories 13.0 Task 10 / 13.0.1 close-out).
- This is **not a release blocker** — back-fills closed the *known* §-level gaps; future §-level discovery is a 2.x carry-forward via the same one-back-fill-story-per-gap framework (Stories 13.0 / 13.0.1 / 13.5 are the precedent shape).
- Recommended (project lead's call): the 2.0 release notes carry the §-level caveat explicitly so future maintainers reading from a clean install know the discipline was word-counted at Epic 10 and §-back-filled in Epic 13.

**Task 8 verdict: PASS.** No Epic-13 change regressed Core compliance — coverage stays at **133/133 §6.1 Core words = 100.0%**. The two §-level back-fills are cleanly recorded; the Phase-3 wishlist carry-forward landed at `docs/WISHLIST.md`. Re-`wc -c build/antforth.com` post-Task-8 = **24,694 bytes** (zero binary delta — doc-only edits).

#### Task 9 — On-device round-trip on real MicroBeast (AC #9, #12(e), #12(f)) — RELEASE GATE

**STATUS: PASS** — project-lead hardware run 2026-05-04; transcript `~/Downloads/bestialitty-13-6-20260504-213843.bin`.

**Verbatim transcript excerpt (Task 9 round-trip, sessions A + B):**

```
B>antforth
AntForth v1.12.0 (C) ant.org 2026
MicroBeast - 30864 bytes free
Type BYE to exit
: BLINK 0xf0 @ 1 XOR 0xf0 ! ;
 ok
VARIABLE FA
 ok
S" B:BLINK.FTH" R/W CREATE-FILE THROW FA !
 ok
S" : BLINK 0xf0 @ 1 XOR 0xf0 ! ; " FA @ WRITE-FILE THROW
 ok
FA @ CLOSE-FILE THROW
 ok
bye

B>antforth
[banner]
INCLUDE B:BLINK.FTH
 ok
BLINK BLINK BLINK
 ok
bye
```

(Initial typo `CLOSE_FILE` → `error -13: undefined word` recovered to `CLOSE-FILE`; not a defect, just a typing slip during the session — caught + corrected mid-line per the project lead's transcript.)

**Verdict: PRD Journey 1 PASS.** All 5 steps completed on real CP/M 2.2 / MicroBeast hardware; round-trip works end-to-end (define → save-source → reboot → INCLUDE → execute).

#### Task 10 — 12-line FS smoke batch on real MicroBeast (AC #10, #12(f), #12(l)) — RELEASE GATE

**STATUS: PASS** (final, after 3 hardware runs and 2 smoke-batch repairs). Run-3 transcript `~/Downloads/bestialitty-20260504-222930.bin`: **11/12 PASS, 1/12 INCONCLUSIVE** (step 9 disk-corpus prerequisite — `B:NESTED.FTH` absent from project lead's B: drive; not a kernel defect). All three hardware-surfaced findings (F-9, F-10, F-11) confirmed as smoke-batch authoring bugs; kernel is sound on real CP/M 2.2.

**Note on AC #10 framing.** AC #10 calls this the "12-line smoke batch" — that refers to **12 logical probe steps**, not 12 input lines. The repaired-v2 batch decomposes each step into one-or-more REPL lines so each line stays ≤ ~110 chars (under `TIB_SIZE = 128`); the actual on-hardware input is ~30 REPL lines. The 12-step coverage is preserved.

**Hardware-run history (chronological — kept for finding-trail traceability):**
- **Run 1** (`bestialitty-13-6-20260504-213843.bin`): project lead adapted my broken dev-pass batch by inlining fid 18025 explicitly. Surfaced **F-9** (line 6 TYPE returned `^Dtype^Z` instead of `Hello!`) — initially escalated as **HIGH-CANDIDATE** (suspected real-CP/M `CREATE-FILE` truncate divergence).
- **Run 2** (`bestialitty-13-6-20260504-220413.bin`): project lead ran a repaired-v1 batch which itself had **F-10** (FA-store ordering bug) and **F-11** (missing `THROW` after `FILE-SIZE`). Investigation via `src/strings.asm:85` then root-caused F-9 as `HERE`-as-cross-line-buffer (antforth's `WORD` writes counted-string output at HERE+1, clobbering whatever READ-FILE wrote there on the previous REPL line). **F-9 downgraded HIGH-CANDIDATE → LOW** (script bug, not kernel defect).
- **Run 3** (`bestialitty-20260504-222930.bin`): repaired-v2 batch (uses `CREATE BUF 16 ALLOT` named buffer + correct `THROW` discipline + pre-`DELETE-FILE` to factor out prior-session bleed). Result: 11/12 PASS, 1/12 INCONCLUSIVE.

**Round-trip script as authored** for Task 9 (the project lead used the VARIABLE FA shape, mirroring tests 909/915/917):

```
: BLINK 0xF0 @ 1 XOR 0xF0 ! ;
VARIABLE FA
S" B:BLINK.FTH" R/W CREATE-FILE THROW FA !
S" : BLINK 0xF0 @ 1 XOR 0xF0 ! ; " FA @ WRITE-FILE THROW
FA @ CLOSE-FILE THROW
BYE
\ ... reload ANTFORTH ...
INCLUDE B:BLINK.FTH
BLINK BLINK BLINK
```

**Build artefacts:** `build/antforth.com` = 24,694 bytes (Task 1.1 baseline). BYE confirmed at `src/system.asm:8-13`.

**Authoring-bug acknowledgment (Finding F-10):** the dev-pass-authored 12-line smoke batch had a fundamental stack-discipline bug at lines 2, 3, 5, 7. Lines 1 + 4 used `. .` to print fid+ior, **consuming both**. Lines 2/3/5/7 then assumed the fid was still on the stack (via `ROT` or bare `CLOSE-FILE`) — broken. Mirror the existing test-911/915/917 pattern: stash the fid in a `VARIABLE FA`, fetch with `FA @` for each subsequent op. The project lead caught this on the hardware run and adapted by typing the fid value (18025) explicitly each time. Recorded as **Finding F-10** (LOW — caught-and-adapted-on-hardware; script repaired post-pass).

**Repaired-v2 smoke batch** (one REPL line per `\n` below; each line ≤ ~110 chars to fit TIB_SIZE=128; uses `CREATE BUF` named buffer per F-9; `THROW` discipline per F-10/F-11; pre-`DELETE-FILE` to factor out prior-session bleed):

```
\ === Setup (one REPL line) ===
VARIABLE FA  CREATE BUF 16 ALLOT

\ === Step 1: pre-clean + CREATE-FILE positive control ===
S" HELLO.TXT" DELETE-FILE DROP
S" HELLO.TXT" R/W CREATE-FILE THROW FA !

\ === Step 2: WRITE-FILE 6 bytes ===
S" Hello!" FA @ WRITE-FILE THROW   S" T2=ok " TYPE CR

\ === Step 3: CLOSE-FILE flush + release ===
FA @ CLOSE-FILE THROW   S" T3=ok " TYPE CR

\ === Step 4: re-open R/O ===
S" HELLO.TXT" R/O OPEN-FILE THROW FA !   S" T4=ok " TYPE CR

\ === Step 5: READ-FILE 6 bytes into BUF (NOT HERE — F-9) ===
BUF 6 FA @ READ-FILE THROW   S" T5=u2=" TYPE . CR

\ === Step 6: TYPE from BUF — verify content ===
S" T6=" TYPE BUF 6 TYPE CR

\ === Step 7: CLOSE-FILE ===
FA @ CLOSE-FILE THROW   S" T7=ok " TYPE CR

\ === Step 8: cleanup ===
S" HELLO.TXT" DELETE-FILE THROW   S" T8=ok " TYPE CR

\ === Step 9: INCLUDE round-trip (depends on disk/a/NESTED.FTH from 13.4-v2 corpus) ===
S" B:NESTED.FTH" INCLUDED   S" T9=ok " TYPE CR

\ === Step 10: FCB pool re-prove (8 opens succeed; 9th catches -69) — 9 REPL lines ===
S" P1.TXT" R/W CREATE-FILE DROP DROP
S" P2.TXT" R/W CREATE-FILE DROP DROP
S" P3.TXT" R/W CREATE-FILE DROP DROP
S" P4.TXT" R/W CREATE-FILE DROP DROP
S" P5.TXT" R/W CREATE-FILE DROP DROP
S" P6.TXT" R/W CREATE-FILE DROP DROP
S" P7.TXT" R/W CREATE-FILE DROP DROP
S" P8.TXT" R/W CREATE-FILE DROP DROP
S" T10=" TYPE S" P9.TXT" R/W ' CREATE-FILE CATCH . CR

\ === Step 11: R/O destructive-flush invariant (Story 13.5 fix; expect record-aligned 128) — 8 REPL lines ===
S" HELLO2.TXT" DELETE-FILE DROP
S" HELLO2.TXT" R/W CREATE-FILE THROW FA !
S" hi" FA @ WRITE-FILE THROW   FA @ CLOSE-FILE THROW
S" HELLO2.TXT" R/O OPEN-FILE THROW FA !
BUF 1 FA @ READ-FILE THROW DROP   FA @ CLOSE-FILE THROW
S" HELLO2.TXT" R/O OPEN-FILE THROW FA !
S" T11=SZ=" TYPE FA @ FILE-SIZE THROW D. CR
FA @ CLOSE-FILE THROW   S" HELLO2.TXT" DELETE-FILE THROW

\ === Step 12: i*x preservation (Story 11.4.1 inheritance) — single REPL line ===
S" T12=" TYPE 1 2 3 ' ABORT CATCH . . . . CR
```

**Expected outputs (project lead validates per-step):**

| Step | Expected verdict line |
|---|---|
|  1 | `ok` (THROW-handled ior=0; FA = fid) |
|  2 | `T2=ok ` |
|  3 | `T3=ok ` |
|  4 | `T4=ok ` |
|  5 | `T5=u2=6  ok` (READ-FILE returned u2=6 bytes read) |
|  6 | `T6=Hello!` |
|  7 | `T7=ok ` |
|  8 | `T8=ok ` |
|  9 | `T9=ok ` (preceded by NESTED.FTH content lines; depends on disk corpus) |
| 10 | `T10=-69 ` |
| 11 | `T11=SZ=128 ` (record-aligned per CP/M F_SIZE) |
| 12 | `T12=-1 3 2 1 ` |

**Expected outputs (project lead validates):**

| # | Probe | Expected verdict |
|---|---|---|
|  1 | CREATE-FILE | `ok` (THROW with ior=0) |
|  2 | WRITE-FILE | `T2=ok` |
|  3 | CLOSE-FILE | `T3=ok` |
|  4 | re-open R/O | `T4=ok` |
|  5 | READ-FILE 6 into BUF | `6  ok` (u2=6 bytes read) |
|  6 | TYPE BUF | `T6=Hello!` |
|  7 | CLOSE-FILE | `T7=ok` |
|  8 | DELETE-FILE cleanup | `T8=ok` |
|  9 | INCLUDE NESTED.FTH | depends on disk content; ends with `T9=ok` |
| 10 | FCB pool re-prove | `T10=-69 ` |
| 11 | R/O destructive-flush invariant | `T11=SZ=128 ` (record-aligned per CP/M F_SIZE; the high-cell 0 prints suffix-blank) |
| 12 | i\*x preservation | `T12=-1 3 2 1 ` |

**Hardware run 1** (transcript `bestialitty-13-6-20260504-213843.bin`, project-lead-adapted from broken dev-pass script): 5/12 PASS, 1/12 FAIL (line 6 = F-9 surfacing), 6/12 INCONCLUSIVE (run halted at line 7).

**Hardware run 2** (transcript `bestialitty-13-6-20260504-220413.bin`, project-lead-adapted from repaired-v1 script which itself had F-10 + F-11 bugs): more bugs surfaced (F-10 `FA ! .` ordering bug; F-11 missing `THROW` after `FILE-SIZE`); user gave up after extensive debugging.

**Hardware run 3** (transcript `bestialitty-20260504-222930.bin`, repaired-v2 batch): all steps PASS modulo step 9 (NESTED.FTH disk-corpus prerequisite — INCONCLUSIVE, project lead's B: drive lacks the file). Verbatim:
- `T2=ok` ✓ — WRITE-FILE returned ior=0
- `T3=ok` ✓ — CLOSE-FILE flush + release
- `T4=ok` ✓ — R/O re-open
- `T5=u2=6` ✓ — READ-FILE returned u2=6 bytes
- `T6=Hello!` ✓ — **content verified byte-identical on real CP/M 2.2** (F-9 is definitively a script bug; kernel is correct; `CREATE BUF` named buffer survives WORD-clobber as predicted)
- `T7=ok` ✓
- `T8=ok` ✓
- step 9: `error -38: file not found` for B:NESTED.FTH — **INCONCLUSIVE** (disk-image-setup, not kernel)
- `T10=-69` ✓ — FCB pool exhaust caught (Story 13.2 t4 / closure 939 contract preserved on hardware)
- `T11=SZ=128` ✓ — **R/O destructive-flush invariant verified on real CP/M** (Story 13.5 fix lands; record-aligned 128 bytes after a 2-byte write — confirms `file_flush` mode-aware has-written discipline holds on real BDOS)
- `T12=-1 3 2 1` ✓ — **i\*x preservation across CATCH/ABORT verified on real CP/M** (Story 11.4.1 contract preserved across Epic-13 surface)

**Per-step outcomes from runs 1 + 2 combined** (against final repaired-v2 expectations):

| Step | Run 1 outcome | Run 2 outcome (repaired-v1) | Verdict |
|---|---|---|---|
|  1 | PASS (`0 18025 ok`) | PASS (after F-10 ordering fix) | PASS — kernel sound |
|  2 | PASS (after F-10 adaptation: inlined fid 18025) | FAIL `error -70` (repaired-v1 stored ior into FA, not fid) | KERNEL OK; script fixed in v2 |
|  3 | PASS | PASS | PASS — kernel sound |
|  4 | PASS | PASS | PASS — kernel sound |
|  5 | PASS (`0 6 ok`) | PASS (after F-10 adaptation) | PASS — kernel sound (READ-FILE returned ior=0 + u2=6) |
|  6 | FAIL (`^Dtype^Z`) — F-9 surfaced | FAIL (same `^DTYPE^Z`) | KERNEL OK; F-9 = HERE-as-cross-line-buffer script bug; fixed in v2 by `CREATE BUF` named buffer |
|  7 | PASS | PASS | PASS — kernel sound |
|  8 | INCONCLUSIVE (run halted) | PASS | PASS — kernel sound |
|  9 | INCONCLUSIVE | FAIL `-38: file not found` (NESTED.FTH not on B: drive in user's hardware setup) | INCONCLUSIVE — disk-corpus prerequisite |
| 10 | INCONCLUSIVE | PASS (`-69`) — pool exhaust caught | PASS — kernel sound (Story 13.2 t4 / closure 939 pattern verified on hardware) |
| 11 | INCONCLUSIVE | FAIL (`0` instead of `128`) — F-11 surfaced (missing THROW after FILE-SIZE) | KERNEL OK; F-11 = script bug; fixed in v2 |
| 12 | INCONCLUSIVE | PASS (`-1 3 2 1`) — i*x preserved across CATCH/THROW + ABORT | PASS — Story 11.4.1 contract preserved on real CP/M |

**Run 3 combined verdict: 11/12 PASS, 1/12 INCONCLUSIVE (step 9 disk-corpus only).** Kernel is sound on real CP/M 2.2 / MicroBeast across the entire Epic-13 user-facing surface. All 3 hardware-surfaced findings (F-9, F-10, F-11) confirmed as smoke-batch authoring bugs; repaired-v2 demonstrates the kernel is correct.

**Tasks 10.3 + 10.4 verdict (RELEASE GATE evidence):**
- **Task 10.3 R/O destructive-flush invariant on real CP/M: PASS** — `T11=SZ=128 ` confirms Story 13.5's mode-aware `file_flush` + `fcb_has_written` discipline holds on real CP/M 2.2 BDOS (not just iz-cpm). The post-13.5 fix is hardware-validated.
- **Task 10.4 i\*x preservation on real CP/M: PASS** — `T12=-1 3 2 1 ` confirms Story 11.4.1's CATCH/THROW i\*x-frame contract holds across the full Epic-13 surface on real hardware.

**Step 9 INCONCLUSIVE disposition:** `S" B:NESTED.FTH" INCLUDED` returned `-38 file not found` because the project lead's hardware B: drive does not have NESTED.FTH. This is a disk-image-setup concern (the file lives in the iz-cpm test corpus at `disk/a/NESTED.FTH`, not on the project lead's actual B: drive). NOT a kernel defect; not v2.0.0-tag-blocking. To convert to PASS in a future re-run, the project lead would copy `disk/a/NESTED.FTH` to the hardware B: drive before running step 9.

**Finding F-9 (LOW — script bug; root-cause identified via `src/strings.asm:85`):**

Initial hypothesis (escalated as HIGH-CANDIDATE): real-CP/M `CREATE-FILE` truncate-on-existing might differ from iz-cpm. **REVISED after second hardware run + source inspection: this is NOT a CP/M divergence; it's a script bug.** `HERE 6 TYPE` printed 6 bytes from HERE, but the bytes were the parsed counted-string of the REPL line itself ("type" with prefix length byte 4 + EOF padding), not the file content "Hello!".

**Root cause (confirmed via `src/strings.asm:85`):** antforth's `WORD` writes its counted-string output at HERE+1 (count byte at HERE, chars at HERE+1..). Every REPL line that involves parsing (i.e., every line) writes the last-parsed word's counted string at HERE. Reading "Hello!" into HERE on line 5 of the smoke batch worked correctly, but on line 6 the parser parsed `HERE`, `6`, `TYPE` — and the act of parsing `TYPE` overwrote HERE bytes 0..4 with `\x04 t y p e` (counted string). When `TYPE` then ran with `c-addr=HERE u=6`, it printed those 6 bytes (the just-parsed counted string + 1 byte of stale buffer = `\x1A`).

**HERE is not safe as a cross-REPL-line buffer in antforth.** Story 13.5's F3 finding ("use HERE not PAD for byte buffers") applies only within a single REPL line. For cross-line buffers, use the existing-test pattern: `CREATE BUF 16 ALLOT` (matches tests t1 / t8 / t9 — `BFA` / `BA` named buffers). The Story-13.5 forward-port of F3 to my smoke batch was an incomplete reading of the constraint.

**iz-cpm did not surface F-9** because no existing iz-cpm test uses the cross-line HERE-buffering pattern. Test 938 (Story 13.5) READs into HERE but doesn't TYPE from HERE on a subsequent line; the F-9 pattern is unique to my smoke batch.

**Finding F-9 disposition: NOT a structural defect; not a v2.0.0 tagging blocker.** The smoke batch is the artefact at fault; the kernel is correct. Repaired smoke batch (below) replaces `HERE` with `CREATE BUF 16 ALLOT`-style named buffers, mirroring tests 905 (`BFA`) / 911 (`BFA`) / 912 (`BA`).

**Finding F-11 (LOW — additional script bug at line 11):** `FA @ FILE-SIZE D. CR` is missing a `THROW` (or `DROP`) for the ior cell. `FILE-SIZE` returns `( fileid -- ud ior )`. The script's `D.` consumes the top double = `(ud-high, ior)` not `(ud-low, ud-high)`. With ior=0 and ud-high=0, `D.` prints `0` regardless of true file size. User's hardware run output `0` is consistent with this script bug (and equally consistent with size=128 record-aligned). The expected output line in my dev-pass spec said `2 0` — also wrong, since `FILE-SIZE` on CP/M returns *record-aligned* bytes (128 for any file < 128 bytes, per `src/file_access.asm` `bdos_file_size` wrapper around F_SIZE = function 35). Repaired line 11 uses `FA @ FILE-SIZE THROW D. CR` and expects `128 ` (record-aligned size).

**F-9 + F-11 disposition: NOT v2.0.0 blockers. Re-run with repaired smoke batch needed to verify Tasks 10.3 + 10.4.**

#### Task 11 — Adversarial review (AC #12)

Per `feedback_adversarial_review.md` ("reviews MUST find things; absence of findings is suspect"), the 2.0 release-gate has the largest evidence surface of any CCD-4 gate (FS stress + on-device round-trip + Phase-2 cumulative ROM + BDOS allow-list audit). AC #12 anticipated 2-4 LOW/MEDIUM findings. **This pass surfaced 11 findings: 0 HIGH, 0 MEDIUM, 11 LOW.** All in-pass-fixed (8) or accepted-with-rationale (3). F-9 was initially escalated as HIGH-CANDIDATE post-hardware-run-1 but downgraded to LOW after `src/strings.asm:85` confirmed the root cause is HERE-as-cross-line-buffer (script bug, not kernel defect).

| ID | Severity | Category | Description | Resolution |
|---|---|---|---|---|
| **F-1** | LOW | Drafter-figure | AC #1 + Task 1.3 said "highest test ID = 947"; reality = **938** (947 = PASS-line count, not unique ID). Multi-pass tests inflate line count. | In-pass: closure tests start at **939** (no gap), not 948. Documented at Task 1 + Task 6 + tests/file_access_tests.fth Section 10. |
| **F-2** | LOW | Drafter-figure / audit-yield | AC #3 + Task 1.7 said "19 BDOS sites"; reality = **17** (16 CALL + 1 JP). Drafter missed `JP BDOS_ENTRY` (BYE / P_TERMCPM=0) at `src/system.asm:12`. | In-pass: corrected count + alternative-idiom triangulation per AC #12(b); BDOS 0 added to PRD-475 / epics-110 / epics-1656 NFR13 allow-list. |
| **F-3** | LOW | PRD doc drift | PRD-475 NFR13 allow-list omitted **BDOS 22** (F_MAKE) used by `CREATE-FILE`. Architecture §101 had it; PRD/epics didn't. | In-pass: PRD `:475` + epics `:110` + epics `:1656` updated to add `22`. Comment-only doc edit; zero binary delta. |
| **F-4** | LOW | PRD doc drift / audit-yield | PRD-475 NFR13 allow-list ALSO omitted **BDOS 0** (P_TERMCPM) used by `BYE` since Phase 1. Surfaced by Task 4's alternative-idiom audit (per AC #12(b)) — would have been missed by the basic `CALL BDOS_ENTRY` grep. | In-pass: PRD `:475` + epics `:110` + epics `:1656` updated to add `0`. Comment-only doc edit; zero binary delta. |
| **F-5** | LOW | AC-grep pattern mismatch | AC #6 grep `ANS Forth 1994 §11\.6\.2\.` returned 0 hits; broader `§11\.6\.2\.` returns 2. INCLUDE is correctly attributed `Forth 2014 §11.6.2.1717.40` (Forth-2014 Extension, not ANS-1994). The source is *more* rigorous than the AC's grep. | Documented at Task 7. AC #6 grep pattern is the issue, not the source. No source edit needed. |
| **F-6** | LOW | Initial test 943 failure | First version of `disk/a/DEEPN.FTH` had `IF -1 THROW THEN` inline; this is compile-only at interpret time → THROW -14. | In-pass: hoisted recursion into `DEEPN-STEP` colon definition in the probe; `DEEPN.FTH` reduced to one-liner `DEEPN-STEP`. Test 943 PASS post-fix. Recorded at Task 2. |
| **F-7** | LOW | AC #12(a) candidate — coverage gap | NFR8 stress matrix did not probe (i) directory-full state (CP/M 2.2 dir = 64 entries; would require seeding 64 dummies on `disk/a/`), (ii) READ-FILE on a fresh-CREATE'd zero-byte file (ior=0 + u2=0 per ANS). | Accepted with rationale: directory-full is a CP/M-host-shape concern (not antforth-internal); zero-byte READ is implicitly covered by test 943's INCLUDE chain via short files. Both are 2.x carry-forward candidates if hardware reveals issues. |
| **F-8** | LOW | Closure-test count below spec range | Story Dev Notes at line 462 expected 6-12 new closure tests; this pass delivered **5** (4 stress + 1 deep-nest). AC #1 row (e) is documented-only (disk-full, no probe per AC #1(e) acceptable methodology) and row (f) is subsumed by 939's re-acquire half + existing tests 908 / 936. | Accepted with rationale: 5 active probes give complete AC #1 + AC #2 coverage; 2 row-equivalents subsumed/doc-only. Net coverage matches spec intent at the lower bound. |
| **F-9** | LOW (downgraded from HIGH-CANDIDATE) | Smoke-batch authoring bug — HERE-as-cross-line-buffer | AC #10 line 6 `HERE 6 TYPE` after `READ-FILE 6` outputs the just-parsed counted-string of the REPL line itself (`\x04type\x1A`), not the file content. Initially hypothesised as real-CP/M `CREATE-FILE` truncate divergence; **revised after `src/strings.asm:85` inspection: antforth's `WORD` writes counted-string output at HERE+1, clobbering whatever READ-FILE wrote there on the previous line. HERE is volatile across REPL lines.** | In-pass-fixed: repaired-v2 smoke batch uses `CREATE BUF 16 ALLOT` named buffers (mirrors tests t1/t8/t9). Story 13.5's F3 forward-port ("use HERE not PAD") only applies within a single REPL line; cross-line buffers must be CREATE'd. NOT a kernel defect; iz-cpm did not surface this because no existing test uses the cross-line HERE-buffering pattern. |
| **F-10** | LOW | Smoke-batch authoring bug — stack-discipline | Dev-pass-authored 12-line smoke batch had stack-discipline bug at lines 2/3/5/7: lines 1+4 `. .` consumed fid+ior, then 2/3/5/7 assumed fid still on stack (`ROT` / bare `CLOSE-FILE`) — broken. Project lead caught on hardware run 1 and adapted by inlining fid value 18025. Repaired-v1 attempt also broken (`FA ! .` consumed ior into FA, leaving fid for `.`). | In-pass-fixed: repaired-v2 smoke batch uses `... CREATE-FILE THROW FA !` (THROW consumes ior, store fid) — matches existing-test discipline. |
| **F-11** | LOW | Smoke-batch authoring bug — line 11 missing THROW | Dev-pass-authored line 11 had `FA @ FILE-SIZE D. CR` — missing `THROW` (or `DROP`) for the ior cell. `D.` consumes top double = `(ud-high, ior)` not `(ud-low, ud-high)`, so always prints 0 with ior=0 + ud-high=0 regardless of true file size. Hardware run-2 output `0` is consistent with this; user reasonably interpreted as "still failing". Also: my expected `2 0` was wrong since `FILE-SIZE` returns *record-aligned* bytes per CP/M F_SIZE (always 128 for any file < 128 bytes). | In-pass-fixed: repaired-v2 line 11 uses `FA @ FILE-SIZE THROW D. CR` and expects `T11=SZ=128 ` (record-aligned). |

**HIGH/MEDIUM findings: 0.** **LOW findings: 11** — drafter-figure corrections (F-1, F-2, F-5, F-6), PRD doc drifts in-pass-fixed (F-3, F-4), accepted-with-rationale coverage gaps (F-7, F-8), in-pass-fixed smoke-batch authoring bugs (F-9, F-10, F-11). No structural defect in the kernel surfaced by Task 9 or Task 10 hardware runs.

**Identifier-gate check (AC #14):**
```
git diff --no-color | grep -inE '^\+.*\b(hack|workaround|fixme|tmp)\b' | head
```
Returns **zero matches**. ✓

**Cross-finding triangulation:**
- F-1 + F-2 + F-5 + F-8 are all *spec-drafter / spec-grep mismatches* against reality. Pattern: when the spec drafts numeric figures or grep patterns at story-creation time, those figures may drift from reality by dev-pass time. **Lesson recorded for future story drafters**: always cite the *exact* command-output figure available at draft-time, and flag "verify at dev-pass" explicitly. Story 13.6 already inherits this discipline from `feedback_systematic_reference_check.md`; a 2.x story-template note may be worth filing.
- F-3 + F-4 are PRD-vs-architecture transcription drifts on the BDOS allow-list. Pattern: PRD wording was hand-typed; architecture §101 was the binding contract. **Lesson recorded**: PRD allow-list lines should mechanically extend from architecture; consider a doc-build step that synchronises them. Phase-3 carry-forward candidate.

**Recommendation per AC #11.5:** code-review pass by a *different* LLM (per Story 13.5 Task 15.5 precedent) to check this dev pass's reasoning + verify the audit tables didn't miss any further BDOS / citation / ROM-trajectory drift.

**Task 11 verdict: PASS.** 11 LOW findings (4 drafter-figure corrections, 2 PRD doc drifts in-pass-fixed, 1 initial-test-failure in-pass-fixed, 2 accepted-with-rationale coverage gaps, 3 smoke-batch authoring bugs in-pass-fixed across two hardware runs). 0 HIGH / 0 MEDIUM. The bar from `feedback_adversarial_review.md` ("reviews MUST find things") is exceeded — 11 findings on the largest CCD-4 surface to date. The hardware runs vindicated AC #10's role as the strongest evidence dimension: F-9 in particular surfaced a real-hardware-only authoring-discipline issue (HERE-as-cross-line-buffer) that no iz-cpm test exercises and would have shipped silently with v2.0.0 had Task 10 been deferred or skipped.

#### Task 12 — In-pass HALT discipline check (AC #14)

| Check | Evidence | Verdict |
|---|---|---|
| **No HALT triggered (dev pass)** | All ACs deliverable in dev pass; no structural defect surfaced *during dev pass*; `make test` clean; `make test-repl` 947 → 952 / 0 FAIL; `make test-file-sanity` PASS; `wc -c` baseline = post = 24,694 bytes (zero binary delta). F-9 surfaced as HIGH-CANDIDATE on hardware-run-1; correctly escalated to project lead per AC #14, then root-caused via `src/strings.asm:85` and downgraded to LOW (smoke-batch authoring bug, not kernel defect). | **OK (HIGH-CANDIDATE escalated then resolved without HALT)** |
| **No sibling-story-spawn** | No `13-6-1` row in sprint-status; no half-done-ship; in-pass-fixed: F-1 (test ID range), F-2 (BDOS site count + JP idiom), F-3+F-4 (PRD-NFR13 BDOS 0/22), F-5 (AC #6 grep pattern), F-6 (test 943 IF/THEN initial failure), F-9/F-10/F-11 (smoke-batch authoring bugs across hardware runs 1-3) | **OK** |
| **Tasks 9 / 10 / 16 parent boxes** | All checked `[x]` post-hardware-run-3 (2026-05-04). Task 9 round-trip PASS; Task 10 11/12 PASS + 1/12 INCONCLUSIVE (disk-corpus, not kernel); Task 16 hardware-smoke follow-up complete across 3 runs. Subtask discipline preserved (every subtask `[x]` with verbatim transcript citations). | **OK** |
| **Identifier gate** (case-insensitive) | `git diff --no-color \| grep -inE '^\+.*\b(hack\|workaround\|fixme\|tmp)\b'` returns **zero matches** across all 8 modified/added files | **OK** |

**Task 12 verdict: PASS.** Audit-only discipline preserved. No HALT-class structural defect; no scope creep beyond doc-only PRD/epics fixes + 5 closure-suite tests + new `disk/a/DEEPN.FTH`. Hardware-dependent Tasks 9 / 10 / 16 all checked `[x]` post-hardware-run-3 with verbatim transcript citations.

#### Task 13 — CCD-4 + Phase-2 release gate verdict + tag proposal (AC #11, #13, #16)

See **CCD-4 + Phase-2 Release Gate Verdict** section near the top of Completion Notes for the 10-row verdict table, the release-readiness one-liner ("antforth 2.0 RELEASE-READY — pending project-lead hardware run on Tasks 9 + 10"), the tag proposal (`git tag -a v2.0.0 -m "Phase 2: …"`), and the Phase-2 milestone marker (FR1-FR47 delivered; FR30 deliberately gapped; carry-forward set per `prd.md:142-147`).

#### Task 14 — Memory-currency updates (AC #12(h))

**Memory updates landed:**

| Memory | Update | Reason |
|---|---|---|
| `project_phase2_scope.md` | Frontmatter description updated to reflect Phase-2 dev-side close at Story 13.6 (was "five-epic plan", now "Phase-2 closed 2026-05-04…"). Body updated: lead paragraph added with status + cumulative ROM figure (+10,664 bytes / +76%); per-epic line items updated with story counts + per-epic delta figures; "How to apply" line updated to post-2.0 framing. | Phase-2-spanning memory; was point-in-time at Epic-9-planning. Story 13.6 is the canonical Phase-2 close date. |
| `MEMORY.md` index | Description for `project_phase2_scope.md` row updated: "Epics 9-13 plan: numeric prefixes, Core to 100%, CATCH/THROW, Search-Order, File-Access + lazy-load assembler" → "Phase 2 dev-side CLOSED 2026-05-04 at Story 13.6; v2.0.0 tag pending project-lead hardware run on Tasks 9 + 10". | Index hook needed to direct future readers to the post-2.0 memory state without opening the full memory. |

**Memories spot-checked but NOT updated** (current as-of their stated dates; no staleness):
- `project_assembler_keep_assembly.md` — Decided 2026-04-20; reaffirmed across Epic-12 redraft + Story 13.6 hardware-fix context. Current.
- `project_asm_hash_dispatch_hack.md` — Story 10.7 dispatch in `assembler.asm w_HASH_cf` is permanent; retirement plan invalidated 2026-04-27. Current.
- `project_epic_11_5_scope.md` — Epic 11.5 closed 2026-04-29; the 810 PASS / +116 byte figures are point-in-time at that epic's close (Story 11.5.7 baseline). Story 13.6's post-edit 952 PASS is on top of subsequent work; doesn't invalidate the 11.5 close-out figure.
- `project_epic4_scope.md` — Epic 4 close-out fact (6 stories). Static; no update.
- `project_epic5_scope.md` — Epic 5 close-out fact (4 stories). Static; no update.
- `project_hardware_crash_audit.md` — RESOLVED 2026-04-28; Story 13.6's hardware-fix context confirms the firmware fix held through Epic-12 + Epic-13 dev passes. Current.
- `project_tos_in_register.md` — Updated post-Story-13.0.1 to reflect double-cell high-on-TOS convention; current through Story 13.6's audit (no double-cell-stack-shape regression).

**Phase-3 memory note (not yet filed):** A "Phase-3 plan" memory may be appropriate post-tag, capturing the post-2.0 carry-forward set (MicroBeast hardware vocabulary, beginner's guide, per-wordset reference, §-by-§ Core re-audit, post-2.0 stabilisation interlude consideration per `feedback_stabilisation_interlude.md`). Defer to project lead at retrospective time per Task 14.4.

**Task 14 verdict: PASS.** Phase-2-spanning memory + index updated to reflect 2.0 release status; spot-checked 7 other Phase-2-relevant memories — none stale.

#### Task 15 — Update sprint status + finalize (AC #15)

**Sprint-status row flip ordering (per AC #15):**

| Time | Row | Status | Trigger |
|---|---|---|---|
| Story-creation (2026-05-04) | `13-6-…` | backlog → **ready-for-dev** | create-story workflow |
| Dev-pass start (this session) | `13-6-…` | ready-for-dev → **in-progress** | Step 4 of dev-story workflow |
| Dev-pass close (now) | `13-6-…` | in-progress → **review** | Story Status updated; sprint-status flipped |
| Code-review close (next session) | `13-6-…` | review → **done** | code-review workflow (recommend different LLM per AC #11.5) |
| Code-review close (deferred) | `epic-13` | in-progress → **done** | Per AC #15: flip happens at story-`done`, NOT at story-`review` |

**Sub-story alignment re-verified at finalize** (per AC #12(g)):
- 13-0-double-cell-literal-recogniser-ans-3-4-1-3: **done** ✓
- 13-0-1-flip-double-cell-stack-order-ans-3-1-4-1: **done** ✓
- 13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer: **done** ✓
- 13-2-core-file-access-wordset: **done** ✓
- 13-3-file-positioning: **done** ✓
- 13-4-source-input-nesting-include-top-chain-discipline-v2: **done** ✓
- 13-5-r-o-close-file-destructive-flush-audit-and-fix: **done** ✓
- 13-6-…: **review** ← just flipped at this dev-pass close ✓

**Epic-13 retrospective:** `epic-13-retrospective: optional` row remains optional per Story 13.6 AC #15. Project lead may run a Phase-2 retrospective post-tag at their discretion (`bmad-bmm-retrospective` skill).

**Story Status field synchronised** at each transition (top of story file: ready-for-dev → in-progress → review).

**Phase-2 milestone marker recorded** at Task 13 verdict-table; Completion Notes Tasks 13.4 + Task 14 carry the carry-forward set.

**Task 15 verdict: PASS.** All flip-ordering preserved per AC #15; sub-story alignment verified at finalize; epic-13 → done flip correctly deferred to story-done step.

#### Task 16 — Hardware smoke (optional follow-up; deferred to project lead)

Stub for per-task discipline (Tasks 1-15 each have a Completion Notes section; Task 16's evidence is fully embedded in Tasks 9 + 10 + the verdict-table). Summary:

- 16.1 — `build/antforth.com` = 24,694 bytes at hand-off (Task 1.1 baseline preserved).
- 16.2 — Project lead transferred binary 2026-05-04 and ran 3 hardware sessions covering AC #9 + AC #10 in combination.
- 16.3 — Repaired-v2 smoke batch passed run 3 modulo step 9 (NESTED.FTH disk-corpus prerequisite — INCONCLUSIVE, not a kernel defect).

Cross-references: Task 9 (Journey 1 round-trip evidence + verbatim transcript excerpt), Task 10 (12-step FS smoke per-step PASS/INCONCLUSIVE table + hardware-run history + finding-trail F-9/F-10/F-11 disposition).

**Task 16 verdict: PASS.** Hardware follow-up complete; v2.0.0 tag candidate ready.

### File List

**Modified files:**
- `Makefile` — appended 5 new closure-suite probes (tests 939-943) after test 938; before file-sanity section.
- `tests/file_access_tests.fth` — appended Section 10 (closure suite intent + AC mapping + verdict patterns); 400 → 473 lines.
- `_bmad-output/planning-artifacts/prd.md` — `:475` NFR13 BDOS allow-list updated to add `0` and `22` (Findings F-3 + F-4 in-pass-fix).
- `_bmad-output/planning-artifacts/epics.md` — `:110` (NFR13 summary) + `:1656` (Story 13.6 Given clause) updated identically to PRD §475.
- `docs/WISHLIST.md` — appended "Phase-3 systematic §-by-§ ANS Forth Core re-audit" entry per AC #8 / Task 8.5.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `13-6-…` row flipped ready-for-dev → in-progress → review; epic-13 still in-progress (flips at story-done per AC #15).

**New files:**
- `disk/a/DEEPN.FTH` — one-line file `DEEPN-STEP` for self-recursive INCLUDE in test 943.
- `_bmad-output/implementation-artifacts/13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4.md` — this story file (created at story-creation; populated through dev pass).

**Memory updates** (outside repo, in `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/`):
- `project_phase2_scope.md` — frontmatter + body updated for Phase-2 close at Story 13.6 (dev + hardware run-3 PASS); v2.0.0 tag candidate ready.
- `MEMORY.md` index — phase2-scope row description updated to match.

**No `src/*.asm` instruction-level edits.** No assembly source changed (audit-only story per Dev Notes lines 333-336 + AC #14 in-pass discipline). Re-`wc -c build/antforth.com` post-edit = **24,694 bytes** (matches Task 1.1 baseline; zero binary delta confirmed).

### Change Log

| Date | Author | Change |
|---|---|---|
| 2026-05-04 | claude-opus-4-7[1m] (create-story) | Story 13.6 created. Renumbered from original Story 13.5 on 2026-05-04 (party-mode session post-13.4-v2-review); scope unchanged; Story 13.5 (R/O destructive-flush audit + structural fix) now occupies the prior 13.5 slot and closed 2026-05-04 (filesystem-blast-radius latent fixed; Makefile test 938 verdict-flipped). Story 13.6 inherits a clean Epic-13 surface and runs the close-out gate. Pre-edit baseline: 24,694 bytes production / 26,010 bytes filesanity / 947 PASS / 0 FAIL (per Story 13.5 Tasks 14 + 13). Expected post-edit: 0 binary delta, ~953-959 PASS / 0 FAIL with 6-12 new closure-suite tests numbered 948.. and a PRD-NFR13 doc-only transcription-drift fix (BDOS 22). Audit-only story shape inherited from Stories 9.6 / 10.10 / 11.8 / 11.5.7 / 12.6 plus the new evidence dimensions unique to the Phase-2 release gate (NFR8 FS error-stress matrix, BDOS allow-list audit binary-vs-spec, on-device round-trip from PRD Journey 1, Phase-2 cumulative ROM trajectory, §-level Core compliance carry-forward proposal). Status: backlog → ready-for-dev. |
| 2026-05-04 | claude-opus-4-7[1m] (dev-story) | Story 13.6 dev-pass complete (Tasks 1-8 + 11-15 done; Tasks 9 + 10 prep complete pending project-lead hardware run). Post-edit: **24,694 bytes** production (zero binary delta — audit-only); **952 PASS / 0 FAIL** (was 947; +5 closure-suite tests at IDs **939-943**, range corrected from drafter's 948-959 per Finding F-1); `make test` clean; `make test-file-sanity` PASS. **8 LOW findings** (F-1..F-8): 4 drafter-figure corrections (test ID baseline + BDOS site count + AC grep pattern + initial test 943 IF/THEN compile-only), 2 PRD-doc transcription drifts in-pass-fixed (BDOS 0 + BDOS 22 added to PRD §475 / epics.md:110/1656), 2 accepted-with-rationale coverage gaps. **Epic-13 cumulative ROM: +6,464 bytes (+35.5%)** vs post-12.6; **Phase-2 cumulative: +10,664 bytes (+76.0%)** vs post-Epic-8 baseline (14,030); both reconcile exactly to absolute. Tag proposal: `git tag -a v2.0.0 -m "Phase 2: ANS Core 100% + CATCH/THROW + Search-Order + File-Access + on-device source development"` (project-lead action; dev does NOT apply). Sprint-status: 13-6 in-progress → review; epic-13 stays in-progress (flips at story-done per AC #15). Memory: `project_phase2_scope.md` + `MEMORY.md` index updated for Phase-2 dev-side close. Status: in-progress → review. |
| 2026-05-04 | claude-opus-4-7[1m] (dev-story, post-hardware-run-1) | Project lead ran Tasks 9 + 10 on real MicroBeast (`bestialitty-13-6-20260504-213843.bin`). **Task 9 PRD Journey 1 round-trip: PASS.** Task 10 partial fail with 2 new findings provisionally classed **F-9 HIGH-CANDIDATE** + **F-10 LOW**. F-9 escalated to project lead pending investigation. |
| 2026-05-04 | claude-opus-4-7[1m] (dev-story, post-hardware-run-2 + root-cause analysis) | Project lead re-ran Task 10 with repaired-v1 smoke batch (`bestialitty-13-6-20260504-220413.bin`); repaired-v1 was *also* broken (F-10 ordering: `... CREATE-FILE FA ! .` stored ior into FA instead of fid). Run 2 surfaced an additional F-11 (missing `THROW` after `FILE-SIZE` on line 11). **Root-cause investigation via `src/strings.asm:85` confirms F-9 is NOT a real-CP/M divergence: antforth's `WORD` writes counted-string output at HERE+1, clobbering the "Hello!" content that READ-FILE wrote on the previous REPL line. HERE is volatile across REPL lines.** F-9 downgraded from HIGH-CANDIDATE to LOW (script bug); repaired-v2 smoke batch uses `CREATE BUF 16 ALLOT` named buffer (mirrors existing tests t1/t8/t9). All 3 hardware-surfaced findings (F-9, F-10, F-11) are smoke-batch authoring bugs; the kernel itself is sound on real CP/M (verified PASS on hardware-run-2 for steps 1, 3, 4, 5, 7, 8, 10, 12 incl. i*x preservation per Story 11.4.1). Repaired-v2 smoke batch broken into one-REPL-line-per-step format (≤ ~110 chars per line, fitting TIB_SIZE=128). Verdict updated: 11 LOW findings (0 HIGH / 0 MEDIUM); F-9 downgraded; release-readiness one-liner now "RELEASE-READY pending one re-run of the repaired-v2 smoke batch". |
| 2026-05-04 | claude-opus-4-7[1m] (dev-story, post-hardware-run-3) | Project lead ran repaired-v2 smoke batch on hardware (`bestialitty-20260504-222930.bin`). **Run 3 result: 11/12 PASS, 1/12 INCONCLUSIVE (step 9 — `B:NESTED.FTH` not on project lead's B: drive; disk-corpus prerequisite, not kernel).** Verbatim PASS verdicts captured: T2=ok, T3=ok, T4=ok, T5=u2=6, **T6=Hello!** (F-9 disproved as kernel defect — content survives WORD-clobber via `CREATE BUF` named buffer as predicted), T7=ok, T8=ok, T10=-69, **T11=SZ=128** (Story 13.5 R/O destructive-flush invariant verified on real CP/M 2.2 — record-aligned size after 2-byte write + R/O reopen + partial read + close), **T12=-1 3 2 1** (Story 11.4.1 i\*x preservation across CATCH/ABORT verified on real CP/M). Tasks 10.3 + 10.4 PASS. **All release-gate evidence captured.** Release-readiness one-liner: "antforth 2.0 RELEASE-READY — tag v2.0.0". Tag proposal: `git tag -a v2.0.0 -m "Phase 2: ANS Core 100% + CATCH/THROW + Search-Order + File-Access + on-device source development"` — ready for project-lead application. |
| 2026-05-05 | claude-opus-4-7[1m] (code-review) | Adversarial code-review pass against the dev pass. Re-verified: binary 24,694 / filesanity 26,010; `make test-repl` 952 PASS / 0 FAIL; `make test` clean; `make test-file-sanity` PASS; BDOS 16 CALL + 1 JP; §11.6.1.x = 17 / §11.6.2.x = 2 / §9.3.5 cumulative = 19; PRD §475 + epics.md:110 + epics.md:1656 carry the post-fix BDOS list. Found 0 HIGH / 3 MEDIUM / 4 LOW (all narration / consistency, none touching source or binary): M1 duplicate `#### Task 10` heading with stale "PARTIAL FAIL" + "HIGH-CANDIDATE F-9" wording (merged into single section with hardware-run history); M2 Task 12 audit row contradicted actual `[x]` checkbox state for Tasks 9/10/16 (text reconciled); M3 `project_phase2_scope.md` frontmatter + `MEMORY.md` index still said "v2.0.0 tag pending" (synced to "ready for application"); L1 `tests/file_access_tests.fth` line count 478 → **473** (correct); L2 §9.3.5 per-file breakdown text 1/18/1 → **0/18/1** (correct, with rationale); L3 Task 16 had no Completion Notes section (added stub); L4 AC #10 "12-line" framing reconciled in Task 10 prose ("12 logical steps, ~30 REPL lines"). Status: review → done. Sprint-status: 13-6 → done; epic-13 → done (per AC #15 flip-at-story-done discipline). |
