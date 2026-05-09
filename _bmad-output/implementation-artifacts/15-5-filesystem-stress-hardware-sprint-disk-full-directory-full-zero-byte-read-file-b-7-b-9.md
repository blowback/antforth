# Story 15.5: Filesystem stress hardware sprint — disk-full + directory-full + zero-byte READ-FILE (B.7 + B.9)

Status: done

<!-- Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!--
Second story of Epic 15 (Phase-3 Standards Close-Out), authored 2026-05-09
post-Story-15.1 close. Story 15.1 (A.1 §-by-§ ANS Core compliance audit)
landed clean: 0 back-fill stories spawned, doc-only diff, zero binary
delta, 973 PASS / 0 FAIL preserved (`docs/PHASE-3-CARRY-FORWARD.md:109`).

Story 15.5 closes B.9 (disk-full hardware re-verification) and exercises
the B.7 conditional fork (directory-full + zero-byte READ-FILE). The
hardware-smoke run IS the deliverable; iz-cpm cannot meaningfully exhaust
its disk image (`tests/file_access_tests.fth:456..463` — Story 13.6
explicitly punted disk-full to a hardware run "if budget permits"; B.9
is that run).

B.7's conditional disposition (architecture `:294..299`):
  (a) "Evaluation suffices" — clean hardware run; B.7 closes without
      Story 15.5.1.
  (b) "Probe story spawned" — hardware reveals defect (wrong ior,
      orphaned FCB, directory corruption, FCB-pool recovery failure);
      Story 15.5.1 spawned per `feedback_verdict_only_audit.md`.

Hardware crash class (memory `project_hardware_crash_audit.md`) was
RESOLVED 2026-04-28 — MicroBeast firmware fix verified clean on real
hardware (`PROBE.COM` all-P, antforth runs flawlessly). B.9 / B.7
hardware run can proceed without firmware-side preconditions.
-->

## Story

As **Pete the hardware/peripheral developer** (PRD Journey 4),
I want disk-full / directory-full / zero-byte READ-FILE failure modes verified clean on real CP/M 2.2 / MicroBeast hardware,
So that documented filesystem failure-mode behaviour is hardware-real, not just iz-cpm-real — closing B.9 (disk-full hardware re-verification) and resolving B.7's conditional fork (directory-full + zero-byte READ-FILE).

## Acceptance Criteria

1. **AC1 (B.9 disk-full)** — `tests/file_access_tests.fth` grows a disk-full probe block targeting B: ramdisk on real CP/M 2.2 / MicroBeast. The probe deterministically writes one large file (or grows it) until `WRITE-FILE` returns a non-zero `ior` (block-storage exhaustion). Probe asserts: (a) non-zero `ior` from `WRITE-FILE`; (b) no orphaned FCB handle (`CLOSE-FILE` after the failure returns `ior=0`); (c) clean re-OPEN-FILE / READ-FILE round-trip on a *pre-existing* file post-failure (filesystem consistency post-storage-exhaustion).

2. **AC2 (F2 directory-full)** — same harness grows a directory-full probe block. Probe creates many small files until `CREATE-FILE` returns a non-zero `ior` (CP/M directory-entry exhaustion — distinct from AC1's block-storage exhaustion per architecture finding F2 `:799..809`). Probe asserts the same three consistency conditions as AC1: non-zero `ior` on the failing `CREATE-FILE`, clean `CLOSE-FILE` on every successfully-acquired FCB, clean re-OPEN-FILE / READ-FILE round-trip on a pre-existing file post-failure.

3. **AC3 (zero-byte READ-FILE)** — same harness grows a zero-byte READ-FILE probe. Probe opens a small known file, calls `READ-FILE` with `u1 = 0` (signature `( c-addr 0 fileid -- 0 0 )`), and asserts both return values are `0` (`u2 = 0`, `ior = 0`). Probe further asserts no FCB-pool or filesystem state mutation: a subsequent ordinary `READ-FILE u1>0 fileid` reads from `FILE-POSITION` 0 (the zero-byte call did not advance the byte cursor).

4. **AC4** — the three probe blocks are wired into `Makefile`'s `test-repl` recipe with unique numeric IDs **965 (zero-byte)**, **966 (disk-full)**, **967 (directory-full)** (highest current ID is 964 per `Makefile:9002` Story-13.5.5 test 964). On iz-cpm, the zero-byte probe (965) reports PASS; the disk-full and directory-full probes (966, 967) either PASS deterministically (if iz-cpm's disk image reaches the limit) or are wired to **skip-with-rationale** rather than fail — iz-cpm's disk image is host-filesystem-bounded (`tests/file_access_tests.fth:456..463`). The hardware-smoke run is the load-bearing verdict for 966 / 967.

5. **AC5 (S9 hardware smoke)** — real CP/M 2.2 / MicroBeast hardware run captured in transcript `~/Downloads/beastty-<YYYYMMDD>-<HHMMSS>.bin`. (CR-1 correction 2026-05-09 — original spec text said `bestialitty-15-5-…`; the local terminal-recorder convention has shifted to `beastty-<date>-<time>` with no story-ID segment. Actual transcripts landed under the new convention; spec updated to match observed reality.) Transcript shows (a) all three probes execute against the live ramdisk; (b) the disk-full and directory-full probes hit their respective failure modes on real hardware (block-storage exhaustion + directory-entry exhaustion); (c) FCB-pool consistency assertions PASS; (d) post-failure clean re-OPEN-FILE / READ-FILE round-trip PASS. **Verdict disposition** per architecture `:294..299`: clean run → B.7 closes (a) "evaluation suffices"; defect surfaced (wrong `ior`, orphaned FCB, directory corruption, FCB-pool recovery failure) → Story 15.5.1 spawned per `feedback_verdict_only_audit.md` (verdict-only audit + standalone reproducer + fix-story).

6. **AC6** — `wc -c build/antforth.com` Δ = 0 vs. pre-edit baseline (probe-only addition; no `src/*.asm` change in this story per architecture `:625` "B.7/B.9 are test-only unless hardware reveals defects"). `make test-repl` reports **≥ baseline + new probes** PASS / 0 FAIL post-edit. `docs/PHASE-3-CARRY-FORWARD.md` rows for B.9 (currently default-open `:40`) and B.7 (currently default-open `:38`) updated at story close-out with verdict summary + B.7 disposition (a) or "Story 15.5.1 spawned per disposition (b)".

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count

### Story tasks

- [x] **Task 1 — Pre-edit baseline** (AC6)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record. (Story 15.1 close-out reported 24,995; re-measure per B.3, do not inherit.) **Measured: 24,995 bytes.**
  - [x] 1.2 — `make test-repl 2>&1 | tee /tmp/15-5-pre-edit.out`; record `grep -c '^PASS:' /tmp/15-5-pre-edit.out` (expected 973) and `grep -c '^FAIL:' /tmp/15-5-pre-edit.out` (expected 0). **Measured: 973 PASS / 0 FAIL.**
  - [x] 1.3 — Confirm hardware crash class is RESOLVED (memory `project_hardware_crash_audit.md`): MicroBeast firmware fix verified clean on real hardware 2026-04-28 (`PROBE.COM` all-P, antforth runs flawlessly). No firmware-side blocker for AC5's hardware run.
  - [x] 1.4 — Confirm highest test ID in current `Makefile` is 964 (Story 13.5.5 test 964 at `Makefile:9002`); allocate 965 (zero-byte), 966 (disk-full), 967 (directory-full). **Confirmed: highest is 964.**

