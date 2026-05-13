# Story 16.1: CCP eviction hardware-verification spike + memory-map page-allocation survey

Status: done

<!-- Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!--
First story of Epic 16 (Phase-4 prework — memory map, emulator pick,
design lock), authored 2026-05-11 against `epics-phase4-epics-16-22.md`
(lastEdited 2026-05-10). Story 15.5 (Phase-3 close-out's filesystem
hardware sprint) landed clean 2026-05-09: 974 PASS / 0 FAIL / 2 SKIP,
B.7 disposition (a), B.9 done, hardware transcript clean (no orphaned
FCBs, canary intact). v2.0.0 was tagged 2026-05-07 (commit 6599d73).
Phase-3 close-out gate replaced by checklist; epic-15 closed
2026-05-09.

Story 16.1 is the first Phase-4 binary-delta-free story. Its job:
deliver the F3 verification transcript (CCP eviction at $D400–$DBFF
is safe — BIOS reloads CCP from disk on warm-boot per CP/M 2.2 BIOS
warm-boot semantics) so Epic 17+ can consume the +2 KB Page-3
headroom for the descriptor-stub allocator without risking a stranded
warm-boot state on real MicroBeast. The hardware-typed transcript IS
the deliverable; S9 hardware-smoke (NFR-P4-11) is explicitly exempt
for binary-delta stories' usual reason — Story 16.1 has zero binary
delta and the hardware run is the verification itself.

Secondary deliverable: the Page 0–3 page-allocation survey
(architecture readiness for downstream Epic-17 stories that touch the
MMU). Source-of-truth citations per page come from MicroBeast
schematic, CP/M 2.2 BIOS source, and `docs/antforth-banking-redesign.md`
§5.1 page-allocation map / §5.2 CP/M residency layout.

F3 disposition fork (architecture `:862..868`):
  PASS → F3 closes with closure note citing Story 16.1, transcript
         path, and verdict; +2 KB Page-3 headroom is consumable by
         Story 17.1 (the kernel-end-moves-up edit).
  FAIL → Story 16.1.1 spawned per `feedback_verdict_only_audit.md`
         with +50 B envelope per architecture `:866` mitigation
         (restore-on-warm-boot kernel addition).

The hardware-crash class (memory `project_hardware_crash_audit.md`)
was RESOLVED 2026-04-28 — MicroBeast firmware fix verified clean on
real hardware (PROBE.COM all-P, antforth runs flawlessly). No
firmware-side blocker for the AC1 hardware run.
-->

## Story

As **Ant the project lead** (PRD Journey author / Phase-4 prework owner),
I want a hardware-verified transcript confirming CCP eviction at `$D400–$DBFF` is reloadable by CP/M 2.2 BIOS on warm-boot,
So that Epic 17+ can consume the +2 KB Page-3 headroom for the descriptor-stub allocator without risking a stranded warm-boot state on real MicroBeast — closing F3 and unblocking the kernel-end-moves-up edit slated for Story 17.1.

## Acceptance Criteria

1. **AC1 (one-shot kernel patch + hardware transcript)** — a one-shot kernel patch (not committed) zeroes the CCP region `$D400–$DBFF` at antforth startup, runs antforth on real CP/M 2.2 / MicroBeast, then exits via `^C` (or `BYE`); a hardware transcript captures the warm-boot path. The transcript shows the CCP prompt returns clean (BIOS reloads CCP from disk on warm-boot per CP/M 2.2 BIOS warm-boot semantics) without crash, stranded state, or dictionary corruption. *(L1-correction 2026-05-13: the canonical LDIR fill idiom is 13 bytes (3+3+3+2+2 for `LD HL,nn` / `LD DE,nn` / `LD BC,nn` / `LD (HL),0` / `LDIR`); the original "~9 bytes" estimate in Task 2.1 was wrong.)*

2. **AC2 (verdict fork)** — if AC1's transcript shows a stranded state (CCP not reloaded, system unresponsive after ^C, corrupted dictionary, or any anomaly attributable to the zeroed CCP region), a follow-up restore-on-warm-boot story (`16.1.1-*`) is spawned with a **+50 B kernel envelope** per F3 mitigation (architecture `:866`); otherwise F3 is closed and the action item dropped.

3. **AC3 (transcript artifact)** — the AC1 hardware transcript is captured as a `~/Downloads/beastty-<YYYYMMDD>-<HHMMSS>.bin` file per the Story 15.5 transcript-naming precedent (CR-1 correction 2026-05-09 — `beastty-` prefix, no story-ID segment), and a derived markdown summary committed to `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` carrying date, hardware revision, transcript-binary path, transcript-verbatim block (or relevant excerpts if the binary is too large to inline), and verdict (`PASS` / `FAIL-spawning-16.1.1`).

4. **AC4 (F3 closure in architecture)** — `_bmad-output/planning-artifacts/architecture.md` Finding F3 (architecture `:862..868`) is updated from "Issue" / "Mitigation" / "Action" tripartite to **`Closed by Story 16.1, <date>, verdict PASS`** (or `FAIL-spawning-16.1.1` if the spike fails). The F3 row's body text is preserved for archaeology; the closure line is appended as a final paragraph or row-status flip.

5. **AC5 (future-edit reference in Dev Notes)** — the Phase-4 memory-map declaration draft (the `src/antforth.asm` edit that will move `kernel_end:` up by 2 KB, reclaiming `$D400–$DBFF` for the descriptor-stub allocator + `bank-table[]`) is captured in this story's Dev Notes as a future-edit reference for Story 17.1; the edit itself does NOT ship in Story 16.1 (zero binary delta is a hard AC of this story per AC7).

6. **AC6 (Page 0–3 page-allocation survey)** — a Page 0–3 page-allocation survey is committed either as a new section in `_bmad-output/planning-artifacts/architecture.md` (under "Phase-4 memory map") or as a dedicated `docs/phase4-memory-map.md`. Each MMU page from `0x00..0x3F` is named with its assignment (BIOS / BDOS / CCP / Zero-page / Application / Virtual-console / RAM-disk / Banks-available), citing the source-of-truth for each assignment: BIOS source / CP/M 2.2 documentation / MicroBeast hardware schematic / `docs/antforth-banking-redesign.md` §5.1–§5.2. Survey table has at minimum one row per page in the `0x20..0x3F` range (the slot-mapped pages); pages below `0x20` are summarised by range if the assignment is uniform.

