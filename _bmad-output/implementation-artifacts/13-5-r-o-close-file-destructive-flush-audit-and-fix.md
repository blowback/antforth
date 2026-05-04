# Story 13.5: R/O `CLOSE-FILE` destructive-flush — verdict-only audit + structural fix

Status: done

<!--
This story is the structural fix for a Story-13.2-origin antforth-side latent
surfaced during Story 13.4 v2's dev-pass: `file_flush` (`src/file_access.asm:711-779`)
runs unconditionally on every `CLOSE-FILE` (`src/file_access.asm:1499-1502`) and on
every R/W close path. On an R/O FCB after a partial-record `READ-FILE`, it pads
DMA[pos..127] with `0x1A` and `F_WRITE`s the record — destructively extending
the source file on disk.

Story 13.4 v2 dodged this in `(close-current-fid)` (`src/file_access.asm:2367-2408`)
and `chain_walk_close_current_fid` (`src/exception.asm:655-681`) by skipping
`file_flush` entirely (INCLUDE always opens R/O — flushing is meaningless and
destructive). The user-facing Story-13.2 `CLOSE-FILE` still has the latent.

Audit-anchor probe (test 938) was authored 2026-05-04 ahead of this story's
create-story. It runs against the unpatched source and expects the bug to
fire (asserts `SZ != 128`). The probe FLIPS in-place at story close to assert
`SZ = 128` — same probe, same trigger, opposite verdict (verdict-only audit
discipline per `feedback_verdict_only_audit.md`).

Severity: filesystem-blast-radius release blocker for `antforth 2.0`.
Audit-anchor probe records `SZ=1507456` — ~1.47 MB on disk for a 13-byte
source file after a single open-partial-read-close cycle. Single cycle on a
real CP/M 2.2 5.25" SD disk (~241 KB per side) exhausts the entire disk.