- [x] **Task 2 — Author zero-byte READ-FILE probe** (AC3, AC4)
  - [x] 2.1 — Appended (s155-zb) section block to `tests/file_access_tests.fth` documenting test 965 intent (zero-byte no-op rule per §11.6.1.2080).
  - [x] 2.2 — Wired test 965 stanza into `Makefile` test-repl after test 964 (probe-id `T-S155-P1-ZBR-NOOP`); verdict regex `T65Z=0 0` AND `T65A=104`.
  - [x] 2.3 — Sanity-run on iz-cpm: **PASS** (`PASS: REPL test 965 — Story 15.5 (p1) zero-byte READ-FILE no-op per §11.6.1.2080 (T-S155-P1-ZBR-NOOP)`).

- [x] **Task 3 — Author disk-full probe** (AC1, AC4)
  - [x] 3.1 — Appended (s155-df) section block to `tests/file_access_tests.fth` documenting test 966 intent (disk-full / block-storage exhaustion).
  - [x] 3.2 — Probe pre-creates `B:CANARY.TXT` with content "Canary!"; outer loop caps at **1024 iterations × 512 bytes = 512KB** (probe-bounded, exceeds plausible MicroBeast B: ramdisk capacities); cap rationale documented inline in Makefile comment.
  - [x] 3.3 — Wired test 966 stanza with **PASS-or-SKIP-or-FAIL** verdict shape: `T6V=DISKFULL_OK + T6C=0 + T6R=Canary!` → PASS; `T6V=NO_LIMIT` → SKIP; otherwise FAIL.
  - [x] 3.4 — Sanity-run on iz-cpm: **SKIP** (`SKIP: REPL test 966 — disk-full not reachable on iz-cpm (host-filesystem-bounded; load-bearing verdict deferred to MicroBeast hardware run, AC5)`). Probe-bounded loop completed all 1024 iterations on iz-cpm without WRITE-FILE returning ior!=0.

- [x] **Task 4 — Author directory-full probe** (AC2, AC4)
  - [x] 4.1 — Appended (s155-dirf) section block to `tests/file_access_tests.fth` documenting test 967 intent (directory-full / directory-entry exhaustion per F2).
  - [x] 4.2 — Probe-bounded outer loop caps at **256 files** (covers small/medium CP/M ramdisks — 64..1024 directory-entry range; cap rationale documented inline).
  - [x] 4.3 — Wired test 967 stanza with PASS-or-SKIP-or-FAIL verdict (`T7V=DIRFULL_OK + T7R=Canary!` → PASS; `T7V=NO_LIMIT` → SKIP; otherwise FAIL).
  - [x] 4.4 — `CLN` cleanup loop deletes all created files at probe end (verified: `ls disk/b/` post-run shows only the original HELLO.FTH/HELLO.TXT/ONLYB.FTH; no F0000-F0255 orphans).
  - [x] 4.5 — Sanity-run on iz-cpm: **SKIP** (`SKIP: REPL test 967 — directory-full not reachable on iz-cpm (host-fs has no CP/M dir-entry cap; load-bearing verdict deferred to MicroBeast hardware run, AC5)`). Probe completed all 256 file creates without CREATE-FILE returning ior!=0.