7. **AC7 (zero binary delta + S9 exempt)** — `wc -c build/antforth.com` reports **24,995 bytes** unchanged from the Phase-3 close-out baseline (per Story 15.5 Task 1.1, post-edit identical). Story dev-pass produces **zero binary delta**. S9 hardware-smoke (NFR-P4-11) is **exempt** with explicit rationale: *"Zero binary delta — the AC1 hardware transcript IS the verification."* The exemption is recorded explicitly in this story's Dev Notes per NFR-P4-11's "Zero-binary-delta stories document their S9 exemption explicitly" clause.

8. **AC8 (regression baseline preserved)** — `make test-repl` reports **≥ 974 PASS / 0 FAIL / 2 SKIP** on iz-cpm (Phase-3 close-out baseline preserved per FR-P4-41 / NFR-P4-10); zero regressions against tests 1..968 (highest current ID — test 968 is the A.2 caught-form coverage probe added via direct commit per Lesson 14-F between Story 15.5 close and Story 16.1 start, taking the baseline from 974 PASS to 975 PASS; this story adds no new tests).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count

### Story tasks

- [x] **Task 1 — Pre-edit baseline** (AC7, AC8)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record. Story 15.5 close-out reported 24,995 bytes; re-measure per B.3 (do not inherit). **Expected: 24,995 bytes.**
  - [x] 1.2 — `make test-repl 2>&1 | tee /tmp/16-1-pre-edit.out`; record `grep -c '^PASS:' /tmp/16-1-pre-edit.out` (expected 974 pre-Lesson-14-F or 975 post-Lesson-14-F direct-commit test 968), `grep -c '^FAIL:' /tmp/16-1-pre-edit.out` (expected 0), `grep -c '^SKIP:' /tmp/16-1-pre-edit.out` (expected 2). **Expected: 974 or 975 PASS / 0 FAIL / 2 SKIP.**
  - [x] 1.3 — Confirm hardware crash class is RESOLVED (memory `project_hardware_crash_audit.md`): MicroBeast firmware fix verified clean on real hardware 2026-04-28 (PROBE.COM all-P, antforth runs flawlessly). No firmware-side blocker for AC1's hardware run.
  - [x] 1.4 — `bash tools/check-doc-sync/check-doc-sync.sh` pre-edit → **TOOL FATAL** (`[fatal] required input file missing or unreadable: _bmad-output/planning-artifacts/epics.md`); `epics.md` was deleted in commit `51bc6d6` (2026-05-10) when the canonical epic catalogue was split into per-phase files. No advisory/drift count obtainable. Pre-existing tool defect orthogonal to Story 16.1; fix carried forward to Story 16.2 (doc-lock — natural Phase-4 doc-bookkeeping vehicle). Task closed per "execute to the maximum extent possible within story scope" + surface-and-file convention (memory `feedback_no_preexisting_discharge.md` — defect filed, not buried).