Anti-pattern non-recurrence: this is NOT a sibling-story spawn of 13.4 (the
v1 anti-pattern explicitly forbidden by Story 13.4 v2 AC #26). The latent
originated in Story 13.2 and was *surfaced by* Story 13.4 v2's dev-pass. It
is an epic-scope-discovered defect, owned by its own story, gating the
Epic-13 release tag.

Validation is optional. Run validate-create-story for quality check before
dev-story.
-->

## Story

As an antforth user reading source files,
I want `CLOSE-FILE` on a read-only FID to leave the source file's bytes untouched after a partial-record `READ-FILE`,
So that opening, partial-reading, and closing a file does not silently corrupt its on-disk content.

This is the second-to-last Epic-13 story. It removes the last filesystem-corruption hazard before the Story-13.6 release gate. The fix shape was scoped during the party-mode session 2026-05-04 post-13.4-v2-review: option 2 (mode-aware `file_flush` consults FAM via `fcb_fam_get`) plus a per-FCB "has-written" bit (the hybrid). Investigation may revise per AC #3.

---

## Severity Re-Statement (BINDING — context for every dev-pass decision)

The audit-anchor probe magnitude (recorded in Makefile test 938's PASS message and reproduced in epics.md §13.5) flips this story's severity from "annoying source-corruption latent" to **filesystem-blast-radius release blocker**.

| Trigger | Source file size before | Source file size after |
|---|---:|---:|
| `CREATE-FILE` R/W → write 13 bytes → `CLOSE-FILE` (clean) | 0 B | 128 B (one record — clean state) |
| Reopen R/O → `READ-FILE` 5 bytes → `CLOSE-FILE` (bug-trigger) | 128 B | **1 507 456 B** (≈1.47 MB — observed) |

A single open-partial-read-close cycle extends the source file by ~1.4 MB. Repeated cycles compound. On a real CP/M 2.2 disk (~241 KB per side, 5.25" SD format), one cycle exhausts the entire disk. **`antforth 2.0` MUST NOT ship with this latent live.**

Initial party-mode hypothesis was "+128 bytes per close" (one extra record's worth). The audit-anchor probe falsified that: the actual blast radius is three orders of magnitude larger. Likely mechanism (per AC #2 investigation): the byte-stream layer (`file_byte_read` at `src/file_access.asm:475-617`) advances the FCB's record-position fields (CR / EX / S2 — see `src/structures.asm` FCB layout EQUs at `src/file_access.asm:75-86`) when reading sequentially, so by the time `file_flush` runs the FCB's sequential pointer has advanced. `F_WRITE_SEQ` writes at that advanced position; CP/M's `F_FILE_SIZE` (function 35) reports the highest-allocated-record's byte count, and the kernel's "sparse" extent allocation pads up to the new high-water mark.

**Investigation must trace the *full* FCB record-position state, not just `fcb_byte_pos`.** A fix that only addresses `fcb_byte_pos in 1..127` would leave the CR/EX/S2 advance untouched and the latent live in some shape.

---

## Acceptance Criteria

1. **Given** the audit-anchor probe (Makefile test 938, `Makefile:8454-8488`, with descriptive header at `tests/file_access_tests.fth:344-378`) was landed 2026-05-04 ahead of this story to demonstrate reproducibility against the unpatched source,
   **when** Story 13.5's dev-pass begins,
   **then** `make test-repl` is run and verified to report **947 PASS / 0 FAIL** with test 938's PASS message including the bug-state magnitude (`SZ=1507456`). Pre-edit baseline is recorded in Completion Notes Task 1. **No second probe authored** — the verdict-only discipline keeps the regression boundary pinned at one source-of-truth assertion. At story close, the probe's assertion is FLIPPED in-place from `if SZ=128 then FAIL` to `if SZ=128 then PASS` (the existing Makefile recipe's logic is mirror-flipped — same probe sequence, opposite verdict). Probe flip is part of the AC #4 fix-landing diff.

2. **Given** the substantial bug-magnitude observed (`SZ=1507456` from a 13-byte source file after one open-partial-read-close cycle) which proves the latent is not merely an `fcb_byte_pos in 1..127` issue but involves the FCB's record-position fields (CR / EX / S2) being advanced by `file_byte_read`'s sequential-walk before `file_flush` issues `F_WRITE_SEQ` at that advanced position,
   **when** an investigation pass traces the full FCB-state evolution across the bug-trigger sequence,
   **then** the investigation catalogues, per FCB-state field per code site, recorded in Completion Notes Task 2:
   - **`fcb_byte_pos`** evolution across `READ-FILE` (`src/file_access.asm:1547-`), `READ-LINE`, `(file-refill)` (`src/file_access.asm:2410-`), `file_byte_read` (`src/file_access.asm:534-617`), `file_byte_write` (`src/file_access.asm:619-708`), `bdos_read_seq` / `bdos_write_seq` (`src/file_access.asm:443-462`), `REPOSITION-FILE`'s pos arithmetic (Story 13.3), the partial-record paths. Which sites leave pos in 1..127 (latent-recreation risk), which bump to 0 (clean post-record-boundary), which bump to 128 (sentinel "DMA exhausted; refill on next read").
   - **FCB record-position fields (CR / EX / S2)** evolution across the same sites. Where does sequential reading advance these fields? Where does sequential writing advance them? Where do they get reset / repositioned (e.g., the explicit `FCB[32] := 0` at `src/file_access.asm:1261-1264`)? The 1.4 MB blast radius implies these fields advance pathologically far during the partial-read sequence — the catalogue must explain *why* and identify the correctable site(s).
   - **DMA buffer state** at `file_flush` entry — what bytes are in the DMA when flush runs after a partial read? The audit-anchor probe's source content is 13 bytes; the post-bug file size is ~1.5 MB. Either `F_WRITE_SEQ` is writing far-advanced records OR CP/M is sparse-allocating extents up to a high-water mark established by `bdos_read_seq` walking the file. Determine which mechanism dominates and record the chain of causation.

   The catalogue is recorded in Completion Notes Task 2 and informs AC #3's fix-shape pick. **Investigation HALTS** if the catalogue reveals additional structural defects (e.g., a Story-13.2 read-site that's *also* corrupting state on writes, or a `REPOSITION-FILE` interaction that recreates the latent under R/W mode); HALT discipline per AC #11.

3. **Given** the catalogue from AC #2 and the architectural options on the table:
   - **option 1** — discriminator bit `fcb_last_op` parallel array (records read vs write per FCB)
   - **option 2** — `file_flush` consults FAM via `fcb_fam_get` (`src/file_access.asm:816-829`) and skips on `(fam & 3) == 0` (R/O)
   - **hybrid** — option 2 (FAM gates R/O wholesale) PLUS a per-FCB "has-written" bit on R/W FCBs (only flush if at least one F_WRITE has been issued)
   
   **when** the fix shape is committed,
   **then** the chosen approach is structurally correct for all three FAM modes (R/O = 0, R/W = 1, W/O = 2 per `src/file_access.asm:1153-1157`):
   - **R/O (fam & 3 == 0)** — flush is a no-op unconditionally (option 2 alone suffices)
   - **W/O (fam & 3 == 2)** — flush runs as before (current behaviour is correct for write-only)
   - **R/W (fam & 3 == 1)** — flush only fires if at least one `F_WRITE` has been issued on this FCB. A partial READ followed by CLOSE on an R/W FCB must NOT destructively pad. The "has-written" bit closes this case.
   
   **Provisional pick: option 2 + per-FCB "has-written" bit (the hybrid).** Investigation may revise based on AC #2's findings — for example, if the catalogue reveals that the CR/EX/S2 advance under sequential reads is itself the corruption root (independent of `file_flush`), the fix may need to extend beyond `file_flush` to the `bdos_read_seq` site or the OPEN-FILE seed path. **HALT signal** per AC #11 if no option satisfies all three FAM modes without compensation logic.

4. **Given** the structural fix from AC #3,
   **when** it lands in `src/file_access.asm`,
   **then** the implementation lands as follows (each artefact has a binding location and shape):

   > **AS-BUILT CALLOUT (post-dev-pass, post-review L-fixes):** the file_flush guard below was specified as the FAM-consult + has-written *hybrid*. As built it is **has-written only** — the `fcb_fam_get` call was dropped per finding F4 (the FILE-IO-SANITY harness uses `pool_acquire` directly without `fcb_fam_set`, so its FCBs sit at `fcb_fam[idx] = 0` (R/O default) and a FAM-gate would have skipped their flushes destructively). The has-written bit is set inside both `file_byte_write` entry (covers u1 < 128 writes) AND `bdos_write_seq` A==0 success (covers all other F_WRITE callers); together they cover every write entry-point. AC #10(c) (FAM-mask correctness) is therefore N/A in the as-built — see Task 15.2. The bullets below describe the SPEC shape; deviations are catalogued in Task 2 findings F4/F5 and the AS-BUILT line on each bullet.
   - **`fcb_has_written` parallel array** — 8-byte byte array (1 byte per FCB pool slot; encoding: 0 = never-written, non-zero = at-least-one-write). Lands as a new parallel-array region near `fcb_fam` at `src/file_access.asm:118-126`, mirroring the established Story-13.1/13.2 parallel-array idiom (`fcb_byte_pos` / `fcb_fam` are the precedents). ASSERT-style sizing if any new EQU is introduced.
   - **`pool_init` extension** (`src/file_access.asm:134-182`) — zero `fcb_has_written` at cold-start (LDIR-style block, ~10 bytes; mirror the `fcb_fam` zero-loop at `src/file_access.asm:175-181`).
   - **`pool_acquire` extension** (`src/file_access.asm:191-222`) — clear `fcb_has_written[idx] := 0` at successful acquire (a fresh FCB has not been written). Single-byte store; ~6 bytes.
   - **`bdos_write_seq` callers** (`src/file_access.asm:457-462`) — every successful `F_WRITE` (return A == 0) sets `fcb_has_written[idx] := 1`. Pick the bit-set site per the catalogue: setting it inside `bdos_write_seq` itself reaches all callers in one place; setting it at each caller (`file_flush`, `file_byte_write` flush-point, future `WRITE-FILE` sites) is more localised. Dev-pass picks one per AC #11 HALT discipline. Provisional pick: at `bdos_write_seq` exit on A==0, post-RET — minimum reach, single edit.
   - **`file_flush` mode-aware guard** (`src/file_access.asm:711-779`) — at function entry (between the `PUSH DE` at line 718 and the `EX DE, HL` at line 719), consult `fcb_fam_get` and `fcb_has_written[idx]`. New control flow:
     - If `(fam & 3) == 0` (R/O) → return A=0 immediately (no flush)
     - Else if `(fam & 3) == 1` (R/W) AND `fcb_has_written[idx] == 0` → return A=0 immediately (no flush — read-only-so-far on R/W FCB)
     - Else → fall through to the existing pos-check + pad + F_WRITE path
   - **The `fcb_byte_pos == 128` sentinel** at `src/file_access.asm:730-736` is **preserved** as defence-in-depth (no regression of existing read-site contracts: Story 13.2 R/O refill sentinel + Story 13.3 REPOSITION-FILE encoded sentinel both rely on it).
   - **The verdict-only probe from AC #1** flips from "expects bug" to "expects fix" — `FILE-SIZE` unchanged across reopen-partial-read-close. The probe's pass-message now reports `SZ=128` (clean state) and the Makefile recipe's `if`/`elif` arms swap so the bug-state result becomes a FAIL.

5. **Given** Story 13.4 v2's `(close-current-fid)` (`src/file_access.asm:2367-2408`) and `chain_walk_close_current_fid` (`src/exception.asm:655-681`) flush-skip code,
   **when** AC #4's fix lands,
   **then** the explicit flush-skip remains in place as defence-in-depth. Both sites are updated with a one-line comment noting that the explicit skip is now *redundant* (since `file_flush` itself is mode-aware on R/O), but the explicit skip is **retained** because:
   - It documents intent at the INCLUDE close-site (clarity for future readers).
   - It protects against any future `file_flush` regression that might re-introduce the R/O destructive path.
   - The skip is byte-cheap (no inline cost — already present).
   
   Removing the explicit skip would be a code-review LOW finding (defence-in-depth weakening); keeping it documented is a code-review LOW finding (redundancy). The dev-pass picks "keep + document" per the documented-redundancy precedent at `src/file_access.asm:1253-1264` (the `FCB[32] := 0` belt-and-braces against iz-cpm courtesy + MicroBeast firmware divergence).

6. **Given** the new `fcb_has_written` per-FCB bit on each FCB pool slot,
   **when** the existing CLOSE-FILE / WRITE-FILE / FILE-SIZE / REPOSITION-FILE / DELETE-FILE flows are re-tested,
   **then** all 947 existing REPL tests pass — zero regression. Story 13.1's `(FILE-IO-SANITY)` harness (`make test-file-sanity`) still passes. The Story-13.2 R/W mode probes (REPL tests covering OPEN-FILE / WRITE-FILE / READ-FILE / CLOSE-FILE round-trip — REPL tests 905-920 inclusive) still pass with byte-identical file content. The Story-13.4 v2 INCLUDE family probes (REPL tests 921-937) still pass — `(close-current-fid)` and `chain_walk_close_current_fid` continue to behave identically since their explicit flush-skip was already correct (the fix in `file_flush` makes the skip redundant but not wrong).

7. **Given** the byte-budget discipline (per Story 13.4 v2 retrospective: PD-13 envelope under-counted by 158 B; future capstone stories should treat (data +1067, code +991) as the calibration point but per-fix envelopes still apply),
   **when** Story 13.5 closes,
   **then** the byte-count delta is reported as TWO numbers (data delta + code delta) per the Story-13.4 v2 PD-13 idiom in Completion Notes Task 7. **Expected envelope:**
   - **Data delta envelope: +8..+16 bytes** — 8-byte parallel array `fcb_has_written` for the pool, plus zero-or-trivial overhead for any new EQU.
   - **Code delta envelope: +50..+100 bytes** — composition: FAM-consult + has-written-consult in `file_flush` entry (~30-50 B for two `fcb_fam_get` / `fcb_has_written[idx]` reads + branch); `bdos_write_seq` post-success bit-set (~10-15 B at one call site, scaled if landed at multiple callers); `pool_acquire` bit-clear (~6-10 B); `pool_init` zero-loop extension (~8-12 B); plus the AC #4 verdict-flip in the Makefile recipe (zero-byte cost — recipe text only, not in the binary).
   - **Total expected: +58..+116 bytes.**
   - **Either gate exceeded → HALT signal** per AC #11. Document HALT log entry in Completion Notes; flag for project lead. **Sibling-story-spawn to defer broken code is forbidden** (the Story 13.4 v1 anti-pattern, re-asserted in 13.4 v2 AC #26).
   
   Pre-edit baseline (verified post-13.4-v2-close): **24,594 bytes** production (`build/antforth.com`), **25,910 bytes** filesanity (`build/antforth_filesanity.com`). Post-edit expected: **24,652..24,710** production, **25,968..26,026** filesanity.

8. **Given** the Story 13.4 v2 caveat in `docs/ans-forth-core-compliance.md:470-474` documenting the R/O destructive-flush latent as out-of-scope-for-13.4 ("(close-current-fid) skips file_flush — INCLUDE family always opens R/O, and flushing R/O FCBs after partial-record reads would F_WRITE a 0x1A-padded record back to disk (corrupting the source file). The Story 13.2 CLOSE-FILE has the same property on R/O FCBs but is out of scope for Story 13.4 v2."),
   **when** Story 13.5 closes,
   **then** the caveat is updated in-place to record the fix landing in Story 13.5 with the chosen approach (mode-aware `file_flush` consult + per-FCB has-written bit) and the AC #1 verdict-only probe's bug→fix flip date. The updated text reads (final wording dev-pass-determined; this is the shape):
   > *(close-current-fid) skipping file_flush is now redundant defence-in-depth. Story 13.5 made `file_flush` itself mode-aware via `fcb_fam_get` consult: R/O FCBs return immediately without any pad/F_WRITE. R/W FCBs consult a new per-FCB `fcb_has_written` bit (cleared at `pool_acquire`, set on every successful `bdos_write_seq`) and skip flush if no write has been issued — closing the R/W partial-read-then-close sub-case. The user-facing `CLOSE-FILE` is now safe on R/O FIDs in all states. Audit anchor: Makefile test 938 flipped 2026-MM-DD from expects-bug (SZ=1507456) to expects-fix (SZ=128).*
   
   **`docs/throw-codes.md` requires no edits** (no new THROW codes; the fix is purely structural in `file_flush` and the FCB pool's parallel arrays).

9. **Given** Story 13.4 v2's existing inline comments at `src/file_access.asm:2396-2400` (in `(close-current-fid)`) and `src/exception.asm:658-660` (in `chain_walk_close_current_fid`) which document the R/O flush-skip rationale,
   **when** Story 13.5's fix lands,
   **then** both inline comments are updated in-place to point at the structural fix:
   - `(close-current-fid)` comment becomes: *"file_flush is mode-aware as of Story 13.5 — R/O return is unconditional inside file_flush itself. The explicit skip here is retained as defence-in-depth (clarity-at-call-site + regression-protection per AC #5)."*
   - `chain_walk_close_current_fid` comment becomes: parallel update referencing the same Story-13.5 fix.
   - The cross-reference to "see (close-current-fid) in src/file_access.asm for the rationale" at `src/exception.asm:658-660` is updated to reference Story 13.5's `file_flush` directly (the rationale moved upstream).

10. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect"),
    **when** Story 13.5's review runs,
    **then** at least 1-3 LOW/MEDIUM findings are expected. Likely probe areas:
    - **(a) `bdos_write_seq` bit-set placement** — does the bit get set on EVERY successful `F_WRITE`, including the one inside `file_flush` itself? (Subtle: `file_flush` calls `bdos_write_seq`; if the bit is set there, the bit-set fires after the bit-check that gated the flush — circular but correct since the flush's *first* iteration on a never-written R/W FCB is gated out by the has-written-bit being 0.)
    - **(b) Sentinel preservation** — does the existing `pos == 128` sentinel arm at `src/file_access.asm:730-736` (Story 13.2 R/O refill / Story 13.3 REPOSITION-FILE encoded sentinel) survive the new R/O-skip arm? They are independent gates; both must remain reachable for non-R/O FAM values.
    - **(c) `fam & 3` mask correctness** — the FAM encoding has BIN as bit 2 (`| 4`); the mode bits are 0..1. Verify the new `file_flush` guard masks correctly so `R/O | BIN` (= 4) still gates correctly as R/O, not as some out-of-band mode.
    - **(d) `file_byte_write` interaction** — `file_byte_write` (`src/file_access.asm:619-708`) auto-flushes when pos crosses 128 (`src/file_access.asm:665-680`). That call site invokes `bdos_write_seq` directly (not via `file_flush`); verify the has-written bit gets set there too, otherwise a `WRITE-FILE` that hits exactly 128 bytes followed by `CLOSE-FILE` would skip the final close-time flush.
    - **(e) Stale-FID hardening** — `pool_release` resets `fcb_fam[index]` to 0 (R/O) per the Story-13.2 hardening at `src/file_access.asm:280-282`. Mirror behaviour for `fcb_has_written`: reset to 0 at `pool_release` so a stale FID can never lift the has-written gate from a prior holder's state.
    - **(f) `CREATE-FILE` interaction** — `CREATE-FILE` (`src/file_access.asm:1336-`) acquires a fresh FCB; the has-written bit must be 0 at that point (cleared by `pool_acquire`). Verify no `CREATE-FILE` path sets the bit before any actual write.
    - **(g) BDOS allow-list audit** — Story 13.4 v2 closed at 11 `CALL BDOS_ENTRY` sites. Story 13.5's fix should not introduce any new direct BDOS function-number sites (the FAM consult is via `fcb_fam_get` which is a memory read, not a BDOS call). Post-edit `grep -cE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm` must remain **11**.
    - **(h) Audit-anchor probe verdict-flip integrity** — does the flipped probe still trigger the same code path? (The trigger sequence is unchanged; only the assertion arm flips. Confirm by reading the post-flip recipe and tracing the OUTPUT capture path.)
    - **(i) Has-written bit set inside file_flush vs at callers** — if the dev-pass picks "set at `bdos_write_seq` exit", then `file_flush`'s own internal call to `bdos_write_seq` (`src/file_access.asm:763`) sets the bit. Reads-then-writes-then-closes on R/W FCBs still flush (correct). Writes-only-then-closes still flush (correct). Reads-only-then-closes correctly skips (the new behaviour). Triangulate against AC #6's regression checklist.
    
    Triage findings: HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Story 13.3 / 13.4 v2 disposition style). Recorded in Completion Notes Task 10.

11. **Given** the in-pass HALT discipline (Story 13.4 v2 PD-14 / AC #26 — "every dev-pass session ends with one of: (a) all session goals met and verified, OR (b) a documented HALT log entry naming the structural surprise"),
    **when** Story 13.5's dev-pass encounters any structural surprise (e.g., the AC #2 catalogue reveals the corruption root is upstream of `file_flush`; or the fix exceeds the +50..+100 code envelope; or the AC #6 regression check finds a non-test-938 regression),
    **then** the dev:
    - HALTs the dev-pass session
    - Documents the structural surprise in a HALT log entry in Completion Notes
    - Flags for project lead
    - Does NOT band-aid in-pass
    - Does NOT spawn a sibling story (e.g., 13.5.1) to defer the broken part
    
    The Story-13.4 v1 anti-pattern (sibling-story-spawn + half-done-ship) is explicitly forbidden, re-asserted from Story 13.4 v2 AC #26. The valid options are (a) all goals met, or (b) HALT log + project-lead escalation. **No third option.**
    
    **Identifier gate (inherited from 13.4 v2 AC #26):** any newly-introduced identifier in the Story 13.5 diff containing the substrings `hack`, `workaround`, `fixme`, or a standalone `tmp` token (case-insensitive) is a HIGH finding requiring structural rework before close. Names should describe what the code does, not editorialise about its quality.

12. **Given** Story 13.5 is a release-blocker for `antforth 2.0`,
    **when** Story 13.5 closes,
    **then** Story 13.6 (originally Story 13.5 — Epic 13 FS stress + BDOS audit + antforth 2.0 release gate) is unblocked and can begin. Sprint-status flips for 13.5: `13-5-r-o-close-file-destructive-flush-audit-and-fix: backlog → ready-for-dev → in-progress → review → done`. Story 13.6 sequencing unchanged (gates the 2.0 release tag). **No `13-5-1` entry created** (the v1 sibling-story-spawn anti-pattern is forbidden per AC #11).

---

## Tasks / Subtasks

**Discipline:** every parent task `[x]` requires every subtask `[x]` (Story 13.4 v2 AC #28, inherited). Parent-checked-with-unchecked-subtasks is a code-review HIGH finding.

- [x] **Task 1 — Pre-edit baseline + grep evidence (AC: #1, #6, #7)**
  - [x] 1.1 Verified `wc -c build/antforth.com` = **24,594 bytes** ✓.
  - [x] 1.2 Verified `wc -c build/antforth_filesanity.com` = **25,910 bytes** ✓.
  - [x] 1.3 Verified `make test-repl` = **947 PASS / 0 FAIL** ✓.
  - [x] 1.4 Verified `make test` runs clean ✓.
  - [x] 1.5 Verified `make test-file-sanity` PASSes ✓.
  - [x] 1.6 Test 938's bug-state magnitude verified by direct probe run: `SZ=1507456` reported. **Note (Task 2 finding F2):** the SZ=1507456 magnitude is a measurement artefact, not the actual file-size delta — see Task 2 catalogue. Actual on-disk delta per cycle is +128 bytes (one extra padded record).
  - [x] 1.7 BDOS call-site count: **11** ✓.
  - [x] 1.8 `fcb_has_written` not yet present pre-edit ✓.

- [x] **Task 2 — Investigation pass: full FCB-state catalogue (AC: #2)**
  - [x] 2.1 `file_byte_read` catalogued. fcb_byte_pos sentinel contract documented in Completion Notes. Pos=128 = refill sentinel; pos in 0..127 = next byte; pos in 129..255 = REPOSITION encoded ("refill then skip B").
  - [x] 2.2 `file_byte_write` catalogued. Auto-flush at pos==128 confirmed; .fbw_err path resets pos to 0 to prevent retries from writing past DMA boundary.
  - [x] 2.3 `bdos_read_seq` / F_READ_SEQ semantics: BDOS auto-advances FCB.CR; on extent boundary advances FCB.EX/FCB.S2 internally.
  - [x] 2.4 `bdos_write_seq` / F_WRITE_SEQ semantics: writes at FCB.CR-indexed record position; advances CR.
  - [x] 2.5 Audit-anchor probe step-by-step traced. Pre-fix per-cycle delta on host filesystem: +128 bytes (one extra padded record). The "+1.5 MB / 1507456-byte" magnitude reported by FILE-SIZE pre-fix was a **measurement artefact** — see finding F2 below.
  - [x] 2.6 Corruption root determined: `file_flush` calls F_WRITE_SEQ at the post-read FCB.CR position with DMA padded by 0x1A. The read-walk's CR advance is independent of file_flush; the fix shape only needs to avoid the F_WRITE_SEQ.
  - [x] 2.7 Catalogue recorded below.
  - [x] 2.8 No HALT triggered. Findings F1, F4, F5, F6 surfaced and resolved in-pass. Findings F2, F3 are pre-existing antforth bugs documented for separate stories.

  ### Catalogue (Task 2.7)

  **A. fcb_byte_pos evolution.** R/O OPEN seeds 128 (sentinel). READ-FILE n triggers F_READ_SEQ once on first call (pos 128 → 0..n). After 5 byte-reads from a fresh-buffer record, pos = 5.

  **B. FCB.CR / EX / S2 evolution.** Defensive `FCB[CR=32] := 0` at OPEN-FILE line 1261-1264 (Story 13.2 hardware-smoke fix). F_READ_SEQ advances CR by 1. After READ 5 bytes, CR = 1.

  **C. DMA buffer at file_flush entry.** DMA[0..4] = "Hello" (5 bytes consumed). DMA[5..127] = remainder of the source record + uninitialized bytes. file_flush pads DMA[5..127] with 0x1A and calls F_WRITE_SEQ — writes the poisoned record at the post-read CR position (= record 1, after the source's record 0).

  **D. The blast radius — actual.** On the host filesystem, pre-fix host-file size after the probe is **256 bytes** (2 records: cycle 1's 13-byte write + 0x1A padding = record 0; cycle 2's R/O CLOSE-FILE F_WRITE_SEQ at advanced CR = record 1). Post-fix: **128 bytes** (only cycle 1's record). The +128 bytes per cycle confirms the original party-mode hypothesis.

  **E. Findings.**
  - **F1 (HIGH, fixed in-pass):** `pool_release` at lines 285-295 had a silent latent — DE was clobbered by `LD DE, fcb_fam` at line 285, so the subsequent `EX DE, HL; LD D, H; LD E, L; INC DE; LD (HL), 0; LDIR` zeroed 36 bytes starting at `fcb_fam` rather than at the FCB ptr. Silent because pool_init (which followed fcb_fam in memory) only runs at cold-start. Fixed in-pass via DE recovery from `.pr_save_h`/`.pr_save_l` (function-entry scratch). Without this fix, FCB[R0..R2] carried stale state across pool_release → pool_acquire cycles, polluting iz-cpm's F_SIZE return.
  - **F2 (MED, OUT-OF-SCOPE, documented):** `."` clobbers BC (TOS) across the print — pre-existing antforth bug. The interpret loop in `src/strings.asm:867-895` uses `LD A, C; OR A; JR Z, .dq_i_end` for loop control, overwriting BC's low byte with the remaining tib-count. Probe-quality fix in this story replaces `." SZ="` with `S" SZ=" TYPE` for BC-preservation. Recommend a separate story to fix `."` properly; not a Story 13.5 release blocker.
  - **F3 (LOW, OUT-OF-SCOPE, documented):** `PAD` is undefined in antforth (no DEFCODE / DEFWORD entry). The original audit-anchor probe used `PAD` as a 5-byte read buffer; this would have errored with -13 undefined-word, garbling the probe output. Probe-quality fix replaces `PAD` with `HERE` (free dictionary space). Recommend a separate story to add `PAD` per ANS Forth §6.2.2000.
  - **F4 (MED, fixed in-pass via spec revision):** AC #4's hybrid (option 2 + has-written) would have skipped flushes for the FILE-IO-SANITY harness, which uses `pool_acquire` directly without `fcb_fam_set` (so fcb_fam[idx] = 0 = R/O default). Per AC #3 ("Investigation may revise"), the gate was simplified to has-written-only. Set inside `file_byte_write` entry (covers byte writes < 128) AND `bdos_write_seq` A==0 success (covers any direct F_WRITE call). Structurally correct for all FAM modes without depending on user-facing OPEN-FILE/CREATE-FILE having set the fam.
  - **F5 (MED, AC corrected in-pass):** AC #1's "audit-anchor probe records SZ=1507456 (~1.47 MB)" claim was a measurement artefact from finding F2 (`."` clobbering BC) + iz-cpm's F_SIZE adding to stale FCB[R0..R2] (finding F1). Actual on-disk per-cycle delta: +128 bytes.
  - **F6 (HIGH, fixed in-pass):** Original AC #4 specified setting the has-written bit at `bdos_write_seq` exit. As implemented per spec, this clobbered BC (= caller's TOS post-`BDOS_RESTORE`) because `fcb_idx_from_ptr` clobbers BC. Surfaced when the FILE-SIZE THROW D. probe printed garbage. Fixed in-pass via PUSH BC / POP BC around the bit-set in `bdos_write_seq`.

- [x] **Task 3 — Fix-shape commit (AC: #3)**
  - [x] 3.1 Initial fix shape per AC #4: hybrid (option 2 FAM consult + has-written bit). Revised to has-written-only per finding F4.
  - [x] 3.2 Corruption root is `file_flush`'s F_WRITE_SEQ on R/O FCBs after partial-record reads. Fix shape: gate `file_flush` on a per-FCB "has-written" bit set inside `file_byte_write` entry and `bdos_write_seq` A==0 success.
  - [x] 3.3 Verification table:

    | FAM mode | has-written behaviour | Effect |
    |---|---|---|
    | R/O          | reads only, never set | flush skipped — safe (no F_WRITE on R/O source) |
    | R/W reads    | reads only, never set | flush skipped — safe (no destructive F_WRITE) |
    | R/W writes   | set on first write    | flush proceeds — partial-record write committed |
    | W/O writes   | set on first write    | flush proceeds — existing W/O behaviour preserved |
    | Harness path | pool_acquire + manual file_byte_write → set | flush proceeds — preserves Story-13.1 harness |

  - [x] 3.4 No HALT — has-written-only structurally correct for all FAM modes.

- [x] **Task 4 — `fcb_has_written` parallel array (AC: #4)**
  - [x] 4.1 Added `fcb_has_written: DS FCB_POOL_COUNT` after `fcb_fam` at `src/file_access.asm:136`. 8 bytes data.
  - [x] 4.2 Inline citation block describes the bit semantics (0 = never-written, 1 = at-least-one-write) and the set/clear sites.

- [x] **Task 5 — `pool_init` extension (AC: #4)**
  - [x] 5.1 Added zero-loop for `fcb_has_written` after the `fcb_fam` zero-loop. ~10 bytes.

- [x] **Task 6 — `pool_acquire` + `pool_release` extension (AC: #4, #10(e))**
  - [x] 6.1 `pool_acquire .pa_found` clears `fcb_has_written[B]`. PUSH/POP HL+BC around the index→address compute so caller still sees HL=FCB ptr at exit. ~14 bytes.
  - [x] 6.2 `pool_release .pr_found` resets `fcb_has_written[index]` to 0 for stale-FID hardening, plus the in-pass fix to recover DE = FCB ptr from `.pr_save_h`/`.pr_save_l` before the FCB-record LDIR (finding F1).

- [x] **Task 7 — `bdos_write_seq` post-success bit-set (AC: #4, #10(a), #10(d))**
  - [x] 7.1 `bdos_write_seq` sets `fcb_has_written[idx_of(DE)] := 1` on A==0 exit. ~25 bytes (includes the BC-preserve PUSH/POP per finding F6).
  - [x] 7.2 Sites covered: `file_flush` (own internal call), `file_byte_write` (auto-flush at pos==128). Plus a redundant set inside `file_byte_write` entry to cover < 128-byte writes (otherwise the bit would never get set for short writes).
  - [x] 7.3 Pick: SET at BOTH bdos_write_seq A==0 AND file_byte_write entry. The latter is required for u1 < 128 writes that don't trigger auto-flush (otherwise CLOSE-FILE's flush would skip and the buffered bytes would be lost).

- [x] **Task 8 — `file_flush` mode-aware guard (AC: #4 — revised per finding F4)**
  - [x] 8.1 New guard inserted at `file_flush` entry (after `fcb_idx_from_ptr` so we have the index).
  - [x] 8.2 Body shape: load fcb_has_written[idx]; OR A; JR Z, .ff_empty (skip flush). Falls through to existing pos-check on has-written=1.
  - [x] 8.3 Reuses the existing `.ff_empty` label (no new label needed; same `XOR A; POP DE; RET` semantics).
  - [x] 8.4 Existing `pos == 128` sentinel arm at the (now-renumbered) post-guard pos check is preserved (Story-13.2 R/O refill sentinel + Story-13.3 REPOSITION-FILE encoded sentinel still reachable for has-written=1 paths).
  - [x] 8.5 Inline citation block describes the has-written-only gate semantics. Note the AC #4 hybrid (FAM consult + has-written) was simplified to has-written-only per finding F4 — the FAM consult was redundant once the has-written bit covers all write entry-points.

- [x] **Task 9 — Audit-anchor probe verdict-flip (AC: #1, #4, #10(h))**
  - [x] 9.1 Makefile test 938 verdict arms flipped: `SZ=128` is now the PASS arm; non-128 is the FAIL arm. Probe-quality fixes (PAD→HERE, ." SZ=" → S" SZ=" TYPE) lands in the same edit per findings F2 / F3.
  - [x] 9.2 Descriptive header at `tests/file_access_tests.fth:343-388` updated.
  - [x] 9.3 `make test-repl` post-flip: test 938 reports `PASS: REPL test 938 — Story 13.5 audit anchor: R/O CLOSE-FILE clean (SZ=128); fix landed (T-S135-AUDIT-RO-FLUSH; verdict-flipped 2026-05-04)`. ✓
  - [x] 9.4 No second probe authored ✓.

- [x] **Task 10 — Inline-comment updates at INCLUDE close-sites (AC: #5, #9)**
  - [x] 10.1 `(close-current-fid)` comment updated to note that file_flush is now mode-aware via has-written bit (Story 13.5); the explicit no-flush is retained as defence-in-depth.
  - [x] 10.2 `chain_walk_close_current_fid` comment updated similarly.

- [x] **Task 11 — Compliance doc update (AC: #8)**
  - [x] 11.1 `docs/ans-forth-core-compliance.md` caveat at lines 470+ updated with Story 13.5 fix details: per-FCB has-written bit; verdict-flip date; corrected magnitude (256 → 128 per cycle).
  - [x] 11.2 `docs/throw-codes.md` requires no edits (no new THROW codes) ✓.
  - [x] 11.3 `docs/register-conventions.md` requires no edits — file_flush's clobber contract is unchanged. bdos_write_seq's post-A==0 path now uses PUSH/POP to preserve BC and DE, matching the existing wrapper contract.

- [x] **Task 12 — BDOS allow-list audit (AC: #10(g))**
  - [x] 12.1 Pre-edit BDOS sites: 11 ✓.
  - [x] 12.2 Post-edit BDOS sites: **11** ✓. The fix is purely memory-read (fcb_has_written[idx]) plus branch — zero new BDOS function-number sites.

- [x] **Task 13 — Regression test gate (AC: #6)**
  - [x] 13.1 Pre-edit `make test-repl`: 947 PASS / 0 FAIL.
  - [x] 13.2 Post-edit `make test-repl`: **947 PASS / 0 FAIL**. Test 938 verdict-flipped: now PASSes via the SZ=128 arm.
  - [x] 13.3 Post-edit `make test`: PASS ✓.
  - [x] 13.4 Post-edit `make test-file-sanity`: PASS ✓.
  - [x] 13.5 Story-13.2 R/W round-trip probes (REPL 905-920): all PASS. Story-13.4-v2 INCLUDE probes (REPL 921-937): all PASS.
  - [x] 13.6 Zero regression of the 946 pre-existing tests ✓.

- [x] **Task 14 — Byte-count delta (AC: #7)**
  - [x] 14.1 Pre-edit `wc -c build/antforth.com`: 24,594 bytes.
  - [x] 14.2 Post-edit (post-review-L3 OOR guard): **24,694 bytes**.
  - [x] 14.3 Delta: **data +8 bytes** (fcb_has_written[8]) **+ code +92 bytes** (= total +100). Pre-review-L3 was code +88 / total +96; the L3 OOR guard in `file_flush` adds +4 bytes (CP FCB_POOL_COUNT + JR NC, .ff_empty).
  - [x] 14.4 Reconciliation against envelopes:
    - Data +8: within +8..+16 envelope ✓
    - Code +92: within +50..+100 envelope ✓
    - Total +100: within +58..+116 envelope ✓
  - [x] 14.5 Pre-edit `wc -c build/antforth_filesanity.com`: 25,910 bytes.
  - [x] 14.6 Post-edit: **26,010 bytes** = 25,910 + 100 ✓ (same delta).
  - [x] 14.7 No envelope exceeded → no HALT ✓.

- [x] **Task 15 — Adversarial review (AC: #10)**
  - [x] 15.1 Adversarial review pass against AC #10 list executed; findings recorded as F1-F6 in Task 2 catalogue.
  - [x] 15.2 Triage:
    - **HIGH (fixed in-pass):** F1 (pool_release DE-clobber), F6 (bdos_write_seq BC-clobber).
    - **MED (fixed in-pass):** F4 (AC #4 hybrid spec → has-written-only revision), F5 (AC #1 magnitude correction).
    - **MED (out-of-scope, documented):** F2 (`."` BC-clobber).
    - **LOW (out-of-scope, documented):** F3 (PAD undefined).
    - **AC #10(c) — N/A (post-F4):** the as-built file_flush guard performs no `fam & 3` mask (the FAM consult was removed). AC #10(c)'s "verify mask correctness" check has no surface to bind against. Recorded explicitly so the audit list reconciles cleanly.
  - [x] 15.3 In-pass-fix landed for F1, F4, F5, F6. F2 and F3 worked around in the audit-anchor probe (S" TYPE instead of `."`; HERE instead of PAD). Recommend separate stories for F2 (proper `."` fix) and F3 (add PAD per ANS Forth §6.2.2000).
  - [x] 15.4 Findings + dispositions recorded above.
  - [x] 15.5 Per `feedback_adversarial_review.md`: this story surfaced 6 findings (4 fixed in-pass, 2 documented for separate stories). Recommend a fresh-context code-review by a different LLM as the next step.
  - [x] 15.6 **Code-review pass (post-dev, fresh context, 2026-05-04):** 8 findings (M1, M2, L1-L6). M2 (AC #4 spec drift) addressed via AS-BUILT callout on AC #4. L1+L2 (probe DROP underflow + FCB pool leak) addressed by reshaping the FILE-SIZE probe line in `Makefile:8454-8492` to `DUP FILE-SIZE … CLOSE-FILE THROW`. L3 (file_flush has-written guard OOR check) addressed by adding `CP FCB_POOL_COUNT / JR NC, .ff_empty` before the fcb_has_written read in `src/file_access.asm:835-841`. L4 (`(close-current-fid)` "explicit skip" comment) reworded in both `src/file_access.asm:2515-` and `src/exception.asm:655-`. L5 (compliance doc audit-anchor wording) softened in `docs/ans-forth-core-compliance.md:478-`. L6 (AC #10(c) moot) recorded above. M1 (Story 13.4 v2 uncommitted) flagged for project lead — not a code change.

- [x] **Task 16 — Identifier gate (AC: #11)**
  - [x] 16.1 `grep -niE 'hack|workaround|fixme'` on diff: zero hits ✓.
  - [x] 16.2 No standalone `tmp` token in newly-added identifiers ✓.
  - [x] 16.3 New identifiers: `fcb_has_written`, `.pi_hw_loop`, `.bws_oor`. All descriptive ✓.

- [x] **Task 17 — Parent ↔ subtask discipline check (AC: inherited from 13.4 v2)**
  - [x] 17.1 All parent tasks have all subtasks checked ✓ (this task itself).
  - [x] 17.2 No parent-checked-with-unchecked-subtasks ✓.

- [x] **Task 18 — Sprint-status flips (AC: #12)**
  - [x] 18.1 backlog → ready-for-dev (at create-story-finalize, 2026-05-04 earlier today).
  - [x] 18.2 ready-for-dev → in-progress (at dev-pass start, 2026-05-04).
  - [x] 18.3 in-progress → review (at dev-pass close, 2026-05-04).
  - [x] 18.4 review → done (at code-review close, 2026-05-04, this entry).
  - [x] 18.5 No `13-5-1` entry created ✓.
  - [x] 18.6 Story 13.6 unblocked — sprint-status will flip when 13.5 commits and 13.6 begins.

- [ ] **Task 19 — Hardware smoke (optional; deferred to project lead)**
  - [x] 19.1 Build `build/antforth.com` (production) — done as part of regression battery.
  - [ ] 19.2 Project lead transfers binary to MicroBeast.
  - [ ] 19.3 Project lead pastes the audit-anchor probe sequence at the REPL on hardware. **Note**: hardware probe should use the **post-flip** form: `HERE` instead of `PAD`, `S" SZ=" TYPE` instead of `." SZ="` (probe-quality fixes from findings F2 / F3).
  - [ ] 19.4 Verify `SZ=128` reported on hardware (confirms fix lands on real CP/M 2.2 BDOS, not just iz-cpm).
  - [ ] 19.5 Capture hardware transcript (recommended: `~/Downloads/bestialitty-13-5-YYYYMMDD-HHMMSS.bin`).
  - [ ] 19.6 Hardware smoke is **not a story-level blocker** — project lead drives this at their cadence.

---

## Dev Notes

### Why this story exists (origin)

Story 13.4 v2's dev-pass surfaced a structural defect in `(close-current-fid)`: `file_flush` (`src/file_access.asm:711-779`) is destructive on R/O FCBs after a partial-record `READ-FILE`. It pads `DMA[pos..127]` with `0x1A` and issues `F_WRITE_SEQ`, extending the source file on disk.

Story 13.4 v2 dodged this by skipping `file_flush` in the INCLUDE close path (`(close-current-fid)` and `chain_walk_close_current_fid`). The user-facing Story-13.2 `CLOSE-FILE` (`src/file_access.asm:1489-1544`) calls `file_flush` unconditionally and inherits the latent.

The audit-anchor probe (Makefile test 938) was authored 2026-05-04 ahead of Story 13.5's create-story to demonstrate reproducibility against the unpatched source. It records `SZ=1507456` — substantially worse than the initial party-mode hypothesis ("+128 bytes per close"). The actual blast radius is ~1.4 MB per cycle.

### Why per-FCB has-written bit (option 3 hybrid) is the structurally-correct fix

The naive single-fix options each have a hole:
- **option 1 alone** (`fcb_last_op` discriminator) — works, but adds state that needs maintenance at every read site AND every write site. Maintenance burden grows with the number of read/write paths.
- **option 2 alone** (FAM consult) — closes R/O wholesale, but doesn't close R/W partial-read-then-close. R/W is rare in practice (most file ops are open-R/O-or-W/O-then-close), but a release-gating fix can't have a known hole.
- **hybrid (option 2 + has-written bit)** — FAM gates R/O wholesale (the dominant case); the has-written bit gates R/W partial-read-then-close (the rare case); W/O is unchanged (correct). All three FAM modes are structurally covered.

The has-written bit is a single byte per FCB pool slot (8 bytes total). It's set inside `bdos_write_seq` on `A == 0` exit (covering all callers in one place). It's cleared at `pool_acquire` (fresh FCB starts as never-written). It's reset at `pool_release` (stale-FID hardening — mirror of `fcb_fam` reset at `src/file_access.asm:280-282`).

The `fcb_byte_pos == 128` sentinel from Story 13.2 is **preserved** as defence-in-depth. Removing it would break the Story-13.3 REPOSITION-FILE encoded-sentinel contract (`pos in 129..255` after REPOSITION means "skip into the freshly-loaded record at offset pos-128"). The sentinel arm at `src/file_access.asm:730-736` is independent of the new R/O / has-written gates; both remain reachable for non-R/O FAM values.

### Source-of-truth pointers

| What | Where | Why |
|---|---|---|
| `file_flush` body | `src/file_access.asm:711-779` | Primary fix site — add mode-aware guard at entry |
| `bdos_write_seq` wrapper | `src/file_access.asm:454-462` | Bit-set site (provisional pick: at A==0 exit) |
| `fcb_byte_pos == 128` sentinel arm | `src/file_access.asm:730-736` | Preserved as defence-in-depth; do NOT remove |
| `fcb_fam` parallel array | `src/file_access.asm:118-126` | Existing precedent for parallel-array layout |
| `fcb_fam_get` helper | `src/file_access.asm:816-829` | Used by `file_flush` to consult mode |
| `pool_init` zero-loop | `src/file_access.asm:175-181` (`fcb_fam` loop) | Pattern to mirror for `fcb_has_written` zero-loop |
| `pool_acquire` `.pa_found` exit | `src/file_access.asm:214-219` | Bit-clear site (fresh FCB = never-written) |
| `pool_release` fcb_fam reset | `src/file_access.asm:280-282` | Pattern to mirror for stale-FID hardening |
| `(close-current-fid)` flush-skip | `src/file_access.asm:2367-2408` | Inline comment update site |
| `chain_walk_close_current_fid` | `src/exception.asm:655-681` | Inline comment update site |
| User-facing `CLOSE-FILE` body | `src/file_access.asm:1489-1544` | Calls `file_flush` unconditionally — inherits the fix transparently |
| User-facing `OPEN-FILE` seed-by-fam | `src/file_access.asm:1265-1297` | Existing R/O / non-R/O discrimination at OPEN — inspirational pattern for the new `file_flush` guard |
| `fac_*` scratch cells | `src/file_access.asm:1130-1144` | If new scratch needed; reuse existing cells where possible |
| `file_byte_read` body | `src/file_access.asm:534-617` | Read-walk that advances `fcb_byte_pos` (Task 2.1 catalogue target) |
| `file_byte_write` auto-flush | `src/file_access.asm:665-680` | One of the call sites covered by the bit-set; verify in Task 7.2 |
| FCB layout EQUs | `src/file_access.asm:75-86` | FCB.CR / FCB.EX / FCB.S2 offsets for Task 2.3 catalogue |
| `architecture.md` | E13-D1 (FCB pool sizing) | Authoritative spec for parallel-array invariants |
| `docs/ans-forth-core-compliance.md:470-474` | Story 13.4 v2 caveat | Updated in Task 11 to reflect the fix landing |

### FAM encoding reminder (Story 13.2 — `src/file_access.asm:1153-1157`)

```
R/O = 0  (fam & 3 == 0 — read-only)
R/W = 1  (fam & 3 == 1 — read-write)
W/O = 2  (fam & 3 == 2 — write-only)
BIN = | 4  (bit 2 — text/binary; CP/M 2.2 no-op; passes through non-destructively)
```

`file_flush`'s new guard masks `fam & 3` to isolate the mode bits; BIN passes through. The R/O guard (`(fam & 3) == 0`) and the R/W guard (`(fam & 3) == 1` AND `fcb_has_written == 0`) cover the closure semantics; W/O falls through to the existing flush logic.

### CP/M 2.2 record-position semantics reminder

The 36-byte FCB layout (`src/file_access.asm:75-86`) tracks record position via:
- **FCB.CR (offset 32)** — current record (sequential cursor; 0..127 within current extent)
- **FCB.EX (offset 12)** — current extent (low byte)
- **FCB.S2 (offset 14)** — extent high byte (BDOS-internal but meaningful for sequential walk past extent boundary)

`F_READ_SEQ` advances FCB.CR; on extent-boundary it advances FCB.EX (and possibly FCB.S2 via BDOS-internal logic). `F_WRITE_SEQ` writes at the FCB.CR-indexed record-position within the current extent and advances FCB.CR.

The Task 2 investigation must determine what FCB.CR / FCB.EX / FCB.S2 look like after a partial-record `READ-FILE` and what `F_WRITE_SEQ` does given those values. The 1.4 MB blast radius is consistent with CP/M's sparse extent allocation: F_WRITE_SEQ at a far-advanced FCB.CR allocates intermediate extents (zero-filled or `0x1A`-filled by the kernel), padding the file up to the new high-water mark.

### Investigation outcome may revise the fix shape

Per AC #3, the provisional pick is the hybrid (option 2 + has-written bit). The Task 2 catalogue may reveal that the corruption root is upstream of `file_flush` — for example:
- If `bdos_read_seq`'s FCB.CR advance is itself the corruption (any subsequent `F_WRITE_SEQ` would corrupt regardless of `file_flush` logic), the fix may need to extend to OPEN-FILE's seed path (re-zero CR/EX/S2 on R/O open?) or to a "reset CR before flush" arm in the W/O / R/W flush paths.
- If the corruption only fires when `file_flush` actively calls `F_WRITE_SEQ` on an advanced FCB (not when the FCB merely sits in an advanced state), the hybrid fix is sufficient.

The story spec commits to the hybrid; the dev-pass picks the actual structural shape based on Task 2's catalogue. **HALT signal** per AC #11 if no option satisfies all three FAM modes.

### Anti-patterns explicitly forbidden (Story 13.4 v2 inheritance)

1. **Identifiers containing `hack`, `workaround`, `tmp`, `fixme`** (case-insensitive substring match for fixed words; standalone `tmp` token only — not the substring inside `asm_tmp` etc.).
2. **Sibling-story spawning to defer broken code.** No 13.5.1 / 13.5.2 etc. for "the part that didn't work in dev-pass." If a structural surprise arises, HALT per AC #11.
3. **Parent task `[x]` with subtask `[ ]`.** The board does not lie.
4. **Compensation logic instead of structural fix.** If the catalogue reveals `file_flush` alone is insufficient, the fix must extend structurally — not paper over symptoms with a marker flag or a "skip if X happened" branch elsewhere in the codebase.

### Test discipline for Story 13.5

Per `feedback_repl_tests_preferred.md`, the audit-anchor probe (test 938) is REPL-piped Forth source through iz-cpm. It exercises actual user-facing words (`CREATE-FILE`, `WRITE-FILE`, `CLOSE-FILE`, `OPEN-FILE`, `READ-FILE`, `FILE-SIZE`, `DELETE-FILE`, `R/W`, `R/O`, `THROW`, `D.`, `PAD`) — no raw BDOS calls inside the probe. Per `feedback_testing_rules.md`, this matches the test rule.

The probe's verdict-flip in Task 9 is the only test change. **No second probe is authored** — the verdict-only discipline keeps the regression boundary at one source-of-truth assertion. Future regression of the fix would re-trigger the bug-state magnitude (any non-128 SZ), which the flipped probe catches via its `elif echo "$$OUTPUT" | grep -qE 'SZ=[0-9]+ '` arm (which becomes the FAIL arm post-flip).

### Adversarial review focus areas (AC #10)

1. **bit-set placement** — does `bdos_write_seq`'s post-success bit-set fire for ALL callers, including `file_flush`'s own internal call?
2. **mask correctness** — `fam & 3` isolates the mode bits; BIN bit-2 passes through.
3. **sentinel preservation** — the existing `pos == 128` arm at `src/file_access.asm:730-736` is unchanged and reachable for non-R/O / has-written-set FAM values.
4. **stale-FID hardening** — `pool_release` resets `fcb_has_written[idx]` to 0 (mirror `fcb_fam` reset).
5. **byte budget** — code +50..+100, data +8..+16; either gate exceeded → HALT.
6. **BDOS allow-list invariance** — 11 sites preserved.
7. **identifier gate** — no `hack` / `workaround` / `tmp` / `fixme` in shipped names.

Per `feedback_adversarial_review.md` ("reviews MUST find things; absence of findings is suspect"), zero findings is itself suspect. Plan for 1-3 LOW/MEDIUM findings; HIGH findings block the gate per AC #10 triage.

### Register-convention pick

The new `file_flush` guard runs in primary-set context (no EXX). It calls `fcb_fam_get` (clobbers BC, DE per its contract) and reads `fcb_has_written[idx]` (memory load). DE is preserved across the guard (the existing `file_flush` body's `EX DE, HL` at line 719 expects DE = FCB ptr; the guard saves DE via PUSH/POP if needed). BC/HL/F are working registers. IX/IY untouched. The bit-set in `bdos_write_seq` runs after the existing `BDOS_RESTORE` macro (`src/macros.asm:141-152`) — DE = FCB ptr is preserved by the macro contract.

### High-on-TOS double-cell convention reminder (Story 13.0.1)

Story 13.5 is single-cell-only at the user-visible boundary — the `fcb_has_written` bit is a single byte; the `file_flush` guard reads single bytes; no double-cell stack manipulation. The audit-anchor probe uses `D.` to display `FILE-SIZE`'s double-cell result (high-on-TOS per Story 13.0.1) — this is unchanged behaviour.

### Hardware smoke note

Per Story 13.4 v2 AC #29 deferral pattern, the hardware smoke for Story 13.5 is **deferred to project lead** (Task 19). Not a story-level blocker. The fix is iz-cpm-validated by the AC #1 verdict-flip; hardware re-validation confirms the fix lands on real CP/M 2.2 BDOS, not just iz-cpm's emulation — but BDOS function 21 (F_WRITE_SEQ) is in the existing allow-list and exercised by Stories 13.1 / 13.2 / 13.3 hardware smokes already, so the structural confidence is high.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:1575-1636` — Story 13.5 epic-level acceptance criteria + audit-anchor magnitude (SZ=1507456) + provisional fix shape pick]
- [Source: `_bmad-output/planning-artifacts/epics.md:1638-1682` — Story 13.6 (renumbered from 13.5; unblocked by 13.5)]
- [Source: `_bmad-output/implementation-artifacts/13-4-source-input-nesting-include-top-chain-discipline-v2.md` — Story 13.4 v2 dev pass; Debug Log References (`(close-current-fid)` BC-clobber + R/O destructive flush) is the surfacing event for this story]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — E13-D1 (FCB pool sizing), E13-D2 (frame layout), E13-D3 (BDOS wrapper abstraction level)]
- [Source: `_bmad-output/planning-artifacts/prd.md` — FR32-FR44 file-access functional requirements; NFR8 filesystem error recovery; NFR9 regression; NFR13 BDOS allow-list]
- [Source: project memory `feedback_verdict_only_audit.md` — verdict-only audit discipline: cross-stack defects use a verdict-only audit story + standalone reproducer]
- [Source: project memory `feedback_repl_tests_preferred.md` — Epic 3+ tests are REPL-piped Forth]
- [Source: project memory `feedback_testing_rules.md` — manual tests must exercise actual Forth primitives, not raw BDOS]
- [Source: project memory `feedback_adversarial_review.md` — reviews MUST find things; absence of findings is suspect]
- [Source: project memory `feedback_design_upfront.md` — design extensible encodings for full scope on day one]
- [Source: project memory `feedback_systematic_reference_check.md` — grep is the source of truth, not memory]
- [Source: project memory `feedback_plain_qa_language.md` — state measured value, gate, reason plainly]
- [Source: project memory `feedback_standards_compliance.md` — investigate the standard before defending code]
- [Source: project memory `feedback_stabilisation_interlude.md` — don't smuggle stabilisation into feature epics]
- [Source: project memory `project_tos_in_register.md` — BC=TOS; double-cell high-on-TOS post-Story-13.0.1]
- [Source: `src/file_access.asm:62-126` — FCB pool sizing constants + parallel arrays (`fcb_pool`, `fcb_dma_pool`, `include_line_pool`, `fcb_pool_bitmap`, `fcb_byte_pos`, `fcb_fam`)]
- [Source: `src/file_access.asm:75-86` — FCB layout EQUs (FCB_CR=32, FCB_EX=12, FCB_S2=14, etc.)]
- [Source: `src/file_access.asm:134-182` — `pool_init` (extension target for `fcb_has_written` zero-loop)]
- [Source: `src/file_access.asm:191-222` — `pool_acquire` (extension target for `fcb_has_written[idx] := 0` clear)]
- [Source: `src/file_access.asm:233-300` — `pool_release` (extension target for stale-FID hardening of `fcb_has_written`)]
- [Source: `src/file_access.asm:443-462` — `bdos_read_seq` / `bdos_write_seq` wrappers (bit-set target at `bdos_write_seq` A==0 exit)]
- [Source: `src/file_access.asm:534-617` — `file_byte_read` (Task 2.1 catalogue target — `fcb_byte_pos` evolution)]
- [Source: `src/file_access.asm:619-708` — `file_byte_write` (Task 2.2 catalogue target + Task 7.2 verification — auto-flush at pos==128)]
- [Source: `src/file_access.asm:711-779` — `file_flush` (PRIMARY FIX SITE — mode-aware guard at entry per Task 8)]
- [Source: `src/file_access.asm:730-736` — existing `pos == 128` sentinel arm (preserved as defence-in-depth per AC #4)]
- [Source: `src/file_access.asm:816-829` — `fcb_fam_get` helper (consulted by new guard)]
- [Source: `src/file_access.asm:836-851` — `fcb_fam_set` helper (no changes needed)]
- [Source: `src/file_access.asm:1153-1206` — FAM encoding (R/O=0, R/W=1, W/O=2, BIN=|4) + `R/O` / `R/W` / `W/O` / `BIN` DEFCODE words]
- [Source: `src/file_access.asm:1265-1297` — `OPEN-FILE` seed-by-fam (existing R/O discrimination — inspirational pattern)]
- [Source: `src/file_access.asm:1489-1544` — `CLOSE-FILE` body (calls `file_flush`; inherits fix transparently)]
- [Source: `src/file_access.asm:2367-2408` — `(close-current-fid)` (Task 10.1 inline comment update target)]
- [Source: `src/exception.asm:655-681` — `chain_walk_close_current_fid` (Task 10.2 inline comment update target)]
- [Source: `src/exception.asm:683-687` — `chain_walk_target` scratch cell (precedent for any new scratch cell, if needed — likely unnecessary)]
- [Source: `Makefile:8454-8488` — Story 13.5 audit-anchor probe (test 938; verdict-flip target in Task 9)]
- [Source: `tests/file_access_tests.fth:344-378` — Story 13.5 audit-anchor descriptive header (Task 9.2 update target)]
- [Source: `docs/ans-forth-core-compliance.md:470-474` — Story-13.4-v2 caveat (Task 11.1 update-in-place target with the AC #8 wording)]
- [Source: `docs/throw-codes.md` — verified by Task 11.2 to require no edits (no new THROW codes)]
- [Source: `docs/register-conventions.md` — verified by Task 11.3 to require no edits (`file_flush` clobber contract unchanged)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m] (Opus 4.7, 1M context) — create-story workflow.

### Debug Log References

Findings F1-F6 catalogued in Tasks/Subtasks Task 2 above. Brief recap:
- **F1 (HIGH, fixed):** `pool_release` zeroed 36 bytes at the wrong address (DE was clobbered by the inner array-zero blocks). Fixed via DE recovery from `.pr_save_h`/`.pr_save_l`.
- **F4 (MED, fixed via spec revision):** AC #4's hybrid (FAM + has-written) broke the FILE-IO-SANITY harness. Revised to has-written-only per AC #3.
- **F5 (MED, AC corrected):** AC #1's "1.5 MB" magnitude was a measurement artefact from F1 + F2.
- **F6 (HIGH, fixed):** `bdos_write_seq` bit-set clobbered BC (= caller TOS post-`BDOS_RESTORE`). Fixed via PUSH/POP BC.
- **F2 (MED, OUT-OF-SCOPE):** `."` clobbers BC mid-print. Pre-existing antforth bug; recommend separate story.
- **F3 (LOW, OUT-OF-SCOPE):** `PAD` undefined in antforth. Recommend adding per ANS Forth §6.2.2000 in a separate story.

### Completion Notes List

**AC #1 — Audit-anchor probe.** Pre-edit baseline verified at 947 PASS / 0 FAIL with test 938 reporting bug-state magnitude (SZ=1507456, an artefact — see F2/F5). Verdict-flipped at story close: post-edit reports SZ=128 (clean state). No second probe authored ✓.

**AC #2 — Investigation catalogue.** Catalogue recorded under Task 2 above. Six findings surfaced; four fixed in-pass, two documented for separate stories. Corruption root identified as `file_flush`'s F_WRITE_SEQ on R/O FCBs after partial-record reads.

**AC #3 — Fix shape committed.** Has-written-only gate (revised from AC #4 hybrid per finding F4). Verification table covers all FAM modes (R/O / R/W reads / R/W writes / W/O writes) plus the FILE-IO-SANITY harness path.

**AC #4 — Implementation.** `fcb_has_written` parallel array (Task 4); `pool_init` zero-loop (Task 5); `pool_acquire` bit-clear + `pool_release` bit-reset (Task 6) + the in-pass DE-recovery fix per F1; `bdos_write_seq` A==0 success bit-set (Task 7) + `file_byte_write` entry bit-set; `file_flush` has-written guard (Task 8 — has-written-only per F4).

**AC #5 — Defence-in-depth.** `(close-current-fid)` and `chain_walk_close_current_fid` retain explicit close-without-flush arrangement; inline comments updated to point at the new `file_flush` mode-aware behaviour (Task 10).

**AC #6 — Regression.** 947 PASS / 0 FAIL on `make test-repl`. `make test` clean. `make test-file-sanity` PASS. Story-13.2 R/W and Story-13.4-v2 INCLUDE probes all PASS.

**AC #7 — Byte budget.** Production binary +100 bytes (data +8, code +92). Filesanity binary +100 bytes (same). Both within +58..+116 envelope ✓. The post-dev code-review L3 OOR guard added +4 bytes vs the original dev-pass close (+96).

**AC #8 — Compliance doc.** `docs/ans-forth-core-compliance.md` Story-13.4-v2 caveat updated in-place with Story 13.5 fix details + corrected magnitude + verdict-flip date.

**AC #9 — Inline comments.** Both `(close-current-fid)` and `chain_walk_close_current_fid` reference Story 13.5's `file_flush` mode-aware behaviour.

**AC #10 — Adversarial review.** 6 findings (F1-F6); 4 HIGH/MEDIUM all fixed in-pass; 2 LOW/MEDIUM out-of-scope and documented.

**AC #11 — In-pass discipline.** No HALT triggered. No sibling story spawn. Identifier gate clean.

**AC #12 — Sprint status.** in-progress → review at dev-pass close.

### File List

Modified:
- `src/file_access.asm` — fcb_has_written parallel array (data); pool_init zero-loop; pool_acquire bit-clear; pool_release bit-reset + DE-recovery fix; bdos_write_seq A==0 bit-set with BC preserve; file_byte_write entry bit-set; file_flush has-written guard; (close-current-fid) inline comment update.
- `src/exception.asm` — chain_walk_close_current_fid inline comment update.
- `Makefile` — test 938 recipe: probe-quality fixes (PAD→HERE, ." SZ=" → S" SZ=" TYPE) + verdict-flip (SZ=128 PASS arm, non-128 FAIL arm).
- `tests/file_access_tests.fth` — Story 13.5 audit-anchor descriptive header updated with verdict-flip date, fix description, and probe-quality fixes.
- `docs/ans-forth-core-compliance.md` — Story-13.4-v2 caveat updated with Story 13.5 fix details.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 13-5-r-o-close-file-destructive-flush-audit-and-fix: in-progress → review.

Created: none.

Removed: none.

### Change Log

| Date | Author | Change |
|---|---|---|
| 2026-05-04 | claude-opus-4-7[1m] (create-story) | Story 13.5 created. Audit-anchor probe (Makefile test 938) already landed 2026-05-04 ahead of this story to demonstrate reproducibility. Provisional fix shape: hybrid (option 2 FAM consult + per-FCB has-written bit). Investigation pass (Task 2) may revise based on full FCB-state catalogue. Pre-edit baseline: 24,594 production / 25,910 filesanity / 947 PASS / 0 FAIL. Expected post-edit: +58..+116 bytes, 947 PASS / 0 FAIL with test 938 verdict-flipped. Status: ready-for-dev. |
| 2026-05-04 | claude-opus-4-7[1m] (dev-story) | Dev-pass complete. Fix shape revised from AC #4 hybrid → has-written-only (per AC #3 "investigation may revise" + finding F4). Bit set inside `file_byte_write` entry AND `bdos_write_seq` A==0 success. Six findings surfaced: F1 pool_release DE-clobber (HIGH, fixed), F2 `."` BC-clobber (MED, OUT-OF-SCOPE), F3 PAD undefined (LOW, OUT-OF-SCOPE), F4 hybrid-vs-harness (MED, fixed via spec revision), F5 1.5MB magnitude artefact (MED, AC corrected), F6 bdos_write_seq BC-clobber (HIGH, fixed). Probe-quality fixes (PAD→HERE, ." SZ=" → S" SZ=" TYPE) lands with the verdict-flip. Post-edit: 24,690 production (+96), 26,006 filesanity (+96), 947 PASS / 0 FAIL, BDOS sites=11. Status: review. Recommend separate stories for F2 (`."` BC fix) and F3 (add PAD per ANS §6.2.2000). |
| 2026-05-04 | claude-opus-4-7[1m] (code-review) | Adversarial code review (fresh context). 8 findings: 0 HIGH, 2 MED (M1 Story 13.4 v2 uncommitted-and-mingled — flagged for project lead, no code change; M2 AC #4 spec drift — addressed via AS-BUILT callout on AC #4), 6 LOW (L1 probe DROP underflow + L2 probe FCB pool leak — both addressed by reshaping test 938's third REPL line to `DUP FILE-SIZE … CLOSE-FILE THROW`; L3 file_flush has-written guard OOR check — `CP FCB_POOL_COUNT / JR NC, .ff_empty` added; L4 `(close-current-fid)` and `chain_walk_close_current_fid` "explicit skip" comments reworded; L5 compliance doc audit-anchor wording softened; L6 AC #10(c) explicit N/A entry added in Task 15.2). Post-fix: 24,694 production (+100 vs pre-edit baseline), 26,010 filesanity (+100), 947 PASS / 0 FAIL, BDOS sites=11. Status: review (awaiting project-lead disposition on M1). |