- [x] **Task 5 — Pre-flight on iz-cpm before hardware run** (AC4, S2, S12)
  - [x] 5.1 — Full `make test-repl` post-edit: **974 PASS / 0 FAIL / 2 SKIP** (973 baseline + test 965 PASS = 974; tests 966 + 967 SKIP per host-bounded iz-cpm rationale). Zero regressions.
  - [x] 5.2 — Probe authoring discipline verified: each probe ends with `BYE` (per `tests/file_access_tests.fth:19` convention); test 965 uses PAD for the byte buffer (canonical transient per Story 14.1 / `tests/README.md`); tests 966 and 967 use `CREATE`-named buffers (BB / BR / NMB) for multi-parse survivors per Story 14.1 discipline (the buffers persist across REPL line boundaries, so PAD's same-line transient guarantee is insufficient).
  - [x] 5.3 — Probe-id strings unique vs. test 1..964 corpus: `T-S155-P1-ZBR-NOOP`, `T-S155-P2-DF`, `T-S155-P3-DIRF` (S155 prefix novel; verified by grep `T-S155` returns only the three new tests).

- [ ] **Task 6 — S9 hardware smoke on real MicroBeast** (AC5)
  - [x] 6.1 — Dev-agent half: `build/antforth.com` ready (24,995 bytes, Δ=0 vs. v2.0.0 tag — no rebuild required if the v2.0.0 image is already on the device). **Project-lead half:** transfer to MicroBeast pending.
  - [x] 6.2 — Dev-agent half: three probes staged as batched REPL paste blocks in Debug Log References above (Probe 1 / Probe 2 / Probe 3); expected-output verdict tokens documented inline (T65Z / T65A for 965; T6I / T6N / T6C / T6R / T6V for 966; T7I / T7N / T7R / T7V for 967). Probes 2 + 3 pre-stage `B:CANARY.TXT` inline at probe start (no separate canary-staging step required). **Project-lead half:** paste / type into REPL pending.
  - [x] 6.3 — Project-lead half: ran on MicroBeast. Transcript run-1 (`beastty-20260509-123943.bin`) PASSed test 965 cleanly but errored test 966/967 verdict lines (probe-design defect — IF/ELSE/THEN at REPL → -14). Probe verdict logic refactored into `: VERDICT ... ;` colon def + numeric codes; iz-cpm sanity-passed post-fix (974 PASS / 0 FAIL / 2 SKIP). Transcript run-2 (`beastty-20260509-125414.bin`) confirms all three probes clean on real MicroBeast: test 966 hit disk-full at 252×512-byte records, test 967 hit dir-full at 36 entries, all consistency assertions PASS.
  - [x] 6.4 — Verdict recorded in Debug Log References "Hardware verdict capture" block above. No anomalies — clean three-probe sweep, no orphaned FCBs, canary intact post-failure on both probes.

- [x] **Task 7 — Disposition B.7 (architecture `:294..299`)** (AC5)
  - [x] 7.1 — Task 6 transcript clean (no defect surfaced) → **B.7 disposition (a) "Evaluation suffices"**. B.7 row in `docs/PHASE-3-CARRY-FORWARD.md` closes with closure note citing transcript `~/Downloads/beastty-20260509-125414.bin` + three-probe verdict summary (965 / 966 / 967 all PASS on hardware; T6V=1 + T7V=1 + T65Z/T65A confirmed).
  - [x] 7.2 — N/A — disposition (b) NOT triggered (no wrong ior, orphaned FCB, directory corruption, or FCB-pool recovery failure observed). **Story 15.5.1 NOT spawned.**

- [x] **Task 8 — Update `docs/PHASE-3-CARRY-FORWARD.md`** (AC6)
  - [x] 8.1 — B.9 row added to Status Tracking table at `docs/PHASE-3-CARRY-FORWARD.md` (post-B.8): `✅ Done` with closure note citing Story 15.5, transcript `~/Downloads/beastty-20260509-125414.bin`, disk-full probe verdict (T6I=2 / T6N=252 / T6C=0 / T6R=Canary! / T6V=1; ~126 KB B: ramdisk capacity), and iz-cpm SKIP-with-rationale.
  - [x] 8.2 — B.7 row added (post-B.8): `✅ Done — disposition (a) "Evaluation suffices"` with three-probe verdict summary (965 / 966 / 967 all PASS on hardware), transcript citation, and the in-pass probe-design defect + fix narrative (verdict logic refactored into colon def + numeric codes after run-1's -14 surfaced the issue).
  - [x] 8.3 — Phase-3 cumulative ROM cap (NFR-P3-2): pre-15.5 cumulative was +0 bytes (Epic 14 + Story 15.1 zero-delta cluster); Story 15.5 delta = **0** (probe-only, no kernel surgery — verified by `wc -c build/antforth.com` = 24,995 bytes, identical to pre-edit). Post-15.5 cumulative: **+0 / 200 bytes** budget used.

- [x] **Task 9 — Post-edit binary + test regression check** (AC6)
  - [x] 9.1 — `wc -c build/antforth.com` post-edit = **24,995 bytes**; **Δ = 0** vs. Task 1.1 (probes are tests; no kernel change). ✓
  - [x] 9.2 — `make test-repl` post-edit on iz-cpm = **974 PASS / 0 FAIL / 2 SKIP** (973 baseline + test 965 PASS = 974; tests 966 / 967 SKIP per host-bounded iz-cpm rationale). Zero regressions on the 1..964 baseline. ✓
  - [x] 9.3 — `bash tools/check-doc-sync/check-doc-sync.sh` post-edit = `[advisory] doc-sync: 15 advisory item(s); 0 drift`. Advisory count = 15 (15 [advisory-section] items remain advisory-by-design per AC3(d) of Story 14.5; 3 [advisory-§] items already closed by Story 15.1; this story does not touch architecture or PRD so no §-ref or Story-cite drift expected — and none surfaced). ✓

- [x] **Task 10 — Sprint-status update + Change Log + File List**
  - [x] 10.1 — Updated `_bmad-output/implementation-artifacts/sprint-status.yaml`: `15-5-...` row transitioned **`backlog → in-progress → review`**. (CR-1 correction 2026-05-09 — original Task 10.1 text claimed pre-state was `ready-for-dev` per `git log`; `git show ab5ab5a:_bmad-output/implementation-artifacts/sprint-status.yaml` shows the committed pre-state was actually `backlog` — the dev agent mis-paraphrased an unstaged interim flip as the git-recorded state. Honest pre-state: `backlog`.) Status flipped to `in-progress` during Task 4 (sprint-status edit alongside story Status header flip), and to `review` at Task 10 close.
  - [x] 10.2 — File List authored below.
  - [x] 10.3 — Change Log authored below.

## Dev Notes

### Why this story matters

Story 13.6 (Epic 13 close-out) **explicitly punted** disk-full hardware verification: see `tests/file_access_tests.fth:456..463`. The probe-time decision was *"iz-cpm's disk image cannot be exhausted within a probe budget (host filesystem, not host-disk-free-bounded). Evidence captured as 'code-path traversal' — F_WRITE A != 0 path exists in src/file_access.asm and is exercised by the wrapper's existing ior return. Hardware re-verification deferred to Task 9 hardware smoke if budget permits."* The hardware-smoke task in Story 13.6 ran out of budget; B.9 was carried forward. Story 15.5 closes that loop.

The B.7 fork (`docs/PHASE-3-CARRY-FORWARD.md:38`, architecture `:294..299`) is intrinsically coupled to B.9: the same hardware run that exhausts block storage (B.9 — disk-full) also exhausts directory entries (B.7-component — directory-full) when the procedure shape splits per architecture finding F2 `:799..809`. Zero-byte READ-FILE is testable on iz-cpm (kernel behaviour, not filesystem-resource behaviour) and lands on iz-cpm's regression surface as test 965; the hardware run validates it under load alongside 966 / 967.

This is the only Phase-3 story (apart from any A.1 back-fill that didn't spawn) whose load-bearing verdict comes from real hardware rather than from iz-cpm + doc walk. S9 (hardware-smoke per binary-delta story) is normally invoked when the binary changes; here, S9 is invoked because the *probe* runs on hardware-only-meaningful resource exhaustion paths even though the binary doesn't move.

### Pre-known iz-cpm constraint

`tests/file_access_tests.fth:456..463` records the iz-cpm disk-image limitation that motivated Story 13.6's punt. The Story 15.5 design accepts this constraint structurally:
- Test 965 (zero-byte READ-FILE) — kernel behaviour, runs cleanly on iz-cpm.
- Test 966 (disk-full) — wired with SKIP-with-rationale on iz-cpm if the cap isn't reached; load-bearing verdict on hardware.
- Test 967 (directory-full) — same SKIP shape; load-bearing verdict on hardware.

The SKIP-with-rationale shape is documented inline in the test stanzas so a future reader understands the verdict-on-iz-cpm vs. verdict-on-hardware split.

### F2 sub-step distinction (architecture `:799..809`)

Disk-full and directory-full are **distinct** CP/M 2.2 failure modes:
- **Disk-full** = exhaustion of *block storage*. One large file written until block budget exhausted → `WRITE-FILE` returns non-zero `ior`.
- **Directory-full** = exhaustion of *directory entries*. CP/M directories are 64–128 entries on small disks, up to 1024 on larger ones — independent of block budget. Many small files `CREATE-FILE`'d until directory-entry budget exhausted → `CREATE-FILE` returns non-zero `ior`.

A single probe shape doesn't cover both; the architecture finding F2 explicit-split mandates two sub-step probes (AC1 + AC2 here). This story's three probes (zero-byte / disk-full / directory-full) are kept as three separate test stanzas with three separate Makefile IDs so the verdict surface is granular — each can be diagnosed independently from its individual `PASS:` / `FAIL:` / `SKIP:` line in the test-repl output.

### B.7 verdict-only audit fork (architecture `:294..299`, `feedback_verdict_only_audit.md`)

If hardware reveals a defect, Story 15.5.1 follows the verdict-only audit pattern from `feedback_verdict_only_audit.md` (memory note, 2026-04-29):
- Story 15.5 itself stops at the verdict (the captured transcript) — no source edits during Story 15.5's audit phase.
- Story 15.5.1 owns: standalone reproducer (smallest probe that exhibits the defect on hardware), fix in the appropriate `src/*.asm`, post-fix re-run, transcript filing, permanent probe in `tests/file_access_tests.fth`.
- ROM envelope per architecture `:518` (Story 15.5.1 AC5): ≤ +30 bytes; HALT signal if outside.

Hardware crash class precedent: Story 11.5.1 / 11.5.1.2 produced verdict (b) firmware-bug; the firmware fix landed without spawning antforth-side defensive saves (`memory project_hardware_crash_audit.md` — RESOLVED 2026-04-28). Same shape would apply if Story 15.5 surfaces a CP/M 2.2 BIOS quirk vs. an antforth-side defect: file the verdict, hand over a tractable reproducer, defer antforth-side fixes until the external maintainer has a chance.

### Phase-3 cumulative envelope check

NFR-P3-2 caps cumulative Phase-3 ROM growth at +200 bytes (24,996 → ≤ 25,200). Pre-15.5 cumulative (post-Epic-14, post-Story-15.1): **+0 bytes** (Story 15.1 was doc-only with comment-only `src/*.asm` citation fixes; Epic 14 was zero-delta). Story 15.5 expected delta: **0** (probe-only, test files only, no kernel surgery; architecture `:351` "B.9 = 0 (probe-only)"; architecture `:625` "B.7 / B.9 are test-only unless hardware reveals defects"). Post-15.5 cumulative: 0 / 200 budget used. If 15.5.1 spawns: +0..+30 bytes per architecture `:349` "B.7 = 0..+30 if probe story spawned". Plenty of headroom.

### Standing commitments

S1..S12 (NFR-P3-22..33) all hold:
- **S1** — adversarial review fresh-context external; this story's ACs do **not** enumerate "trigger an adversarial review pass" (per `instructions.xml:20..31`). The `CR` command runs separately at story-close.
- **S2** — REPL-piped tests are the regression surface; this story authors three new probes (965 / 966 / 967) in `tests/file_access_tests.fth` and wires them into `Makefile`'s `test-repl` recipe.
- **S3** — real-byte-count + capstone-aware; Pre-edit Task 1 re-`wc -c`s directly per B.3.
- **S4** — AC composition; the 6 ACs compose cleanly (AC1/2/3 produce probes; AC4 wires Makefile; AC5 captures hardware verdict; AC6 enforces zero binary delta + carry-forward closure).
- **S5** — HALT on PARTIAL ship; if iz-cpm sanity-pass succeeds but hardware run fails to be scheduled in this dev-pass, the story is `15-5.partial`-not-allowed — close `review` only after hardware verdict captured (Task 6).
- **S8** — "pre-existing" cannot discharge correctness defects; if hardware surfaces a defect, B.7 disposition (b) fires (Story 15.5.1) — no rationalisation.
- **S9** — hardware-smoke required (Task 6); the probes' load-bearing verdicts are hardware-only.
- **S10** — workflow > memory > prompt; the carry-forward closure rows in `docs/PHASE-3-CARRY-FORWARD.md` are the durable record, not memory notes.
- **S11** — not tag-applicable in this story (no banner change; Phase-3 close-out gate per `epics.md:522..532` is a separate checklist, replacing former Story 15.6).
- **S12** — hardware-typed probe authoring fully engaged: each probe ends `BYE`, uses canonical transient buffers per `tests/README.md`, has unique numeric ID across `Makefile`, and survives TIB-128 line-length.

### Project Structure Notes

Touch surface scoped to test harness + Makefile + carry-forward catalogue:
- **Modified (primary):** `tests/file_access_tests.fth` — three new section blocks (test 965 / 966 / 967) appended in canonical narrative shape per the existing test 905..964 precedent.
- **Modified (test wiring):** `Makefile` — three new `test-repl` recipe stanzas for tests 965 / 966 / 967, including expected-output regex check + matching `PASS:` / `SKIP:` / `FAIL:` echo lines per the test 905..964 precedent.
- **Modified (carry-forward catalogue):** `docs/PHASE-3-CARRY-FORWARD.md` — Status column update for B.9 (`✅ Done` with closure note) and B.7 (disposition (a) or (b) per Task 7).
- **Modified (sprint tracking):** `_bmad-output/implementation-artifacts/sprint-status.yaml` — `15-5-...` row status flip; if Task 7 fires disposition (b), append a new `15-5-1-*` row at `backlog`.
- **Created (transcript):** `~/Downloads/bestialitty-15-5-<YYYYMMDD>-<HHMMSS>.bin` — hardware-run capture (per Story 13.1 / 11.8 precedent — outside the repo, referenced by path in story Debug Log).
- **Conditionally created (only if Task 7 disposition (b) fires):** `_bmad-output/implementation-artifacts/15-5-1-*.md` — Story 15.5.1 file per `feedback_verdict_only_audit.md` shape.

No `src/*.asm` instruction changes in this story. No new EQUs. No new dictionary words. The deliverable is probe coverage + hardware verdict.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.5] (`:487..504`) — canonical 6-AC spec.
- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.5.1] (`:506..520`) — conditional fix-story canonical shape (only if Task 7 fires (b)).
- [Source: _bmad-output/planning-artifacts/architecture.md#B.7 + B.9] (`:292..312`) — combined-close-out shape, B.7-D1 conditional trigger, B.9-D1 disk-full probe shape.
- [Source: _bmad-output/planning-artifacts/architecture.md#F2] (`:799..809`) — disk-full vs. directory-full sub-step distinction.
- [Source: _bmad-output/planning-artifacts/architecture.md] (`:625`) — `src/file_access.asm` frozen for Phase 3 unless hardware reveals defects.
- [Source: _bmad-output/planning-artifacts/architecture.md] (`:349..351`) — per-story binary delta envelopes (B.7 / B.9 / B.7 conditional).
- [Source: docs/PHASE-3-CARRY-FORWARD.md] (`:38, :40`) — B.7 + B.9 carry-forward rows (currently default-open).
- [Source: tests/file_access_tests.fth] (`:456..463`) — Story 13.6 punt-rationale for hardware re-verification (the gap this story closes).
- [Source: tests/file_access_tests.fth] (`:1..19`) — test discipline conventions (REPL-piped probes, BYE-terminated, no raw BDOS in probes).
- [Source: Makefile] (`:9002`) — current highest test ID 964 (Story 13.5.5 test 964); allocate 965/966/967.
- [Source: _bmad-output/implementation-artifacts/15-1-ans-forth-core-compliance-audit-a-1.md] — prior story (closed 2026-05-09; doc-only audit, zero-delta).
- [Source: _bmad-output/implementation-artifacts/13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer.md] (`:271`) — `~/Downloads/bestialitty-<story>-<date>-<time>.bin` transcript-naming precedent.
- [Source: _bmad-output/implementation-artifacts/11-8-epic-11-benchmark-survivability-stress-and-regression-gate-ccd-4.md] (`:165`) — MicroBeast hardware-transfer precedent.
- [Source: memory `feedback_verdict_only_audit.md`] — verdict-only audit pattern for cross-stack defects.
- [Source: memory `project_hardware_crash_audit.md`] — RESOLVED 2026-04-28; no firmware-side blocker for AC5 hardware run.
- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml] (`:285`) — current 15-5 row status (`backlog`).
- DPANS94 §11.6.1.2080 (`READ-FILE`) — zero-byte READ-FILE no-op `( c-addr 0 fileid -- 0 0 )` rule (AC3 source-of-truth).

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

**Pre-edit baseline (Task 1, 2026-05-09):**
- `wc -c build/antforth.com` = **24,995 bytes** (re-measured per B.3, matches Story 15.1 close-out figure).
- `make test-repl` baseline: `grep -c '^PASS:' /tmp/15-5-pre-edit.out` = **973**, `grep -c '^FAIL:' /tmp/15-5-pre-edit.out` = **0**.
- Highest pre-edit test ID = **964** (Makefile:9002, Story 13.5.5 (p5)). Allocated 965 (zero-byte), 966 (disk-full), 967 (directory-full).
- Hardware crash class **RESOLVED 2026-04-28** per memory `project_hardware_crash_audit.md` — MicroBeast firmware fix verified clean (PROBE.COM all-P; antforth runs flawlessly). No firmware-side blocker for AC5.

**iz-cpm sanity-pass post-edit (Tasks 2..5, 2026-05-09):**
- `wc -c build/antforth.com` = **24,995 bytes** (Δ=0 vs. pre-edit; probe-only addition).
- `make test-repl` post-edit: **974 PASS / 0 FAIL / 2 SKIP** (973 baseline + test 965 PASS = 974; tests 966 + 967 SKIP per host-bounded iz-cpm rationale).
- Test 965 verdict on iz-cpm: `PASS: REPL test 965 — Story 15.5 (p1) zero-byte READ-FILE no-op per §11.6.1.2080 (T-S155-P1-ZBR-NOOP)`.
- Test 966 verdict on iz-cpm: `SKIP: REPL test 966 — disk-full not reachable on iz-cpm (host-filesystem-bounded; load-bearing verdict deferred to MicroBeast hardware run, AC5)`.
- Test 967 verdict on iz-cpm: `SKIP: REPL test 967 — directory-full not reachable on iz-cpm (host-fs has no CP/M dir-entry cap; load-bearing verdict deferred to MicroBeast hardware run, AC5)`.
- Cleanup verified: `ls disk/b/` post-run shows only the original `HELLO.FTH HELLO.TXT ONLYB.FTH` (no F0000-F0255 orphans, no DFTEST.TXT, no CANARY.TXT).

**Hardware-paste content (Task 6.2, dev-agent half) — 2026-05-09:**

The three probes below mirror the Makefile test-repl stanzas verbatim. Each ends with `BYE` so antforth exits cleanly on MicroBeast; re-launch `ANTFORTH.COM` between probes (each probe is a fresh dictionary).

Pre-flight on hardware:
1. Build/transfer per Story 11.8 Task 8.2 precedent (`build/antforth.com` = 24,995 bytes, Δ=0 vs. tagged v2.0.0; binary unchanged so no rebuild required if v2.0.0 image is already on the device).
2. Open transcript capture (e.g., `bestialitty` capture), name `~/Downloads/bestialitty-15-5-<YYYYMMDD>-<HHMMSS>.bin`.
3. Run each probe block below; observe printed verdict tokens.

**Probe 1 — Test 965 (zero-byte READ-FILE no-op per §11.6.1.2080):**

```forth
S" T965ZB.TXT" DELETE-FILE DROP
VARIABLE FA  S" T965ZB.TXT" R/W CREATE-FILE THROW FA !
S" hello" FA @ WRITE-FILE THROW  FA @ CLOSE-FILE THROW
S" T965ZB.TXT" R/O OPEN-FILE THROW FA !
S" T65Z=" TYPE PAD 0 FA @ READ-FILE . . CR
S" T65A=" TYPE PAD 1 FA @ READ-FILE DROP DROP PAD C@ . CR
FA @ CLOSE-FILE DROP  S" T965ZB.TXT" DELETE-FILE DROP
BYE
```

Expected output: `T65Z=0 0` on one line and `T65A=104` on the next (cursor not advanced; first byte = 'h' = 104).

**Probe 2 — Test 966 (disk-full / block-storage exhaustion, B.9):**

```forth
S" B:CANARY.TXT" DELETE-FILE DROP  S" B:DFTEST.TXT" DELETE-FILE DROP
VARIABLE FA  CREATE BB 512 ALLOT  CREATE BR 16 ALLOT
VARIABLE NRECS  VARIABLE FAILIOR  0 NRECS !  0 FAILIOR !
S" B:CANARY.TXT" R/W CREATE-FILE THROW FA !
S" Canary!" FA @ WRITE-FILE THROW  FA @ CLOSE-FILE THROW
S" B:DFTEST.TXT" R/W CREATE-FILE THROW FA !
: TRY-FILL 1024 0 DO BB 512 FA @ WRITE-FILE DUP IF FAILIOR ! LEAVE THEN DROP I 1+ NRECS ! LOOP ;
: PRT-FAIL S" T6I=" TYPE FAILIOR @ . CR  S" T6N=" TYPE NRECS @ . CR  S" T6C=" TYPE FA @ CLOSE-FILE . CR ;
: OPCAN S" B:CANARY.TXT" R/O OPEN-FILE THROW FA ! ;
: PRT-CAN OPCAN BR 7 FA @ READ-FILE DROP DROP S" T6R=" TYPE BR 7 TYPE CR FA @ CLOSE-FILE DROP ;
: VERDICT FAILIOR @ IF PRT-FAIL PRT-CAN 1 ELSE FA @ CLOSE-FILE DROP 0 THEN S" T6V=" TYPE . CR ;
TRY-FILL  VERDICT
S" B:DFTEST.TXT" DELETE-FILE DROP  S" B:CANARY.TXT" DELETE-FILE DROP
BYE
```

**CR-1 finding M1 — WITHDRAWN (false-positive 2026-05-09):** CR initially reported a stack leak in `TRY-FILL`'s failure path and proposed `… IF FAILIOR ! DROP LEAVE THEN …`. This was wrong — the original shape is correct: `WRITE-FILE` leaves only ONE cell (`ior`), `DUP` makes two, `IF` consumes one for the test, `FAILIOR !` consumes the second, `LEAVE` exits with a clean stack. The proposed extra `DROP` introduced a real **stack-underflow** that hardware re-run (`~/Downloads/beastty-20260509-134543.bin`) caught immediately as `error -4: stack underflow` on test 966's failure path. (iz-cpm sanity-passed the buggy version because iz-cpm never hits the failure path — the bug was on a code path that only executes when the disk is actually full.) Reverted to the original. **Lesson candidate:** any probe-shape change touching a code path that's only exercised on hardware (the failure path here) MUST be hardware-verified before claim — iz-cpm sanity-pass is necessary but not sufficient. Probe 2 verdict for AC1 remains load-bearing on the **run-2** transcript (`~/Downloads/beastty-20260509-125414.bin`); the run-3 -4 surface is on the withdrawn buggy variant, not the shipped probe.

Expected on hardware (disk-full path): `T6I=<nonzero-ior>`, `T6N=<records-written-before-fail>`, `T6C=0` (clean CLOSE-FILE on failed FCB), `T6R=Canary!` (canary readback intact), then `T6V=1`.

Expected (didn't exhaust; 512KB cap too low for the device's B: capacity): single line `T6V=0` — surface as Story 15.5.1 finding requiring a higher cap.

**Probe 3 — Test 967 (directory-full / dir-entry exhaustion, B.7):**

```forth
S" B:CANARY.TXT" DELETE-FILE DROP
VARIABLE FA  CREATE NMB 12 ALLOT  CREATE BR 16 ALLOT
VARIABLE NFILES  VARIABLE FAILIOR  VARIABLE CIM  0 NFILES !  0 FAILIOR !  0 CIM !
S" B:F" NMB SWAP MOVE  S" 0000.TXT" NMB 3 + SWAP MOVE
S" B:CANARY.TXT" R/W CREATE-FILE THROW FA !
S" Canary!" FA @ WRITE-FILE THROW  FA @ CLOSE-FILE THROW
: DGT [CHAR] 0 + ;
: STO4 DUP 1000 / DGT NMB 3 + C! DUP 1000 MOD 100 / DGT NMB 4 + C! DUP 100 MOD 10 / DGT NMB 5 + C! 10 MOD DGT NMB 6 + C! ;
: TRY-CREATE 256 0 DO I STO4 NMB 11 R/W CREATE-FILE DUP IF FAILIOR ! DROP LEAVE THEN
  DROP CLOSE-FILE CIM @ OR CIM ! I 1+ NFILES ! LOOP ;
: PRT-FAIL S" T7I=" TYPE FAILIOR @ . CR  S" T7N=" TYPE NFILES @ . CR  S" T7C=" TYPE CIM @ . CR ;
: OPCAN S" B:CANARY.TXT" R/O OPEN-FILE THROW FA ! ;
: PRT-CAN OPCAN BR 7 FA @ READ-FILE DROP DROP S" T7R=" TYPE BR 7 TYPE CR FA @ CLOSE-FILE DROP ;
: CLN NFILES @ 0 DO I STO4 NMB 11 DELETE-FILE DROP LOOP ;
: VERDICT FAILIOR @ IF PRT-FAIL PRT-CAN 1 ELSE 0 THEN S" T7V=" TYPE . CR ;
TRY-CREATE  VERDICT
CLN  S" B:CANARY.TXT" DELETE-FILE DROP
BYE
```

Expected on hardware (directory-full path): `T7I=<nonzero-ior>`, `T7N=<files-created-before-fail>`, `T7C=0` (per-iteration close-ior fold = 0; AC2 sub (b) literal coverage), `T7R=Canary!` (canary readback intact), then `T7V=1`.

Expected (didn't exhaust; 256-file cap too low for the device's B: directory size): single line `T7V=0` — surface as Story 15.5.1 finding requiring a higher cap.

**CR-1 fix H2 (2026-05-09):** original Probe 3 did `CLOSE-FILE DROP` per iteration, silently discarding any non-zero close-ior. CR found AC2 sub-assertion (b) "clean CLOSE-FILE on every successfully-acquired FCB" was unverified — dev agent's "structural rather than separately-asserted" rationale didn't satisfy the AC literal text. Probe now OR-folds per-iteration CLOSE-FILE ior into `CIM` and surfaces it as `T7C` in the failure verdict; Makefile PASS branch additionally requires `T7C=0`. **Line-length discipline:** the post-H2 `TRY-CREATE` definition is split across two source lines because the single-line form is 134 chars — over antforth's TIB-128 limit. Hardware re-run transcript (`~/Downloads/beastty-20260509-134543.bin`) initially showed TIB truncation at char 128 (`NFILES` mid-cut to `NFILE` + leftover `S ! LOOP ;` parsed as standalone words → `error -13: undefined word`); resolved by splitting the colon-def at the `THEN`-boundary (compile-mode line continuation across colon-def is fine). Both Makefile probe stanza and the paste block above now reflect the split form. **Hardware verdict (run-3):** `T7I=3 T7N=37 T7C=0 T7R=Canary! T7V=1` — directory-full reached at 37 entries (run-2 hit at 36; B: ramdisk format produced one extra entry this run, immaterial). **`T7C=0` confirms AC2 sub (b) literal coverage on real hardware** — every successfully-acquired FCB closed cleanly. Canary readback intact post-failure. All AC2 sub-assertions (a)/(b)/(c)/(d) now hardware-load-bearing.

**Hardware-run iteration history (Task 6.3 partial — 2026-05-09):**

- Run 1, transcript `~/Downloads/beastty-20260509-123943.bin`:
  - Probe 1 (test 965): **PASS** — `T65Z=0 0` and `T65A=104` confirmed on real MicroBeast hardware. Zero-byte READ-FILE no-op rule (§11.6.1.2080) verified.
  - Probe 2 (test 966): **iteration-defective** — `error -14: interpreting a compile-only word` raised on the bare-REPL `FAILIOR @ IF ... THEN` line (IF/ELSE/THEN are compile-only per ANS Forth; antforth correctly enforces this). TRY-FILL ran to completion (no THROW), but verdict was never printed. Net verdict: indeterminate — re-run required after probe fix.
  - Probe 3 (test 967): **iteration-defective** — same `error -14` on the `FAILIOR @ IF ... THEN` line. TRY-CREATE ran; CLN ran (cleanup confirmed). Verdict indeterminate — re-run required.
  - **Probe-design defect identified:** verdict logic placed at REPL interpret-state instead of compile-state. iz-cpm did not surface this defect because grep matched the literal `T6V=NO_LIMIT` / `T7V=NO_LIMIT` strings in the *echoed source line* of `S" T6V=NO_LIMIT" TYPE`, not in actual probe output — false-positive SKIP. Hardware run with bare verdict line is the canonical surface for this defect.
  - **Fix landed in Makefile + paste blocks:** verdict logic wrapped in `: VERDICT ... ;` colon definition (compile-only words now legitimately compiled inside `:`); numeric verdict codes (1 = OK, 0 = NO_LIMIT) replace string literals so source-echo can no longer false-positive grep matches. iz-cpm post-fix: 974 PASS / 0 FAIL / 2 SKIP — same shape as before, but SKIPs are now correctness-actual (verdict word ran, printed `T6V=0` / `T7V=0`).

- Run 3, transcript `~/Downloads/beastty-20260509-134543.bin` (CR-1 post-fix re-run):
  - Probe 1 (test 965): **PASS** — `T65Z=0 0` and `T65A=104` (re-confirms run-1).
  - Probe 2 (test 966): **`error -4: stack underflow`** on the failure path of `TRY-FILL`. Surfaces the **CR-1 M1 false-positive** — CR proposed adding `DROP` before `LEAVE` inside the `IF`, claiming a stack leak; the original was actually correct (WRITE-FILE leaves only one ior, DUP+IF consumes one, FAILIOR! consumes the other, LEAVE exits clean). The proposed extra DROP under-flows on the failure path. iz-cpm sanity-passed the buggy version because iz-cpm never reaches the failure path (no exhaustion). M1 reverted; probe 2's load-bearing verdict remains **run-2** (`beastty-20260509-125414.bin`, `T6I=2 T6N=252 T6C=0 T6R=Canary! T6V=1`).
  - Probe 3 (test 967): initial paste hit **TIB-128 truncation** on `TRY-CREATE` (line was 134 chars; `NFILES` cut mid-token to `NFILE` with leftover `S ! LOOP ;` parsed as standalone words → cascading `error -13: undefined word`). After three retry attempts, the project lead manually retyped the colon-def split across two lines at the `THEN`-boundary and the probe ran clean. Fix: split `TRY-CREATE` permanently in both Makefile stanza and story Probe 3 paste block. Run-3 verdict: **`T7I=3 T7N=37 T7C=0 T7R=Canary! T7V=1`** — directory-full reached at 37 entries; **`T7C=0` confirms AC2 sub (b) literal coverage on real hardware** (every successfully-acquired FCB closed cleanly).

**Hardware verdict capture (Task 6.4):**
- Transcript path (run 1): `~/Downloads/beastty-20260509-123943.bin` (probes 2/3 verdict indeterminate due to probe-design defect; re-run required).
- Transcript path (run 2 — combined): `~/Downloads/beastty-20260509-125414.bin` (clean verdict for probes 2 + 3 with fixed VERDICT colon-def + numeric codes; transcript also contains run 1's probe 1 PASS plus two failed paste attempts of the new probes — the third paste of each landed clean).
- Transcript path (run 3 — CR-1 post-fix re-run): `~/Downloads/beastty-20260509-134543.bin` (load-bearing for probe 3's post-H2 `T7C` assertion; also re-confirms probe 1; surfaced CR-1 M1 false-positive on probe 2 → M1 reverted, probe 2 verdict remains run-2-load-bearing).
- **Test 965 verdict: PASS (run 1, re-confirmed run 3)** — `T65Z=0 0` and `T65A=104` confirmed on real hardware. Zero-byte READ-FILE no-op rule (§11.6.1.2080) verified — read-with-u1=0 returns u2=0, ior=0; cursor not advanced (subsequent 1-byte READ from byte 0 returns 'h' = 104).
- **Test 966 verdict: PASS (run 2)** — disk-full reached on real MicroBeast B: ramdisk after **252 × 512-byte records ≈ 126 KB**. Outputs: `T6I=2` (WRITE-FILE ior=2, antforth wrapper "F_WRITE returned non-zero" → block-storage exhaustion); `T6N=252` (records before failure); `T6C=0` (CLOSE-FILE on the failed FCB returned ior=0 — no orphaned FCB); `T6R=Canary!` (B:CANARY.TXT re-OPEN-FILE / READ-FILE round-trip intact post-failure — filesystem consistency); `T6V=1` (verdict DISKFULL_OK). All AC1 sub-assertions (a)/(b)/(c) satisfied. (Run-3 attempted to re-confirm with the CR-1 M1 "fix" applied; that fix proved a false-positive that introduced a real -4 stack underflow on the failure path — reverted; probe 2's run-2 verdict is unchanged and remains load-bearing.)
- **Test 967 verdict: PASS (run 3 — post-H2 fix)** — directory-full reached on real MicroBeast B: ramdisk after **37 successful CREATE-FILE entries** (run-2 hit at 36; run-3 hit at 37 — single-entry variance from RAM-disk re-format, immaterial). Outputs: `T7I=3` (CREATE-FILE ior=3, antforth wrapper directory-entry exhaustion); `T7N=37` (entries before failure); **`T7C=0`** (per-iteration CLOSE-FILE ior fold = 0 — every successfully-acquired FCB closed cleanly; **AC2 sub (b) literal coverage**); `T7R=Canary!` (canary round-trip intact); `T7V=1` (verdict DIRFULL_OK). All AC2 sub-assertions (a)/(b)/(c)/(d) satisfied on hardware. The 256-file probe cap was more than sufficient (37 < 256) — no Story 15.5.1 cap-bump needed.
- **B.7 disposition (per architecture `:294..299`): (a) "Evaluation suffices"** — clean hardware run; all three probes hit their failure modes (or no-op, for 965), all consistency assertions PASS, no orphaned FCBs, no directory corruption, no FCB-pool recovery failure, canary readback intact post-failure. **Story 15.5.1 NOT spawned.** B.7 row closes (a) with this story; B.9 row closes ✅ Done with this story.

**Hardware ior wrapper notes (architectural — observed in run 2):**
- WRITE-FILE returned ior=2 on disk-full (block-storage exhaustion). antforth's wrapper layer maps CP/M F_WRITE return codes to ior values per `src/file_access.asm`; ior=2 is the documented "F_WRITE non-zero" path.
- CREATE-FILE returned ior=3 on directory-full (directory-entry exhaustion). antforth's wrapper maps F_MAKE 0xFF to ior=3 (or similar — confirm by inspection if needed).
- These are wrapper-determined non-zero `ior`s, not THROW codes. AC1 / AC2 require only "non-zero ior", not specific values, so the verdict is unambiguous PASS regardless of exact ior code. Documenting the observed values for forward reference.

### Completion Notes List

- **Story 15.5 closed `done` 2026-05-09 post-CR-1.** All 6 ACs satisfied (AC2 sub (b) literal hardware coverage now load-bearing on run-3); Phase-3 carry-forward rows B.7 (disposition (a)) and B.9 closed. Story 15.5.1 NOT spawned (no defect surfaced on hardware).
- **Hardware run summary across three transcripts** (run-2 + run-3 jointly load-bearing for the close-out):
  - **Test 965 (zero-byte READ-FILE no-op per §11.6.1.2080)** — verdict from run-1 + run-2 + run-3 (consistent across all three): `T65Z=0 0` + `T65A=104` — kernel rule satisfied, byte cursor not advanced.
  - **Test 966 (disk-full / B.9)** — verdict from run-2 (`beastty-20260509-125414.bin`): `T6I=2 T6N=252 T6C=0 T6R=Canary! T6V=1` — disk-full reached at ~126 KB on B: ramdisk; no orphaned FCB; canary readback intact post-failure. (Run-3 attempt with CR-1 M1 "fix" applied surfaced -4 stack underflow proving M1 was a false-positive finding; reverted.)
  - **Test 967 (directory-full / B.7)** — verdict from run-3 (`beastty-20260509-134543.bin`, post-CR-1 H2 fix): `T7I=3 T7N=37 T7C=0 T7R=Canary! T7V=1` — directory exhausted at 37 entries; **`T7C=0` confirms every successfully-acquired FCB closed cleanly (AC2 sub (b) literal coverage)**; canary readback intact post-failure (no directory corruption).
- **Probe-design defect surfaced + corrected mid-pass (lesson candidate):** initial probes 966 + 967 placed verdict logic `IF/ELSE/THEN` at REPL interpret state, which raises `error -14: interpreting a compile-only word` per ANS Forth (correctly enforced by antforth). iz-cpm did not surface this defect because grep matched the literal `T6V=NO_LIMIT` string in the *echoed source line* of `S" T6V=NO_LIMIT" TYPE` rather than in actual probe output — false-positive SKIP. Real-hardware run was the canonical surface. Fix: wrap verdict logic in `: VERDICT ... ;` colon def (compile-only words now legitimately compiled inside `:`); replace string-literal verdict tokens with numeric codes (1 = OK, 0 = NO_LIMIT) so source-echo can no longer false-positive grep matches. **Forward-pointer for retro:** "iz-cpm-vs-hardware verdict-shape divergence" — REPL-state-leakage in iz-cpm output (echo-grep false-positive) is a recurring failure mode for hardware-typed probes; a check that "verdict tokens grep only in actual probe output, not source-echo" should be standing probe-authoring discipline.
- **Wrapper ior values observed on hardware (forward reference):** WRITE-FILE returned ior=2 on disk-full; CREATE-FILE returned ior=3 on directory-full. AC1/AC2 require only "non-zero ior", so verdict is unambiguous PASS regardless. Documented for any future ior-table audit.
- **Zero binary delta (NFR-P3-2 Phase-3 cumulative):** `wc -c build/antforth.com` = 24,995 bytes pre- and post-edit. Cumulative Phase-3 ROM growth: **0 / 200 bytes** budget used after 6 stories (Epic 14: 5 stories doc/process; Story 15.1: doc-only audit; Story 15.5: probe-only addition).

### File List

Modified:
- `tests/file_access_tests.fth` — appended Story 15.5 narrative section (s155-zb / s155-df / s155-dirf) documenting the three new probes' intent, verdict regex, and iz-cpm-vs-hardware verdict-shape rationale.
- `Makefile` — wired three new test-repl stanzas (965 / 966 / 967) after the existing test 964 block, including the post-hardware-run fix (verdict-as-colon-def with numeric codes).
- `docs/PHASE-3-CARRY-FORWARD.md` — added B.7 closure row (disposition (a) "Evaluation suffices") and B.9 closure row (`✅ Done`) in Status Tracking table; both cite hardware transcript + verdict tokens.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `15-5-...` row: `ready-for-dev → in-progress → review`.
- `_bmad-output/implementation-artifacts/15-5-filesystem-stress-hardware-sprint-disk-full-directory-full-zero-byte-read-file-b-7-b-9.md` (this file) — Status header flipped to `review`; Tasks/Subtasks all `[x]`; Dev Agent Record + File List + Change Log filled.

Created: none (Story 15.5.1 not spawned per disposition (a)).

Deleted: none.

Hardware-run transcripts (outside repo, referenced by path):
- `~/Downloads/beastty-20260509-123943.bin` — run 1: probe 1 PASS; probes 2/3 verdict indeterminate (probe-design defect — `IF/ELSE/THEN` at REPL → -14).
- `~/Downloads/beastty-20260509-125414.bin` — run 2: probes 2/3 PASS with fixed verdict word; **load-bearing for test 966 (B.9 disk-full closure)**.
- `~/Downloads/beastty-20260509-134543.bin` — run 3: CR-1 post-fix re-run; probe 1 re-confirmed; probe 3 PASS with new `T7C=0` assertion (**load-bearing for test 967, AC2 sub (b)**); probe 2 surfaced + reverted CR-1 M1 false-positive finding (extra `DROP` introduced -4 stack underflow on the failure path — original probe 2 was correct, run-2 verdict unchanged).

### Change Log

| Date | Author | Note |
|------|--------|------|
| 2026-05-09 | Dev (claude-opus-4-7 1M ctx) | Story 15.5 dev-pass: authored probes 965 / 966 / 967 (`tests/file_access_tests.fth` + `Makefile`); iz-cpm sanity-pass clean (974 PASS / 0 FAIL / 2 SKIP); hardware run on MicroBeast surfaced probe-design defect (REPL-state `IF/ELSE/THEN` → -14); refactored verdict logic into `: VERDICT ... ;` colon def + numeric codes; second hardware run clean (test 966 disk-full at ~126 KB; test 967 dir-full at 36 entries; all consistency assertions PASS). B.7 disposition (a) "Evaluation suffices"; B.9 closed. Story 15.5.1 not spawned. Zero binary delta (24,995 bytes). |
| 2026-05-09 | CR (claude-opus-4-7 1M ctx) | CR-1 sweep — addressed 2 HIGH + 3 MEDIUM findings: **H1** narrative drift in `tests/file_access_tests.fth` (comments documented obsolete `T6V=DISKFULL_OK` / `T6V=NO_LIMIT` / `T7V=DIRFULL_OK` / `T7V=NO_LIMIT` string-token verdict shape; rewritten to numeric-code `T6V=1`/`T6V=0`/`T7V=1`/`T7V=0` shape with rationale + cross-reference to first hardware transcript). **H2** AC2 sub (b) literal coverage gap (probe 3's `TRY-CREATE` silently DROPped per-iteration `CLOSE-FILE` ior — added `CIM` variable that OR-folds per-iteration close-iors; surfaced as `T7C` in failure verdict; Makefile PASS branch additionally requires `T7C=0`). **M1** *withdrawn* — proposed adding `DROP` before `LEAVE` in `TRY-FILL`; the original probe was actually clean and the proposed fix introduced a real -4 stack underflow on the failure path that hardware run-3 surfaced. Reverted. Lesson: hardware-only code paths cannot be validated by iz-cpm sanity-pass alone. **M2** Task 10.1 sprint-status pre-state mis-narrated (claimed `ready-for-dev` per git log; actual `git show ab5ab5a:…` shows `backlog`; corrected). **M3** transcript-naming mis-spec (story-spec text said `bestialitty-15-5-…`; actual transcripts landed under `beastty-<date>-<time>`; spec corrected). |
| 2026-05-09 | CR (claude-opus-4-7 1M ctx) | CR-1 hardware re-run on real MicroBeast (transcript `~/Downloads/beastty-20260509-134543.bin`). Probe 1 re-confirmed clean. Probe 2 surfaced CR-1 M1 false-positive (-4 stack underflow → reverted; probe 2 verdict remains run-2-load-bearing). Probe 3 initial paste hit TIB-128 truncation (post-H2 `TRY-CREATE` line was 134 chars; cut at `NFILE` mid-token); **split `TRY-CREATE` across two source lines** at the `THEN`-boundary in both Makefile stanza and story Probe 3 paste block; iz-cpm re-pass clean (974 PASS / 0 FAIL / 2 SKIP unchanged); hardware re-paste in split form ran clean. Run-3 final verdict for probe 3: **`T7I=3 T7N=37 T7C=0 T7R=Canary! T7V=1`** — `T7C=0` confirms AC2 sub (b) literal hardware coverage. All 6 ACs now hardware-load-bearing. Story status `review → done`. Zero binary delta (24,995 bytes). |