- [x] **Task 2 — Author the one-shot CCP-zero-out kernel patch** (AC1)
  - [x] 2.1 — Author a minimal, uncommitted patch to `src/antforth.asm` (or `src/system.asm` — wherever it lands cleanly without touching unrelated init code) that, immediately after the existing user-area init and before the boot banner, writes zero bytes across `$D400..$DBFF` (2 KB = 2048 bytes). Implementation hint: `LD HL, $D400 / LD DE, $D401 / LD BC, $07FF / LD (HL), 0 / LDIR` is the canonical Z80 fill idiom (~9 bytes of patch code; transient — never committed).
  - [x] 2.2 — `make` to build the patched binary; record the patched `wc -c build/antforth.com` for diagnostic only (this build IS NOT the AC7 artifact; the AC7 verdict is measured against an unpatched binary AFTER the patch is reverted at Task 5).
  - [x] 2.3 — iz-cpm sanity-run on the patched binary: confirm antforth still boots (zeroing $D400-$DBFF must not crash the kernel's own init — the kernel lives below $D400 at current 24,995 bytes ≈ `$0100 + $6196 = $6296`, well clear of the CCP region). Confirm `BYE` returns to iz-cpm's emulated CCP cleanly (or as cleanly as iz-cpm's CCP-substitute behaves — iz-cpm's CCP is NOT a real CP/M 2.2 CCP, so this sanity-run is for "antforth still works with CCP zeroed", NOT for the F3 verification itself).
  - [x] 2.4 — Stage the patched `build/antforth.com` for hardware transfer per the existing transfer convention (`disk/` upload or USB / serial — whatever the current MicroBeast workflow uses).

- [x] **Task 3 — Hardware run + transcript capture** (AC1, AC3)
  - [x] 3.1 — Project-lead half: transfer the patched `build/antforth.com` (from Task 2.4) to the MicroBeast B: ramdisk (or wherever the antforth.com binary normally lives). Start the terminal recorder per the Story 15.5 precedent (`beastty-<YYYYMMDD>-<HHMMSS>.bin` naming).
  - [x] 3.2 — Boot CP/M 2.2 on real MicroBeast hardware to the CCP prompt. Confirm CCP prompt is healthy (e.g., `DIR` lists the disk; `STAT` reports drive state). Capture this pre-state in the transcript as the baseline.
  - [x] 3.3 — From the CCP prompt, run the patched `antforth.com`. Confirm the antforth banner prints and the REPL is responsive. Type a minimal sanity probe at the REPL (e.g., `1 2 + .` → expect `3 ok`). Do NOT run a heavy test batch — the load-bearing verdict is the warm-boot, not the kernel's own behaviour.
  - [x] 3.4 — From the antforth REPL, exit via either `BYE` (clean exit) or `^C` (warm-boot interrupt — per CP/M 2.2 convention, ^C from CCP triggers warm-boot; whichever path the antforth REPL exposes; both produce a CP/M 2.2 BIOS warm-boot, which is the load-bearing event for F3). The transcript captures the CCP prompt return.
  - [x] 3.5 — At the returned CCP prompt: confirm CCP is responsive (e.g., `DIR` works, `STAT` works, a second `antforth.com` invocation works). This is the F3 verification: if the BIOS warm-boot reloaded the CCP from disk despite the antforth-startup zero-fill, the CCP prompt is healthy; if the CCP is still zeroed (or partially zeroed) and the prompt is dead / crashes / corrupts, F3 verification FAILS.
  - [x] 3.6 — Save the transcript binary to `~/Downloads/beastty-<YYYYMMDD>-<HHMMSS>.bin`; note the path in the story Debug Log References.

- [x] **Task 4 — Transcript artifact + verdict disposition** (AC2, AC3, AC4)
  - [x] 4.1 — Author `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` containing: (a) date and time of the hardware run, (b) MicroBeast hardware revision and CP/M 2.2 source notes (e.g., what disk image / what BIOS), (c) path to the captured `~/Downloads/beastty-<YYYYMMDD>-<HHMMSS>.bin` file, (d) transcript-verbatim block — paste relevant excerpts inline (CCP-prompt-pre-state, antforth-banner, sanity-probe result, exit, CCP-prompt-post-warm-boot); a full-binary inline is not required since the binary is captured separately, (e) verdict line: `PASS — CCP prompt clean after warm-boot; F3 closes` or `FAIL — <observed anomaly>; Story 16.1.1 spawned per F3 mitigation`.
  - [x] 4.2 — If verdict is **PASS**: proceed to Task 5 (revert the patch and finalise).
  - [x] 4.3 — If verdict is **FAIL**: spawn Story 16.1.1 per `feedback_verdict_only_audit.md` shape (verdict-only audit story + standalone reproducer + fix-story). Append the `16.1-1-*: backlog` row to `_bmad-output/implementation-artifacts/sprint-status.yaml` after the `16-1-...` row. Story 16.1.1's envelope is +50 B per architecture `:866`. Story 16.1 itself stops at the verdict — no source edits during the audit phase per the verdict-only audit pattern (memory `feedback_verdict_only_audit.md`, 2026-04-29). Story 16.1's `Status:` flips to `review` once the verdict artifact lands; 16.1.1 owns the fix.
  - [x] 4.4 — Update `_bmad-output/planning-artifacts/architecture.md` F3 row (lines `:862..868`): append closure line `**Closed by Story 16.1, <YYYY-MM-DD>, verdict PASS — CCP reloaded from disk by BIOS on warm-boot per CP/M 2.2 spec; +2 KB Page-3 headroom safe to consume in Epic 17+.**` (or the FAIL variant). Preserve the existing Issue / Mitigation / Action body for archaeology.

- [x] **Task 5 — Revert patch and re-build canonical binary** (AC7)
  - [x] 5.1 — Revert the Task 2.1 patch from `src/*.asm`. Confirm no patch residue remains (`git diff src/` returns empty against the pre-patch tree state — Story 16.1's source-tree footprint is documentation only).
  - [x] 5.2 — `make clean && make` to rebuild the canonical `build/antforth.com`. `wc -c build/antforth.com` → expect **24,995 bytes** (Δ=0 vs. Task 1.1). If the byte count drifts from 24,995, HALT — the patch revert was incomplete or unrelated source changes leaked in.
  - [x] 5.3 — Re-run `make test-repl` post-patch-revert → expect **974 PASS / 0 FAIL / 2 SKIP** unchanged. Zero regressions confirmed.

- [x] **Task 6 — Future-edit reference for Story 17.1** (AC5)
  - [x] 6.1 — In this story's Dev Notes (the section below), capture the Phase-4 memory-map declaration draft: the specific `src/antforth.asm` line(s) (currently `kernel_end:` at `src/antforth.asm:290`) that Story 17.1 will edit to move the kernel-end up by 2 KB, reclaiming `$D400–$DBFF` for the descriptor-stub allocator + `bank-table[]` shell. The capture is a forward-reference for Story 17.1's developer; it does NOT ship as a kernel edit in this story.
  - [x] 6.2 — Note that the actual layout decision (where exactly the `bank-table[]` base lives within $D400-$DBFF; how the descriptor-stub allocator carves the remaining region; per-entry stub size pin from §9.5) lands in Story 17.1 / 18.1 — Story 16.1's responsibility is verification that the region is safe to consume, not the layout.

- [x] **Task 7 — Page 0–3 page-allocation survey** (AC6)
  - [x] 7.1 — Decide artifact location: append a new "Phase-4 memory map" section to `_bmad-output/planning-artifacts/architecture.md` OR create `docs/phase4-memory-map.md` as a dedicated file. Recommendation: a dedicated `docs/phase4-memory-map.md` (so the architecture document is not bloated by an enumeration table; the architecture document cross-references the new file). Capture the choice rationale inline.
  - [x] 7.2 — Author the survey table: one row per page in `0x20..0x3F` (the slot-mapped pages — 32 rows; rows for pages below `0x20` may be summarised by range if uniform). Columns: `Page | Address-range-when-mapped | Assignment | Source-of-truth`. Example rows:
    - `0x20 | $0000–$3FFF (slot 0) | Kernel page 0 (fixed) | docs/antforth-banking-redesign.md §5.1`
    - `0x21 | $4000–$7FFF (slot 1) | Kernel page 1 (fixed) | docs/antforth-banking-redesign.md §5.1`
    - `0x22 | $8000–$BFFF (slot 2 default) | Portal page = DEFAULT BANK 0 | docs/antforth-banking-redesign.md §5.1`
    - `0x23 | $C000–$FFFF (slot 3) | Stacks / user / CCP-eaten / BDOS / BIOS (fixed) | docs/antforth-banking-redesign.md §5.1, §5.2`
    - `0x24 | (when mapped in slot 2) | Virtual console buffer (reusable; +1 bank if reclaimed) | docs/antforth-banking-redesign.md §5.1`
    - `0x25–0x34 | (when mapped in slot 2) | RAM disk pages (reusable; +16 banks if reclaimed) | docs/antforth-banking-redesign.md §5.1`
    - `0x35–0x3F | (when mapped in slot 2) | DEFAULT BANKS 1–11 | docs/antforth-banking-redesign.md §5.1`
  - [x] 7.3 — Within slot 3 (`$C000–$FFFF` when page 0x23 is mapped), produce a sub-table covering the CP/M residency layout per redesign §5.2:
    - `$D400–$DBFF | CCP | DISPOSABLE (Story 16.1 closes F3) | docs/antforth-banking-redesign.md §5.2`
    - `$DC00–$E9FF | BDOS | Must stay; CALL 0005h works from banked code | docs/antforth-banking-redesign.md §5.2`
    - `$EA00+    | BIOS | IM 2 vector table + BIOS work area + BIOS stack | docs/antforth-banking-redesign.md §5.2`
  - [x] 7.4 — Cite the source-of-truth for each row explicitly. Where the redesign-doc is the citation, use the `§5.1` / `§5.2` form. Where the citation is the MicroBeast hardware schematic or CP/M 2.2 BIOS source, name the document and section. If a row is "assignment inferred from convention", flag it explicitly.
  - [x] 7.5 — If `docs/phase4-memory-map.md` is created: add a cross-reference row in `architecture.md`'s "Additional Requirements From Architecture" section (`:162..184`) so future readers can find it. If the survey is appended to `architecture.md` instead, no cross-reference is needed.

- [x] **Task 8 — Post-edit validation** (AC7, AC8)
  - [x] 8.1 — `wc -c build/antforth.com` post-Task-5 = **24,995 bytes**; **Δ = 0** vs. Task 1.1. ✓
  - [x] 8.2 — `make test-repl` post-edit on iz-cpm = **974 PASS / 0 FAIL / 2 SKIP**. Zero regressions. ✓
  - [x] 8.3 — `bash tools/check-doc-sync/check-doc-sync.sh` post-edit → **TOOL FATAL** (same `[fatal] required input file missing or unreadable: _bmad-output/planning-artifacts/epics.md` as Task 1.4; identical pre- and post-edit). Zero drift introduced by Story 16.1 confirmed by the equality of fatal-exit pre and post. Same orthogonal-pre-existing-defect disposition as Task 1.4; carry-forward to Story 16.2.
  - [x] 8.4 — S9 hardware-smoke exemption documented explicitly per NFR-P4-11 "Zero-binary-delta stories document their S9 exemption explicitly": rationale = "Zero binary delta — the AC1 hardware transcript IS the verification; no separate S9 smoke probe runs needed."

- [x] **Task 9 — Sprint-status update + Change Log + File List**
  - [x] 9.1 — Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey` row transitions `backlog → in-progress → review` (in-progress flip happens alongside the Status header flip during Task 2; review flip at Task 9 close). Verify epic-16 row transitions from `backlog → in-progress` (auto-handled by the create-story workflow but verify post-edit it's correct).
  - [x] 9.2 — File List authored below (Dev Agent Record section).
  - [x] 9.3 — Change Log authored below (Dev Agent Record section).

## Dev Notes

### Why this story matters

Story 16.1 is the load-bearing prework gate for Epic 17 Story 17.1's `kernel_end:` move-up edit. PD-P4-6 (architecture `:271..284`) elected option (c) — evict CCP from `$D400–$DBFF` for +2 KB Page-3 headroom — explicitly conditional on F3 (architecture `:862..868`) verification: *"CP/M 2.2's BIOS warm-boot path may expect CCP to be reloadable from disk on warm-boot. If the BIOS reloads CCP from disk, eviction is safe (the BIOS will restore it on the user's next ^C / system reset). If not, the warm-boot path needs a restore mechanism."*

The +2 KB Page-3 headroom is the buffer that absorbs the projected ~6 KB banking infrastructure growth against the NFR-P4-5 ≤ 8 KB cap. Without it, every Phase-4 binary-delta story is squeezed against the headroom envelope from word one. With it, Stories 17.1–22.x have working room.

The verification is not amenable to iz-cpm: iz-cpm's CCP-substitute does not implement CP/M 2.2's BIOS warm-boot semantics. The load-bearing verdict is hardware-only. This is the same shape as Story 15.5 (B.9 disk-full): the probe runs on hardware because the failure mode is hardware-resource-bounded; the test is meaningful only on real silicon.

### F3 disposition fork

Per architecture `:862..868`:

- **PASS path (expected)** — CP/M 2.2 BIOS reloads CCP from disk on warm-boot (this is the documented behaviour per CP/M 2.2 BIOS source). F3 closes; +2 KB Page-3 headroom is consumable by Story 17.1's `kernel_end:` move-up edit. No follow-up story.
- **FAIL path (mitigation)** — BIOS does not reload CCP; ^C from antforth lands at a corrupted / stranded CCP prompt; the warm-boot path needs a restore mechanism. Story 16.1.1 is spawned per `feedback_verdict_only_audit.md` shape: verdict-only audit (this story stops at the verdict, no source edits), standalone reproducer, fix-story with **+50 B kernel envelope** per architecture `:866`. Story 16.1.1 owns the restore-on-warm-boot code (likely a small handler in `src/system.asm` or `src/antforth.asm`'s exit path that reloads the CCP from disk before warm-booting, mimicking what BIOS would have done).

The FAIL path's +50 B envelope is the same shape as Story 13.5.5's caught-form CATCH retest (small, scoped, single-purpose). Plenty of headroom against NFR-P4-5's 8 KB total banking cap.

### S9 exemption rationale (NFR-P4-11 / NFR-P4-36)

NFR-P4-11 requires every binary-delta Phase-4 story to run its own hardware-smoke probe with a PASS verdict before story close. Zero-binary-delta stories document their S9 exemption explicitly.

**Story 16.1's S9 exemption:** *"Zero binary delta — the AC1 hardware transcript IS the verification. No separate S9 smoke probe runs needed because the entire story's deliverable is a hardware-typed verification artifact."*

This is the canonical "verification spike" exemption shape. The same shape applies to Stories 16.2 (doc-lock, no binary change) and 16.4 (architecture-stage open-questions resolution, doc-only) per the Epic 16 spec — see architecture `:347` *"Zero binary delta (planning + verification only); S9 hardware-smoke is exempted per story with explicit rationale per NFR-P4-11."* Story 16.3 (emulator vendor pick) similarly carries a zero-binary-delta S9 exemption (dev-tooling change, not kernel).

### Pre-known iz-cpm constraint

iz-cpm's CCP-substitute is NOT a real CP/M 2.2 CCP and does NOT implement BIOS warm-boot. The Task 2.3 iz-cpm sanity-run validates that the patched antforth still boots and runs (the zero-fill of $D400-$DBFF does not crash the kernel's own init) — it does NOT validate F3. F3 is hardware-only.

This is similar to Story 15.5's B.9 / B.7 hardware-only verdict shape (transcript = the deliverable; iz-cpm = sanity-runs only) and Story 11.5.1.2's hardware-only firmware-bug reproducer.

### Future-edit reference for Story 17.1 (AC5 deliverable)

**Current state (Phase-3 close-out, v2.0.0):**
- `src/antforth.asm:290` declares `kernel_end:` immediately after `tib_buffer:` (the user-area + BDOS-input + TIB region).
- At 24,995 bytes total `.COM` size, the kernel body runs from `$0100` (TPA_START) to roughly `$6296` (= `$0100 + $6196`).
- This leaves `$6296..$D3FF` (~28 KB) as user RAM / dictionary growth space below the CCP region.
- $D400 through $DBFF is CCP territory (CP/M 2.2 BIOS-loaded).
- $DC00 onward is BDOS / BIOS (must stay; CALL 0005h works from any bank).

**Phase-4 (Story 17.1) edit shape:**
- Move `kernel_end:` declaration / allocation behaviour up by 2 KB, claiming `$D400..$DBFF` for the descriptor-stub allocator + `bank-table[]` shell.
- The exact layout within the reclaimed 2 KB (where `bank-table[]` base lives, how the descriptor-stub allocator carves the rest, per-entry stub size — pinned at 3 / 4 / 5 B per Story 16.4 §9.5) is Story 17.1 / 18.1's decision.
- Story 16.1's responsibility is **safety verification only** — that the region is reclaimable without breaking warm-boot. The layout decision is downstream.

This forward-reference satisfies AC5; Story 17.1's developer can use it as the binding "where to start" pointer without re-deriving the current state from `git log`.

### Page-allocation survey methodology

The AC6 survey is a single-page reference document (or a section in `architecture.md`). It deliberately enumerates per-page assignments so that downstream-story developers (Story 17.1 onward, anyone touching the MMU port writes, anyone authoring the CL parser at Story 17.4) can look up "what's at page 0x2A?" without re-deriving from the schematic.

The survey's source-of-truth columns matter: each row should cite the **canonical** source for that page's assignment, not just the redesign doc. For example:
- Page 0x20-0x23 default slot assignments — MicroBeast hardware schematic (memory-map decoder section).
- CCP / BDOS / BIOS region addresses — CP/M 2.2 BIOS source (the BDOS_ADDR_PTR points to BDOS, which lives at $DC00; CCP is documented at $D400-$DBFF per CP/M 2.2 BIOS conventions).
- Default user banks 0x35-0x3F — `docs/antforth-banking-redesign.md` §5.1 (the design decision).
- Virtual console buffer at 0x24 / RAM disk at 0x25-0x34 — MicroBeast firmware documentation (whatever ships with the MicroBeast bank-list configuration).

Where a row cannot trace to a canonical source, flag the row explicitly: `"assignment inferred from convention; canonical citation TBD"`. Don't fabricate citations.

### Phase-4 envelope check (NFR-P4-5)

NFR-P4-5 caps total banking infrastructure at **≤ 8 KB fixed memory** at the 28-bank cap (~6 KB at default 12 banks). The +2 KB Page-3 headroom from CCP eviction (PD-P4-6) is the buffer that absorbs most projected growth.

**Pre-16.1 cumulative Phase-4 banking infra:** 0 bytes (no Phase-4 binary-delta stories shipped yet).
**Story 16.1 expected delta:** **0** (verification + documentation only; AC7 hard-enforces zero binary delta).
**Post-16.1 cumulative:** **0 / 8 KB** envelope used. Headroom fully intact.

This is the cleanest possible Phase-4 start: F3 closes (or fails into a +50 B follow-up), and the next story (16.2 doc-lock) is also zero-delta. The cumulative budget is not stressed until Story 17.1 ships the kernel-end move + `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` (Epic 17 envelope target ≤ ~400 B per architecture `:609`).

### Standing commitments

S1..S12 (NFR-P4-28..39) all hold for this story:

- **S1 (NFR-P4-28)** — adversarial review fresh-context external; this story's ACs do NOT enumerate "trigger an adversarial review pass" (per `instructions.xml:20..31`). The `CR` command runs separately at story-close.
- **S2 (NFR-P4-29)** — REPL-piped tests are the regression surface. This story adds **zero new REPL probes**; AC8's regression check uses the existing 974/0/2 baseline. The deliverable is a hardware transcript, not a REPL probe.
- **S3 (NFR-P4-30)** — real-byte-count + capstone-aware; Pre-edit Task 1.1 re-`wc -c`s directly per B.3.
- **S4 (NFR-P4-31)** — AC composition; the 8 ACs compose cleanly (AC1 produces the transcript; AC2 forks on verdict; AC3 captures the artifact; AC4 closes F3 in architecture; AC5 captures the future-edit reference; AC6 produces the survey; AC7 hard-enforces zero binary delta; AC8 enforces zero regression).
- **S5 (NFR-P4-32)** — HALT on PARTIAL ship; if the hardware run fails to be scheduled in this dev-pass, the story is `16-1.partial`-not-allowed — close `review` only after the hardware verdict is captured (Task 3).
- **S6 (NFR-P4-33)** — inventory grep covers helpers, not just leaves; N-A for this story (no kernel-word inventory; the touch surface is documentation only).
- **S7 (NFR-P4-34)** — EXX-hygiene per kernel-internal raise site; N-A for this story (no THROW-raising kernel additions).
- **S8 (NFR-P4-35)** — "pre-existing" cannot discharge correctness defects; if AC1 surfaces a stranded warm-boot, AC2's spawn fork fires (Story 16.1.1) — no rationalisation that "the CCP-reload assumption was always shaky".
- **S9 (NFR-P4-36)** — hardware-smoke required; **explicitly exempted** for this story per NFR-P4-11 zero-binary-delta clause (rationale: "the AC1 hardware transcript IS the verification"). Exemption recorded in Task 8.4.
- **S10 (NFR-P4-37)** — workflow > memory > prompt; the F3 closure line in `architecture.md` is the durable record, not a memory note. The transcript artifact at `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` is the durable verdict record.
- **S11 (NFR-P4-38)** — not tag-applicable in this story (Epic 16 close-out per epic spec ships planning artifacts; no antforth 3.x.0 tag until Epic 17 close-out's iron-spike per `epics-phase4-epics-16-22.md:584..609`).
- **S12 (NFR-P4-39)** — hardware-typed probe authoring discipline; the AC1 hardware run is a single human-typed sequence (boot → run antforth → BYE/^C → check CCP prompt); no batch of probes that need word-existence pre-flight or TIB-128 line-length lint. The transcript captures the typing live.

### Project Structure Notes

Touch surface scoped to documentation + uncommitted transient patch + transcript:

- **Modified (architecture document):** `_bmad-output/planning-artifacts/architecture.md` — F3 row closure line (Task 4.4); optionally a new "Phase-4 memory map" section if Task 7.1 elects to land the survey here rather than in a dedicated file.
- **Created (transcript artifact):** `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` — verdict record + transcript-verbatim block + path to the captured binary.
- **Created (transcript binary, outside repo):** `~/Downloads/beastty-<YYYYMMDD>-<HHMMSS>.bin` — terminal-recorder capture of the hardware run (per Story 15.5 / Story 13.1 precedent).
- **Created (survey artifact, if chosen path):** `docs/phase4-memory-map.md` — Page 0–3 page-allocation survey table (Task 7.1's recommended path).
- **Modified (sprint tracking):** `_bmad-output/implementation-artifacts/sprint-status.yaml` — `16-1-...` row status flip from `backlog → in-progress → review` (Task 9.1); epic-16 row flip from `backlog → in-progress` (auto-handled by create-story); conditionally an appended `16-1-1-*: backlog` row if Task 4.3 fires.
- **Conditionally created (only if AC2 FAIL path fires):** `_bmad-output/implementation-artifacts/16-1-1-*.md` — Story 16.1.1 file per `feedback_verdict_only_audit.md` shape (verdict-only audit + reproducer + +50 B fix).
- **Transient (never committed):** the Task 2.1 one-shot CCP-zero-out kernel patch in `src/antforth.asm` (or `src/system.asm`); reverted at Task 5.1 before story close.

**No `src/*.asm` instruction changes** ship in this story (the Task 2.1 patch is transient). **No new EQUs.** **No new dictionary words.** **No new Makefile recipe stanzas.** **No new tests.** The deliverable is a verification transcript + documentation.

### References

- [Source: _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md#Story 16.1] (`:361..380`) — canonical 8-AC spec for this story.
- [Source: _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md#Epic 16] (`:345..359`) — Epic 16 goal + Findings closed (F1 / F3 / F5) + S9-exemption framing.
- [Source: _bmad-output/planning-artifacts/architecture.md#PD-P4-6] (`:271..284`) — CCP eviction decision; option (c) chosen; F3 mitigation flagged.
- [Source: _bmad-output/planning-artifacts/architecture.md#F3] (`:862..868`) — F3 finding body: issue, mitigation, action. Closure target of this story.
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Handoff] (`:1004..1007`) — Epic-16 first stories list (Story 16.1 first).
- [Source: _bmad-output/planning-artifacts/prd.md] — FR-P4-40 / FR-P4-41 / NFR-P4-5 / NFR-P4-10 / NFR-P4-11.
- [Source: docs/antforth-banking-redesign.md] (`:75..95`) — §5.1 page-allocation map; §5.2 CP/M residency layout (CCP at $D400–$DBFF, BDOS at $DC00–$E9FF, BIOS at $EA00+).
- [Source: docs/antforth-banking-redesign.md] (`:163..173`) — §9 open questions list (this story is precursor work to §9 resolution by Story 16.4).
- [Source: src/antforth.asm] (`:290`) — current `kernel_end:` declaration site; future-edit target for Story 17.1.
- [Source: src/antforth.asm] (`:50..51`) — `HERE = kernel_end` init; HERE's current ceiling against the CCP region.
- [Source: _bmad-output/implementation-artifacts/15-5-filesystem-stress-hardware-sprint-disk-full-directory-full-zero-byte-read-file-b-7-b-9.md] (`:5..30`) — prior story (closed 2026-05-09); transcript-naming precedent (`~/Downloads/beastty-<YYYYMMDD>-<HHMMSS>.bin`); hardware-only verdict shape.
- [Source: _bmad-output/implementation-artifacts/15-5-...md] (`:64..65`) — pre-edit baseline binary size 24,995 bytes; baseline test count 973 PASS → 974 PASS post-15.5-close (with test 965; tests 966 / 967 SKIP on iz-cpm).
- [Source: _bmad-output/implementation-artifacts/11-5-1-2-firmware-bdos-register-preservation-reproducer.md] — hardware-only verdict precedent (firmware-side defect; hardware run was the load-bearing verdict).
- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml] (`:297..302`) — Epic 16 row + Story 16.1 row currently at `backlog`.
- [Source: memory `feedback_verdict_only_audit.md`] — verdict-only audit pattern (applied if AC2 FAIL fires).
- [Source: memory `project_hardware_crash_audit.md`] — RESOLVED 2026-04-28; no firmware-side blocker for the AC1 hardware run (BDOS_PRO.COM all-P, antforth runs flawlessly).
- [Source: memory `feedback_no_preexisting_discharge.md`] — S8 standing-commitment; AC2 FAIL spawns a fix-story rather than rationalising.
- [Source: memory `feedback_stabilisation_interlude.md`] — Phase-4 prework framed as the explicit prework gate per epic 16's "Zero binary delta (planning + verification only)" framing.
- [Source: docs/PHASE-3-CARRY-FORWARD.md] — closed; nothing to reference forward into Phase 4 from carry-forward (Epic 15 retro closed all P1 items 2026-05-09).
- [Source: Makefile] — `test-repl` target unchanged; this story adds no new test stanzas.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

- Pre-edit baseline test log: `/tmp/16-1-pre-edit.out` (975 PASS / 0 FAIL / 2 SKIP).
- Patched-binary test log: `/tmp/16-1-patched.out` (975 PASS / 0 FAIL / 2 SKIP — patched build sanity-passes iz-cpm regression suite).
- Post-revert test log: `/tmp/16-1-post-revert.out` (975 PASS / 0 FAIL / 2 SKIP — clean rebuild, Δ=0 vs. baseline).
- Hardware transcript binary: `~/Downloads/beastty-20260513-110640.bin` (1,453 bytes).
- Hardware transcript artifact: `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md`.

### Completion Notes List

**Verdict: PASS.** F3 closes; +2 KB Page-3 headroom ($D400–$DBFF) safe to consume in Epic 17+. No follow-up Story 16.1.1 spawned.

**AC-by-AC closure:**

- **AC1 — one-shot kernel patch + hardware transcript:** PASS. Patch (13 B `LDIR` zero-fill) inserted at `src/antforth.asm` cold_start immediately after FORTH-WORDLIST init and before "; 10. Enter execution"; build = 25,008 B (24,995 + 13). iz-cpm sanity-run clean (banner + `1 2 + .` → `3 ok` + `BYE` exits cleanly). Hardware run executed by project lead 2026-05-13 11:06:40; transcript `~/Downloads/beastty-20260513-110640.bin` captures both `BYE` and `^C` exit paths returning to a healthy `B>` CCP prompt with working `dir`.
- **AC2 — verdict fork:** PASS path taken. AC2 FAIL spawn-Story-16.1.1 fork did NOT fire. Architecture F3 closure line landed (architecture.md `:871` post-edit, immediately after the `:867..:869` Issue/Mitigation/Action block — body preserved for archaeology per AC4).
- **AC3 — transcript artifact:** PASS. `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` authored with date / hardware-rev / transcript-binary path / verbatim excerpts of both runs / PASS verdict.
- **AC4 — F3 closure in architecture:** PASS. F3 row at `_bmad-output/planning-artifacts/architecture.md:870..871` (post-edit) appended with `**Closed by Story 16.1, 2026-05-13, verdict PASS — …**` line. Body text preserved for archaeology.
- **AC5 — future-edit reference in Dev Notes:** PASS. Story Dev Notes section "Future-edit reference for Story 17.1 (AC5 deliverable)" already captures the `src/antforth.asm:290` `kernel_end:` declaration site + Phase-4 kernel-end-moves-up edit shape. Post-revert verified: `kernel_end:` is still at `src/antforth.asm:290`.
- **AC6 — Page 0–3 page-allocation survey:** PASS. `docs/phase4-memory-map.md` created (chose dedicated-file path over architecture-doc-inline per Task 7.1 recommendation, to avoid bloating architecture.md). Survey table covers `0x20..0x3F` (32 pages) with per-row source-of-truth citations; slot-3 residency sub-table covers `$D400–$DBFF` (CCP, DISPOSABLE) + `$DC00–$E9FF` (BDOS) + `$EA00+` (BIOS); pages below `0x20` summarised as out-of-scope-for-Phase-4 with `(inferred from convention)` flag. Cross-reference row added to `architecture.md` "New files created in Phase 4" table (line 654).
- **AC7 — zero binary delta + S9 exempt:** PASS. Pre-edit baseline `wc -c build/antforth.com` = 24,995 B (Task 1.1); post-revert + `make clean && make` = 24,995 B (Task 5.2, Task 8.1). Δ = 0 verified. S9 hardware-smoke EXEMPT per NFR-P4-11 "Zero-binary-delta stories document their S9 exemption explicitly": rationale = *"Zero binary delta — the AC1 hardware transcript IS the verification; no separate S9 smoke probe runs needed because the entire story's deliverable is a hardware-typed verification artifact."*
- **AC8 — regression baseline preserved:** PASS. Pre-edit / patched / post-revert `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** on iz-cpm; ≥ 974 PASS / 0 FAIL / 2 SKIP envelope honoured. Pre-edit baseline was 975 PASS rather than the story-spec-anticipated 974 PASS because direct-commit test 968 ("A.2 caught-form coverage for asm-error THROW -258..-272") was added between Story 15.5 close (974 PASS) and Story 16.1 start, per the Lesson 14-F demotion of 15.2 (caught-form THROW probes) to direct-commit work. Zero regressions across all three measurements (pre / patched / post-revert).

**S9 hardware-smoke exemption (NFR-P4-11):** Story 16.1 is a zero-binary-delta verification spike. AC1's hardware transcript IS the verification — no separate S9 smoke probe is meaningful because there is no binary delta to smoke-test. Exemption recorded here explicitly per NFR-P4-11. (Same shape applies to Story 16.2 doc-lock, Story 16.3 emulator vendor pick, and Story 16.4 open-questions resolution, per the Epic 16 spec.)

**Pre-existing tool defect surfaced (orthogonal):** `tools/check-doc-sync/check-doc-sync.sh` fails fatal pre- and post-edit because it requires `_bmad-output/planning-artifacts/epics.md`, deleted in commit `51bc6d6 update PRD` (2026-05-10) when the canonical epic catalogue was split into phase files (`epics-phase1..4-...md`). Same fatal exit pre- and post-edit = zero drift introduced by this story. Candidate carry-forward for Story 16.2 (doc-lock) which is the natural Phase-4 doc-bookkeeping vehicle. Not in scope for Story 16.1. (Tasks 1.4 and 8.3 wording was updated 2026-05-13 in the code-review pass to reflect the actual outcome honestly, per memory `feedback_no_preexisting_discharge.md`'s "surface, file, fix" convention — the defect is filed in this Completion Notes block and carried forward to Story 16.2, not buried under a [x] mark.)

**Code review (2026-05-13, Opus 4.7 adversarial pass):** 0 HIGH / 4 MEDIUM / 6 LOW findings — all fixed in-document. See Change Log row "2026-05-13 | Adversarial code review …" for the per-finding disposition. Fixes were doc-only (no `src/*.asm` edits, no Makefile edits, no test edits, no architecture.md edits beyond the existing F3 closure + memory-map cross-reference rows); the 24,995-byte binary delta envelope is therefore re-confirmed unchanged by the review pass.

**Hardware transcript verbatim (key excerpts; full version in `16-1-ccp-eviction-hardware-transcript.md`):**

```
B>antforth
AntForth v2.0.0 (C) ant.org 2026
MicroBeast - 30550 bytes free
Type BYE to exit
1 2 + .
3  ok
bye

B>dir
B: SLIDE    COM : RESET    COM : … : ANTFORTH COM : … : VIBE     COM
[CCP healthy after BYE-warm-boot; dir works]

B>antforth
AntForth v2.0.0 (C) ant.org 2026
MicroBeast - 30550 bytes free
Type BYE to exit
1 2 + .
3  ok
^C
B>
B>dir
[CCP healthy after ^C-warm-boot; dir works]
```

### File List

**Created:**
- `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` — hardware-run verdict artifact (Task 4.1).
- `docs/phase4-memory-map.md` — Page 0–3 page-allocation survey (Task 7).

**Modified:**
- `_bmad-output/planning-artifacts/architecture.md` — F3 row appended closure line (line ~870 post-edit); new row added to "New files created in Phase 4" table for `docs/phase4-memory-map.md` (line ~654 post-edit).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `16-1-…` row flipped `ready-for-dev → in-progress → review` (Task 9.1).
- `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey.md` — this file: Status flip + task checkboxes + Dev Agent Record sections.

**Captured outside repo (project-lead's local filesystem):**
- `~/Downloads/beastty-20260513-110640.bin` — terminal-recorder capture of the hardware run (1,453 bytes; CR/LF-terminated console capture; not committed per Story 15.5 / 13.1 precedent for `beastty-*.bin` files).

**Unrelated WIP in working tree at story-close (NOT part of Story 16.1; flagged here to prevent silent inclusion at commit time):**
- `examples/batnball.fth` — Bat'n'Ball Forth game source; untracked in `git status` at 16.1 close; appears in the hardware transcript's B: ramdisk DIR listing (`BATNBALL FTH`) because the project lead's MicroBeast B: drive happened to contain it. **Not authored by Story 16.1; not part of this story's File List**; should be committed (or `.gitignore`d) separately by its own follow-up. The hardware-run zeroing-of-CCP probe did not interact with this file (the file is in B: ramdisk, not memory).

**Transient (authored + reverted within this dev-pass; NOT in final tree):**
- `src/antforth.asm` — 13-byte `LDIR` CCP-zero patch (`LD HL,$D400 / LD DE,$D401 / LD BC,$07FF / LD (HL),0 / LDIR`) inserted at cold_start (Task 2.1); reverted at Task 5.1. Post-revert `git diff src/` = empty.

**Source-tree footprint of this story:** documentation only. No `src/*.asm` instruction changes. No new EQUs. No new dictionary words. No new Makefile recipe stanzas. No new tests. (NFR-P4-11 zero-binary-delta confirmed: `wc -c build/antforth.com` = 24,995 B pre- and post-edit.)

### Change Log

| Date | Change | Reference |
|---|---|---|
| 2026-05-11 | Story created (`ready-for-dev`). | Story-creation workflow; epic `epics-phase4-epics-16-22.md` §"Story 16.1" |
| 2026-05-11 | Dev-pass started; sprint-status flipped to `in-progress`; baseline captured (24,995 B / 975 PASS / 0 FAIL / 2 SKIP); transient CCP-zero patch authored + built + iz-cpm-sanity-tested (975 PASS / 0 FAIL / 2 SKIP on patched binary); `build/antforth.com` (25,008 B patched) staged for hardware transfer; halted for project-lead hardware run. | Task 1, Task 2 |
| 2026-05-13 | Project lead completed hardware run; transcript captured (`~/Downloads/beastty-20260513-110640.bin`, 1,453 B). | Task 3 |
| 2026-05-13 | Verdict: PASS. Transcript artifact authored (`_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md`); F3 closure line appended to `architecture.md` row `:862..868`. | Task 4 |
| 2026-05-13 | Transient patch reverted from `src/antforth.asm`; clean rebuild `wc -c build/antforth.com` = 24,995 B (Δ=0); post-revert `make test-repl` = 975 PASS / 0 FAIL / 2 SKIP. | Task 5 |
| 2026-05-13 | Future-edit reference for Story 17.1 (AC5) confirmed in Dev Notes; `kernel_end:` post-revert verified at `src/antforth.asm:290`. | Task 6 |
| 2026-05-13 | Page 0–3 page-allocation survey authored at `docs/phase4-memory-map.md`; cross-reference row added to `architecture.md` "New files created in Phase 4" table. | Task 7 |
| 2026-05-13 | Post-edit validation: 24,995 B / 975 PASS / 0 FAIL / 2 SKIP; doc-sync same fatal pre- and post-edit (pre-existing tool defect — `epics.md` deleted in `51bc6d6` 2026-05-10; orthogonal to Story 16.1; candidate carry-forward for Story 16.2 doc-lock); S9 exemption documented per NFR-P4-11. | Task 8 |
| 2026-05-13 | Sprint-status row flipped `in-progress → review`; Dev Agent Record sections authored; Status → `review`. | Task 9 |
| 2026-05-13 | Adversarial code review (Opus 4.7) ran; 0 HIGH / 4 MEDIUM / 6 LOW findings. All fixed in-document: (M1) `docs/phase4-memory-map.md` survey expanded from 7 rows to 32 rows in `0x20..0x3F` per strict AC6 reading; (M2) transcript artifact gained explicit "MicroBeast firmware revision" line anchored to the 2026-04-28 firmware-fix from `project_hardware_crash_audit.md`; (M3) `examples/batnball.fth` unrelated-WIP disclaimer added to this story's File List; (M4) Tasks 1.4 and 8.3 task bodies rewritten to honestly state "TOOL FATAL — carry-forward to Story 16.2" rather than the original "record advisory/drift count" wording; LOWs L1..L6 cleared in-line (AC1 patch-size, AC8 test range, Task 1.2 baseline, transcript DIR count, F3 closure line citation, 0x00..0x1F citation phrasing). No source code edits; doc-only fixes. Status → `done`. | Code review |
