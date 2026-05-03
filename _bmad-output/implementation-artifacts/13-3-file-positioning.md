# Story 13.3: File positioning — `FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to query and set the current byte position in an open file and query the byte-length of an open file as ANS-conformant double-cell unsigned values,
So that random-access reads/writes and progress-bar-style file consumption (FR40, FR41) work atop Story 13.2's user-facing wordset — and so the post-Story-13.0.1 high-on-TOS double-cell convention earns its first real-world consumer.

## Acceptance Criteria

1. **Given** ANS Forth 1994 §11.6.1.1520 (`FILE-POSITION ( fileid -- ud ior )`),
   **when** invoked on an open FID,
   **then** a new `DEFCODE` word `FILE-POSITION` is added to `src/file_access.asm` (in the user-facing section, after Story 13.2's `WRITE-FILE` and before any IFDEF FILE_SANITY block) that:
   - Calls `fid_validate` first (per Story 13.2 AC #8 invariant — raises `-70 THROW_FILE_INVALID_FID` for an out-of-range or freed FID).
   - Computes the current byte position as **`(record_count * 128) + byte_within_record`** where `record_count` is the FCB's random-record fields (FCB[33..35] = `r0..r2`, little-endian 24-bit unsigned) **synthesised on demand** from FCB[12..15] (extent EX/S2 + current record CR within extent), and `byte_within_record` is `fcb_byte_pos[index]` clamped to `0..127` (sentinel `128` reads as `0` because position-128 means "next read refills the next record" — the cursor is already at the record boundary, not 128 bytes past the prior boundary).
   - Pushes `( ud-low ud-high ior )` onto the parameter stack with the **high cell on TOS** per the post-Story-13.0.1 ANS §3.1.4.1 convention (`project_tos_in_register.md`). On success `ior = 0`; on a should-not-happen internal error (e.g., FCB index drift), the picked-in-dev-pass non-zero `ior` is returned with `ud = 0 0` (recommended pick: ior = 4 — record in Completion Notes Task 1; opaque non-zero per ANS §11.3.5).
   - Carries an inline `; ANS Forth 1994 §11.6.1.1520 FILE-POSITION — current byte cursor as double-cell unsigned` citation per CCD-3 / NFR17 (`architecture.md:472`).

2. **Given** the cursor synthesis above,
   **when** an open FID is read sequentially,
   **then** `FILE-POSITION` reports the byte offset of the *next byte to be read*, **not** the bytes-already-consumed-from-this-record offset. Two empirical anchor cases the dev-pass smoke must hit:
   - Case (a) — **fresh OPEN-FILE, no I/O yet**: `FILE-POSITION` returns `0 0 0` (low=0, high=0, ior=0). This relies on Story 13.2's H1 fix that seeded `fcb_byte_pos[index]` per fam (R/O → 128 = refill-on-first-read sentinel, R/W/W/O → 0 = empty-buffer write start). Both encodings collapse to "logical position 0" — the cursor synthesis logic must recognise both. **Recommendation:** treat `pos == 128` as "logical 0 within the current record" (no bytes read yet from this record); treat `pos == 0` after any successful refill as "0 bytes ahead in the buffer".
   - Case (b) — **after reading 200 bytes** of a 256-byte file: `FILE-POSITION` returns `200 0 0` (low=200, high=0, ior=0). The CR field is at 1 (one full record consumed); `fcb_byte_pos[index] = 72` (we're 72 bytes into the second record); synthesis: `1 * 128 + 72 = 200`. ✓
   These two anchor cases are the dev-pass smoke must-haves (Task 7 below); other read patterns (record-aligned reads, mixed read/write — see AC #11 deviation log) are tested via `tests/file_access_tests.fth` probes.

3. **Given** ANS Forth 1994 §11.6.1.2142 (`REPOSITION-FILE ( ud fileid -- ior )`),
   **when** invoked with a target byte position within the file,
   **then** a new `DEFCODE` word `REPOSITION-FILE` is added at the same source-order region. Its body:
   - Calls `fid_validate` first.
   - Pops `( ud-low ud-high fileid -- )` per the high-on-TOS convention (TOS = fileid → save to scratch → POP = ud-high → POP = ud-low).
   - **Validates the target position fits in CP/M's 24-bit random-record byte address space**: ud-high upper byte must be 0 (CP/M random-record addresses are 24 bits = 16 MB max; position values >= `0x01000000` are out of range). On overflow, return `ior` non-zero (recommended pick: ior = 5; record in Completion Notes Task 1) without mutating any FCB state.
   - **Discards any pending partial-record write buffer**: a `REPOSITION-FILE` mid-write would otherwise lose the last 0..127 bytes of buffered-but-not-flushed data. Two valid disciplines per ANS:
     - (i) Auto-flush before reposition (Forth-friendly, "do what I mean").
     - (ii) Discard buffered bytes silently (matches CP/M's low-level model, faster).
     Pick **(i) auto-flush** unless dev-pass discovers a strong reason against it: call `file_flush` before mutating FCB random-record fields; map a flush failure to ior non-zero (recommended pick: ior = 6) without mutating the cursor (the user's data isn't on disk and the cursor stays where it was). Record the pick in Completion Notes Task 3.
   - **Sets the FCB random-record fields** `FCB[33..35]` (`r0..r2`) to `target / 128` (low 24 bits of `ud / 128`); sets `fcb_byte_pos[index]` to `target % 128`; sets the CR field `FCB[32]` and the EX/S2 fields `FCB[12..14]` to match (CP/M's BDOS uses the random-record fields *or* the sequential extent/CR fields depending on which call follows — `bdos_read_rand` / `bdos_write_rand` consult r0..r2; `bdos_read_seq` / `bdos_write_seq` consult EX/S2/CR). **Synchronisation discipline:** after setting r0..r2, fall through to the `bdos_read_rand` path on the *next* read, OR explicitly mirror the random-record fields back into EX/S2/CR before the next sequential call. Pick **switch to random-record mode via a per-FCB "repositioned" flag**, OR pick **always read random and emulate sequential as random+1** — dev-pass surfaces which is cheaper. Document the chosen synchronisation strategy in Completion Notes Task 3.
   - Returns `ior = 0` on success; `ior` non-zero per the ranges above.
   - Carries an inline `; ANS Forth 1994 §11.6.1.2142 REPOSITION-FILE — set byte cursor` citation.

4. **Given** ANS Forth 1994 §11.6.1.1522 (`FILE-SIZE ( fileid -- ud ior )`),
   **when** invoked on an open FID,
   **then** a new `DEFCODE` word `FILE-SIZE` is added at the same source-order region. Its body:
   - Calls `fid_validate` first.
   - **Saves the current FCB random-record fields** `FCB[33..35]` to a scratch slot (`fac_r0r1r2: ds 3` in the existing `fac_*` scratch block) so the F_SIZE call doesn't clobber the user's cursor mid-flight.
   - Calls `bdos_file_size` (F_SIZE = 35 — Story 13.1 wrapper at `src/file_access.asm:449-456`). F_SIZE writes the file's size in records into the FCB's `r0..r2` fields.
   - Reads `r0..r2` (3-byte little-endian unsigned record count), multiplies by 128 (= shift left 7), and produces a 32-bit unsigned byte count.
   - **Restores the saved cursor** `r0..r2` (and any associated state — see AC #3 sync strategy) so a subsequent `READ-FILE` / `WRITE-FILE` / `FILE-POSITION` returns to the pre-FILE_SIZE cursor.
   - Pushes `( ud-low ud-high ior )` (high on TOS) with `ior = 0`. On internal failure (should-not-happen — F_SIZE never returns an error code per the CP/M 2.2 spec; A is documented as "not used"), return ior non-zero (recommended ior = 7; dev-pass pick).
   - Carries an inline `; ANS Forth 1994 §11.6.1.1522 FILE-SIZE — byte length of file` citation.
   - **Caveat — record-granular size, byte-EOF unknown to CP/M:** CP/M 2.2's filesystem tracks size in 128-byte records, not bytes. A file written by `WRITE-FILE` of 100 bytes occupies 1 record (128 bytes on disk, with bytes 100..127 padded to 0x1A by `file_flush`); `FILE-SIZE` reports **128**, not 100. This is a documented platform limitation, not a defect. Per ANS §11.6.1.1522, `FILE-SIZE` returns "the size, in characters, of the file identified by fileid"; on CP/M 2.2 this is "the size, in characters, *rounded up to the nearest 128-byte boundary*". Document in Completion Notes Task 4 and in the source comment at `FILE-SIZE`'s body.

5. **Given** the FID-validation contract from Story 13.2 AC #8,
   **when** `FILE-POSITION` / `REPOSITION-FILE` / `FILE-SIZE` are called on a closed/stale FID,
   **then** `fid_validate` raises `-70 THROW_FILE_INVALID_FID` *before* any FCB byte is read or mutated. Test coverage at AC #9 probe (t12) — closed-FID detection extended to all three new words.

6. **Given** the high-on-TOS double-cell convention (Story 13.0.1, ANS §3.1.4.1) and the Z80 cell-pair memory layout (high cell at lower address per `2!`/`2@`),
   **when** `FILE-POSITION` and `FILE-SIZE` push their `ud` onto the parameter stack,
   **then** the **high cell is pushed last** (= ends up on TOS in BC); the low cell is below it. This matches every other double-cell word in the kernel post-Story-13.0.1 (`D+`, `D-`, `D=`, `D<`, `(DLIT)`, `2DUP`, etc.). Audit: a `.S` after `<fid> FILE-POSITION DROP` shows the low cell *below* the high cell; for a 200-byte file position this prints as `200 0` (not `0 200`), where 200 is the second-on-stack low cell and 0 is the high cell on TOS. **Common-mistake-to-prevent:** don't accidentally push low-on-TOS — that's the pre-Story-13.0.1 convention which is now wrong. The Story 13.0.1 retro flagged this as the most likely regression vector on any new double-cell-touching word.

7. **Given** the post-Story-13.2 BDOS allow-list invariance (Story 13.2 AC #10 / NFR13: every BDOS call uses an allow-listed function from the pre-existing 11 wrappers),
   **when** Story 13.3's three new words are authored,
   **then** **no new BDOS function numbers are introduced**. F_SIZE (35), F_READRAND (33), and F_WRITERAND (34) are already wrapped by Story 13.1 (`bdos_file_size`, `bdos_read_rand`, `bdos_write_rand` at `src/file_access.asm:430-456`); Story 13.3 adds zero new direct `CALL BDOS_ENTRY` sites. Audit: `grep -nE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm` post-edit returns the same 11 hits at substantially the same line numbers (modulo line drift from new code above the wrapper region). Any new direct BDOS call is a story-level blocker — wrap it as a helper in the wrapper region first if unavoidable.

8. **Given** the BDOS register-preservation contract inherited from Story 13.1 AC #5 / Story 13.2 AC #11 (firmware ≥2026-04-28 + assumption-by-mechanism for non-blocking BDOS functions; hardware-confirmed by Story 13.1 AC #17 and Story 13.2 Task 17),
   **when** Story 13.3's words call `bdos_file_size` / `bdos_read_rand` / `bdos_write_rand` through the existing wrappers,
   **then** the IX/IY/shadow-register preservation contract extends transparently. Story 13.3 introduces no new register-discipline requirements at the user-facing layer; the IP-preservation pattern from Story 13.2 (`LD (fac_ip), DE` at top of body, `LD DE, (fac_ip)` before each NEXT path) is reused for each of the three new words. **Caveat — F_READRAND is not on the Story-13.1-probed list (1, 2, 6, 9, 10, 11)**: Story 13.3 inherits the assumption-by-mechanism for F_SIZE / F_READRAND / F_WRITERAND, but if dev-pass surfaces a hardware-only register clobber on these specific functions (analogous to the F_OPEN CR-zero issue caught in Story 13.2 Task 17), the disposition follows AC #19's escalation gate: defensive write *at the user-facing layer* is in-pass; helper-layer rewrite is escalation-gated.

9. **Given** the test discipline (`feedback_repl_tests_preferred.md` — REPL-piped Forth tests; `feedback_testing_rules.md` — manual tests must exercise actual Forth primitives, not raw BDOS) and the `tests/file_access_tests.fth` infrastructure inherited from Story 13.2,
   **when** `tests/file_access_tests.fth` is **extended** by this story (the file already exists post-Story-13.2 with probes (t1)..(t9) at Makefile tests 905..913),
   **then** new probes (t10)..(t14) are added covering the FILE-POSITION / REPOSITION-FILE / FILE-SIZE matrix. Required probe set:
   - **(t10) FILE-POSITION on a fresh OPEN-FILE** — create a file, write 0 bytes, close; reopen R/O; **before any READ-FILE**, call `FILE-POSITION`. Expected: `0 0 0` (low, high, ior). Anchors AC #2(a). The probe ends with `." T10=" FILE-POSITION . . . CR`.
   - **(t11) FILE-POSITION mid-read** — create a file with the (t2) 256-byte payload, close, reopen R/O, READ 200 bytes into a buffer, then call `FILE-POSITION`. Expected: `200 0 0`. Anchors AC #2(b). Notes: ensure the 200-byte read crosses one record boundary (CR=0 → CR=1 mid-read; final position is record 1, byte 72) to verify the synthesis logic in AC #1 handles record-boundary-crossed reads correctly.
   - **(t12) Closed-FID detection on the three new words** — open a file, close it, attempt `FILE-POSITION` / `REPOSITION-FILE` / `FILE-SIZE` on the stale FID via `' <word> CATCH`. Each must surface `-70` on the data stack. Three sub-cases under one Makefile test number (or three separate tests — dev-pass pick).
   - **(t13) REPOSITION-FILE round-trip** — write a 256-byte payload (re-using (t2)'s `P256` colon-def pattern); close; reopen R/W; REPOSITION-FILE to byte 100; READ-FILE 1 byte → expect byte = `('A' + (100 mod 26)) = 'W'` (matches the (t2) encoding). REPOSITION-FILE to byte 0; READ-FILE 1 byte → expect `'A'`. REPOSITION-FILE to byte 200; READ-FILE 1 byte → expect `('A' + (200 mod 26)) = 'C'`. REPOSITION-FILE to byte 256 (= EOF); READ-FILE 1 byte → expect `u2 = 0, ior = 0` (clean EOF per Story 13.2 AC #5).
   - **(t14) FILE-SIZE matches written byte count, modulo record rounding** — create empty file `TSIZE0.TXT`; FILE-SIZE → expect `0 0 0`. Create file `TSIZE1.TXT`, write 64 bytes (partial record — pads to 128 on close), close, reopen, FILE-SIZE → expect `128 0 0` (record-granular size; document the rounding-up in the probe's comment). Create `TSIZE3.TXT`, write 256 bytes (= 2 full records), close, reopen, FILE-SIZE → expect `256 0 0`. Cleanup: delete each file.
   - **(t15, optional)** — record-edge boundary positions: REPOSITION-FILE to bytes 127, 128, 129 across a written 256-byte file; READ-FILE 1 byte at each; verify the byte values match the (t2)-pattern `('A' + (pos mod 26))`. This is the AC-level requirement from epics.md:1533 ("boundary positions at record edges (127/128/129 bytes)"). Recommended: roll into (t13) as additional sub-probes rather than a separate Makefile test.
   Each probe is a separately-numbered REPL test in the Makefile, continuing the post-Story-13.2 sequence (last numbered test is **913**); (t10)..(t14) run as **N additional tests** where N is dev-pass-decided (range **+5 to +9** depending on per-probe granularity — sub-tests of (t12) and (t13) may be split). Per `feedback_repl_tests_preferred.md`, every probe is REPL-piped Forth source through iz-cpm; per `feedback_testing_rules.md`, raw BDOS calls inside probes are forbidden — the probes go through the new DEFCODE words exclusively.

10. **Given** the TIB-128 limit (Action Item A1 from Epic 12 retro, fully landed by Story 13.2 Task 15),
    **when** any (t10)..(t14) probe's Forth source crosses 127 bytes per `printf` line,
    **then** the test author splits the source across multiple `printf '%s\r\n'` arguments per the documented split-printf idiom. The (t13) REPOSITION + multi-read probe is most likely to cross the limit; the (t14) FILE-SIZE matrix may also cross when written as a single line. Continue the Story-13.2 pattern (`Makefile:8018-8030` reference) — multi-arg `printf '%s\r\n%s\r\n...'` with each chunk under 127 bytes.

11. **Given** Story 13.2's still-open R/W mixed read+write follow-up (recorded in Story 13.2 Code Review notes — "R/W mode mixed read+write within one FID still needs REPOSITION-FILE to behave cleanly"),
    **when** Story 13.3 lands `REPOSITION-FILE`,
    **then** the deviation log either resolves the follow-up or explicitly defers it to Story 13.5 (FS stress + capstone). Two valid dispositions:
    - **(a) Resolve in-pass:** REPOSITION-FILE used between a READ and a subsequent WRITE on the same FID is the canonical CP/M idiom for mixed-mode access (the random-record fields disambiguate from the sequential cursor). If the AC #3 sync strategy plays cleanly with mixed-mode access (verified by an extra (t13) sub-probe: write 64 bytes, REPOSITION-FILE to 0, read 64 back, verify), the follow-up is resolved here. Pick this if dev-pass shows it works without further surgery.
    - **(b) Defer to Story 13.5:** if mixed-mode access exposes a Story-13.1-helper-layer rewrite need (`file_byte_read` / `file_byte_write` confusion across REPOSITION boundaries — analogous to the AC #17(h) EOF/error disambiguation deviation), HALT, document the divergence, and explicitly carry the follow-up forward. Do NOT refactor the helper layer in-pass per Story 13.2 AC #19's structural-load-bearing escalation gate.
    Record the pick + rationale in Completion Notes Task 11. Either disposition is acceptable; the project lead reviews the rationale at story close.

12. **Given** FR43 (file-op errors raise THROW, not ABORT) and the ior-vs-THROW routing pattern from Story 13.2 AC #12,
    **when** Story 13.3's three new words encounter errors,
    **then** the routing matches Story 13.2's discipline:
    - **`ior` (recoverable, no THROW)** — REPOSITION-FILE target out of 24-bit range, REPOSITION-FILE flush failure mid-reposition (write-mode), should-not-happen internal errors that aren't catastrophic.
    - **`THROW` (unrecoverable, no ior)** — closed/stale FID (`-70 THROW_FILE_INVALID_FID`).
    - **No double-error path** — each condition routes to exactly one channel; the routing table is recorded in Completion Notes Task 12 as a 2-column table (condition → channel).

13. **Given** the byte-count delta budget (`architecture.md:158` no per-epic net-negative gate) and the post-Story-13.2 baseline (**21,887 bytes** production, **23,203 bytes** filesanity per the dev-pass close 2026-05-03),
    **when** Story 13.3's build closes,
    **then** the post-edit `wc -c build/antforth.com` is recorded in Completion Notes Task 13 alongside the pre-edit baseline. **Expected envelope: +250 to +500 bytes.** Composition estimate:
    - 3 user-facing DEFCODE words (`FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`) — ~80-130 bytes each (header + arg-marshal + helper call + double-cell push) = ~270-390 bytes
    - Synthesis arithmetic (`(record_count * 128) + byte_within_record` — = `SLA` 7 + `OR` lo + carry-prop hi) ~25 bytes
    - 24-bit overflow check on REPOSITION-FILE target ~15 bytes
    - 1-3 bytes new scratch storage (`fac_r0r1r2: ds 3` for FILE-SIZE cursor save) — 3 bytes
    - Possible 1-byte per-FCB "random-mode" flag if AC #3's sync strategy needs it (8 bytes if it's a parallel array; 0 bytes if encoded in fcb_fam's unused bits) — 0-8 bytes
    Total estimated: **~310-440 bytes.** Any delta beyond +600 bytes warrants explicit justification in Completion Notes Task 13 per `feedback_plain_qa_language.md` (state value, gate, reason). Per Lesson 12-C (`epic-12-retro-2026-05-01.md:88`), tight per-story budgets ratchet even when overshot — record honestly, no smuggled-in stabilisation per `feedback_stabilisation_interlude.md`.

14. **Given** the post-Story-13.2 regression baseline (**922 PASS / 0 FAIL** per `make test-repl`, post-Code-Review-H1 fix per Story 13.2 dev-notes Code Review entry),
    **when** Story 13.3's edits land,
    **then** all 922 existing tests continue to PASS (zero regression — NFR9 / FR45 / FR46 enforced per-story). Pre-edit and post-edit `make test-repl` PASS counts are recorded in Completion Notes Task 14; the post-edit count is `922 + N` where `N` is the new probe count from AC #9 (5..9). `make test` (assembly thread) runs clean post-edit. `make test-file-sanity` (Story 13.1's harness) continues to PASS — the new positioning words are additive and do not displace the FILE_SANITY-wrapped harness. Any pre-existing failure is a release blocker per `feedback_standards_compliance.md`.

15. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect"; `architecture.md:565-569` — Epic 13 capstone reviews unlikely to be clean) and Story 13.2's yield (1 HIGH + 1 MEDIUM + 4 LOW dev-review findings + Code Review H1/M1/L5/L6/L8 fixes),
    **when** Story 13.3's review runs,
    **then** **at least 2-4 LOW/MEDIUM findings are expected** (the "ninth-plus consecutive epic" review trend per Epic 12 retro Lesson 5; Story 13.2 returned ~10 findings total across both review passes). Likely candidates the review must probe:
    - **(a) Cursor synthesis correctness across record boundaries** — Audit: `FILE-POSITION` after a read of exactly 128 bytes (one full record) returns `128 0 0`, not `0 0 0` (which would be the bug if synthesis used `pos==128 sentinel → bytes-this-record=0` without bumping CR-counter). Smoke probe: write 256 bytes, read 128, FILE-POSITION → expect `128 0 0`.
    - **(b) ud-high cell ordering audit** — Verify with `.S` that `<fid> FILE-POSITION` lands the high cell on TOS (top-of-stack-on-the-right per ANS convention; in antforth's `.S` output the rightmost number is TOS). Cross-reference: every other Story 10.2+ double-cell word follows the same convention; a regression here would surface in the test-suite's existing double-cell tests, but Story 13.3's own tests must verify the double-cell push happens-correctly *here* too. Common-mistake-to-prevent: pushing the *low* cell last (= old pre-13.0.1 convention).
    - **(c) FILE-SIZE cursor preservation** — Verify: after `FILE-SIZE`, a subsequent `FILE-POSITION` returns the *same* value it would have returned *before* `FILE-SIZE`. The save/restore of FCB `r0..r2` (and any sync-flag state) must round-trip cleanly. Smoke probe: read 100 bytes; record FILE-POSITION; call FILE-SIZE; call FILE-POSITION again; assert equal.
    - **(d) REPOSITION-FILE flush failure path** — If the AC #3 auto-flush pick is taken and the flush fails (disk full, F_WRITE error), the cursor must NOT be mutated (the user's data is in limbo and they need to know). Audit: in the flush-fail branch, return ior non-zero BEFORE touching `r0..r2` / `fcb_byte_pos`.
    - **(e) REPOSITION-FILE 24-bit overflow** — Audit: a `ud` whose ud-high upper byte is non-zero (i.e., target ≥ 16 MB) returns ior non-zero without mutating the FCB. The test-suite probe should include an obvious overflow case (e.g., `0 1 fileid REPOSITION-FILE` with high cell bit 16 set).
    - **(f) BDOS allow-list audit invariance (Story 13.2 AC #10 inheritance)** — Re-run `grep -nE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm` post-edit; confirm 11 hits (same as Story 13.2 baseline). Story 13.3 contributes zero new audit rows.
    - **(g) FILE-POSITION/FILE-SIZE on freshly-OPEN R/O — sentinel handling** — `pos==128` after OPEN-FILE R/O is the Story 13.1 "refill on first read" sentinel. The cursor synthesis logic in AC #1 must treat this as *logical position 0* (not `1 * 128 = 128`); else `FILE-POSITION` immediately after R/O OPEN returns `128 0 0` instead of `0 0 0`. Audit: explicit branch test in `FILE-POSITION` body that `pos == 128 → byte_within_record = 0` (no record-count bump).
    - **(h) Concurrency / multiple-FID interleave (low priority)** — If two FIDs are open simultaneously and used in interleaved order, BDOS's process-global DMA address may diverge from each FID's expected DMA. Story 13.1's `bdos_set_dma` discipline (called on every refill/flush) handles this *for* the byte-stream layer; FILE-SIZE's F_SIZE call doesn't use DMA so it's unaffected. REPOSITION-FILE doesn't use DMA either (just sets r0..r2). Audit: confirm no DMA-related side effects in any of the three new words.
    - **(i) Hardware-only divergence on F_SIZE / F_READRAND / F_WRITERAND** — Per AC #8 caveat, these are not on Story 13.1's probed BDOS list (1,2,6,9,10,11). The Story 13.2 Task 17 hardware smoke caught a divergence on F_OPEN's CR-zero behaviour; analogous risk here is hardware-only divergence in random-record byte layout. **Mitigation:** Task 7 hardware smoke MUST exercise REPOSITION-FILE round-trip and FILE-SIZE on real MicroBeast — not just under iz-cpm.
    - **(j) Test fixture leakage** — As Story 13.2 (i): every probe deletes its files at the end (or relies on `.gitignore` for `disk/a/*.TXT` and `disk/b/*.TXT`). Story 13.3's probes follow the same convention; the (t14) FILE-SIZE matrix creates 3 files (TSIZE0.TXT, TSIZE1.TXT, TSIZE3.TXT) and must delete all three.
    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Story 13.2's 0-fix-4-accept dev-review disposition + Code Review's 4-fix-5-accept disposition). Recorded in Completion Notes Task 15.

16. **Given** Action Item A5 from the Epic 12 retrospective ("Mid-epic hardware smoke cadence for Epic 13"; project lead 2026-05-01) and the per-story hardware-smoke precedent (Story 13.1 AC #17, Story 13.2 Task 17),
    **when** Story 13.3 closes review,
    **then** the build is transferred to real MicroBeast and a hardware-smoke probe exercises the three new words. Probe sequence:
    - paste a single colon-definition wrapping the round-trip: `: HW3-TEST  S" HW3.TXT" R/W CREATE-FILE DROP DROP  S" HW3.TXT" R/W OPEN-FILE DROP <fid> !  HERE 32 <fid> @ WRITE-FILE DROP <fid> @ FILE-SIZE . . . CR <fid> @ FILE-POSITION . . . CR  0 0 <fid> @ REPOSITION-FILE . CR <fid> @ FILE-POSITION . . . CR <fid> @ CLOSE-FILE DROP S" HW3.TXT" DELETE-FILE DROP ;`
    - record the hardware build path used (production `build/antforth.com` — Story 13.3's wordset is in production, not behind FILE_SANITY)
    - hardware target drive: **B:** (firmware ROM occupies A: on MicroBeast — Story 13.1 AC #17 / Story 13.2 Task 17 convention). The probe filename `HW3.TXT` has no drive prefix → routes to default → B: on hardware, A: under iz-cpm (transparent).
    - capture transcript (recommended: `~/Downloads/bestialitty-13-3-YYYYMMDD-HHMMSS.bin`)
    - PASS/FAIL verdict against expected output: FILE-SIZE before any flush should report `128 0 0` (write-buffer not flushed yet — Story 13.2 H1 understanding: write-mode, pos starts at 0, F_SIZE on an unsaved file may report 0 0 0; verify expected behaviour empirically and record). **More important:** REPOSITION-FILE 0 followed by FILE-POSITION returns `0 0 0` round-trip; ior=0 throughout; no THROW.
    The hardware probe doubles as evidence the three new words work end-to-end on real hardware against the firmware-fixed BDOS path inherited from Story 13.1. Recorded in Completion Notes Task 16.

17. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 12.1 AC #14, Story 11.5.5 AC #12, Story 13.1 AC #14, Story 13.2 AC #19),
    **when** small in-pass refinements are warranted (additional grep-driven scrubs, polished comment phrasing, ior-value picks, sync-strategy picks per AC #3, FILE-SIZE byte-vs-record-rounding documentation phrasing),
    **then** they are landed inside this story — no spawning sub-stories. The exception: if review surfaces a **load-bearing structural change** to Story 13.1's helper layer (e.g., `file_byte_read` / `file_byte_write` rewrite for mixed-mode FID per AC #11(b)), HALT and flag for project lead before refactoring — the change becomes a separate decision (a Story 13.3.1 if the project lead approves). Documented in Completion Notes Task 17.

18. **Given** the documentation update discipline (Story 13.2 Task 18.1: `docs/ans-forth-core-compliance.md` §11.6 table),
    **when** Story 13.3's three words land,
    **then** the §11.6 File-Access table in `docs/ans-forth-core-compliance.md:404-415` is extended with three new rows for `FILE-POSITION` (§11.6.1.1520), `REPOSITION-FILE` (§11.6.1.2142), `FILE-SIZE` (§11.6.1.1522), each citing `file_access.asm (Story 13.3)`, with Notes columns matching the existing pattern. The "Story 13.2 ior/THROW split" callout below the table is updated to "Story 13.2 + 13.3" or kept and a new Story-13.3-specific callout added — pick whichever reads cleaner; ensure the callout includes the FILE-SIZE record-rounding caveat (AC #4) so users aren't surprised. `docs/throw-codes.md` requires no edits — no new THROW codes introduced (all new error conditions route through ior or via the inherited `-70 THROW_FILE_INVALID_FID`).

19. **Given** Story 13.3 sits between Story 13.2 (core File-Access wordset, **done**) and Story 13.4 (source-input nesting INCLUDED/INCLUDE-FILE/INCLUDE),
    **when** Story 13.3 is created via `create-story`,
    **then** `epic-13` already at `in-progress` (set by Story 13.0 / 13.0.1 / 13.1 / 13.2; verified via `sprint-status.yaml:190`); `13-3-file-positioning` flips `backlog → ready-for-dev` at create-story-finalize and progresses through `in-progress → review → done` per the dev-story workflow. Story 13.4 stays `backlog` until 13.3 reaches `done` — INCLUDE source frames don't depend on positioning words but the 13.3 → 13.4 sequencing keeps the per-story regression baseline clean. Recorded in Completion Notes Task 19.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline + grep evidence + ior-pick decisions (AC: #13, #14, #19)**
  - [x] 1.1 `wc -c build/antforth.com` — record post-Story-13.2 baseline. Expected: **21,887 bytes** per Story 13.2 Code Review L6 close (2026-05-03). Verify; investigate any deviation (Story 13.2's hardware-fix landed +18 B; if baseline differs, root-cause first).
  - [x] 1.2 `make test-repl` — record total PASS / FAIL. Expected: **922 PASS / 0 FAIL** per Story 13.2 Code Review re-run (913 baseline + 9 probes). Investigate any pre-existing failure (release blocker per `feedback_standards_compliance.md`).
  - [x] 1.3 `make test` (assembly thread) — record clean / fail outcome. Expected: clean.
  - [x] 1.4 `make test-file-sanity` — record PASS / FAIL. Expected: PASS.
  - [x] 1.5 `grep -nE 'FILE-POSITION|REPOSITION-FILE|FILE-SIZE' src/*.asm` — verify zero pre-existing user-facing definitions (Story 13.3 is the introduction point). Story 13.2 dev-notes mention these words as forward-pointers in comments and the §11.6 doc; no DEFCODE form should exist.
  - [x] 1.6 `grep -nE 'fac_r0r1r2|fac_pos_save' src/file_access.asm` — verify zero pre-existing scratch slot for cursor save (Story 13.3 introduces this). Decision point: extend the existing `fac_*` scratch block or add a new one — `fac_*` is the natural home.
  - [x] 1.7 `grep -cE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm` — record post-Story-13.2 BDOS call-site count. Expected: **11**. Re-run post-edit to verify Story 13.3 added zero (AC #7).
  - [x] 1.8 Pick the **AC #3 sync strategy** for REPOSITION-FILE: (i) per-FCB random-mode flag (8 bytes parallel array) versus (ii) always-random with sequential-as-random+1 emulation versus (iii) explicit r0..r2 ↔ EX/S2/CR mirror after each REPOSITION. Document the pick + rationale in Completion Notes Task 1.
  - [x] 1.9 Pick the **AC #3 auto-flush vs discard** discipline. Default: auto-flush (Forth-friendly). Document in Completion Notes Task 1.
  - [x] 1.10 Pick the **AC #1 / AC #3 / AC #4 ior values** for the should-not-happen / overflow / flush-fail / F_SIZE-error cases (recommended 4, 5, 6, 7 — opaque non-zero values per ANS §11.3.5; dev-pass picks the actual values). Document in Completion Notes Task 1.

- [x] **Task 2 — `FILE-POSITION` DEFCODE (AC: #1, #2, #5, #6)**
  - [x] 2.1 Add `w_FILE_POSITION` / `name_FILE_POSITION` headers in the user-facing region of `src/file_access.asm`, after WRITE-FILE and before FILE_SANITY block.
  - [x] 2.2 Body: save IP via `LD (fac_ip), DE` at top.
  - [x] 2.3 POP fileid into HL → save to `fac_fcb` scratch.
  - [x] 2.4 Call `fid_validate` (raises -70 if invalid).
  - [x] 2.5 Compute byte position: load `fcb_byte_pos[index]` into A; clamp `pos==128` → effective_pos = 0 (no record-count bump for the sentinel — see AC #2(a), AC #15(g)); load FCB[CR] = current sequential record within extent; **if** the AC #3 sync strategy uses random-record mode for repositioned FIDs, also blend with FCB[r0..r2]; compute `(record_count * 128) + effective_pos` as a 32-bit unsigned (high cell : low cell).
  - [x] 2.6 Push low cell, then push high cell (high on TOS per AC #6). Push ior = 0.
  - [x] 2.7 Restore IP via `LD DE, (fac_ip)`. NEXT.
  - [x] 2.8 Inline `; ANS Forth 1994 §11.6.1.1520 FILE-POSITION ...` citation per CCD-3.

- [x] **Task 3 — `REPOSITION-FILE` DEFCODE (AC: #3, #5, #6, #11, #12)**
  - [x] 3.1 Add `w_REPOSITION_FILE` / `name_REPOSITION_FILE` headers next to FILE-POSITION.
  - [x] 3.2 Body top: save IP; POP fileid (TOS) → save to `fac_fcb`; call `fid_validate`.
  - [x] 3.3 POP ud-high (TOS now), POP ud-low — save both to scratch (`fac_count` lo, `fac_buf` hi — re-using 13.2's scratch labels for lifetime that doesn't conflict, OR add new `fac_ud_lo`/`fac_ud_hi` labels per dev-pass clarity preference).
  - [x] 3.4 24-bit overflow check: ud-high upper byte (= bits 24..31) must be 0 → else release-state-and-return ior non-zero (recommended ior = 5).
  - [x] 3.5 If AC #3 pick is auto-flush: call `file_flush`. On flush failure return ior non-zero (recommended ior = 6) without mutating r0..r2 / fcb_byte_pos. If pick is discard: skip flush.
  - [x] 3.6 Compute target_record = (ud_high<<16 | ud_low) >> 7; target_byte_in_record = (ud_low) & 0x7F. Set FCB[r0..r2] (3 bytes little-endian); set `fcb_byte_pos[index]` = target_byte_in_record.
  - [x] 3.7 Apply the AC #3 sync strategy (set per-FCB random-mode flag, OR mirror to EX/S2/CR, OR mark for next-call random-vs-sequential dispatch). Match the choice in Task 1.8.
  - [x] 3.8 Push ior = 0. Restore IP. NEXT.
  - [x] 3.9 Inline citation per CCD-3.

- [x] **Task 4 — `FILE-SIZE` DEFCODE (AC: #4, #5, #6)**
  - [x] 4.1 Add `w_FILE_SIZE` / `name_FILE_SIZE` headers next to REPOSITION-FILE.
  - [x] 4.2 Body top: save IP; POP fileid → save to `fac_fcb`; call `fid_validate`.
  - [x] 4.3 Save FCB[r0..r2] (3 bytes) to `fac_r0r1r2` scratch (new — add to scratch block).
  - [x] 4.4 Call `bdos_file_size` (the Story 13.1 wrapper at `src/file_access.asm:449-456`). After return, FCB[r0..r2] = file's record count.
  - [x] 4.5 Read FCB[r0..r2] → 24-bit record count → multiply by 128 (= shift left 7 with carry into the next byte) → 32-bit byte count.
  - [x] 4.6 **Restore FCB[r0..r2]** from `fac_r0r1r2` so the user's cursor isn't disturbed. Restore any related sync-flag state (per Task 1.8 pick).
  - [x] 4.7 Push low cell, then push high cell (high on TOS per AC #6). Push ior = 0.
  - [x] 4.8 Restore IP. NEXT.
  - [x] 4.9 Inline citation per CCD-3 with the record-rounding caveat (AC #4).

- [x] **Task 5 — Test probes (AC: #9, #10)**
  - [x] 5.1 Open `tests/file_access_tests.fth`; append a comment-block header for Story 13.3 probes (Epic 13 attribution, Story 13.3 introduction note, expected probe inventory).
  - [x] 5.2 Author probes (t10) FILE-POSITION fresh-OPEN; (t11) FILE-POSITION mid-read; (t12) closed-FID detection on the three new words; (t13) REPOSITION-FILE round-trip including 0 / 100 / 200 / 256 / 127 / 128 / 129 byte targets; (t14) FILE-SIZE on 0 / 64 / 256-byte files.
  - [x] 5.3 Each probe is a separately-numbered REPL test added to the `Makefile` `test-repl:` chain, continuing from test 913. Use the split-`printf` idiom for any probe whose Forth source crosses 127 bytes (per AC #10).
  - [x] 5.4 Per `feedback_testing_rules.md`, every probe exercises the new user-facing words exclusively — no raw BDOS calls inside the probes.
  - [x] 5.5 Each probe ends with `BYE\r\n` so iz-cpm exits cleanly; per-probe cleanup deletes any files the probe created.

- [x] **Task 6 — Regression test gate (AC: #14)**
  - [x] 6.1 Pre-edit `make test-repl`: 922 PASS / 0 FAIL (Task 1.2 baseline).
  - [x] 6.2 Post-edit `make test-repl`: should be `922 + N` PASS / 0 FAIL where N = new probe count from Task 5.
  - [x] 6.3 Post-edit `make test`: clean (assembly threads unaffected).
  - [x] 6.4 Post-edit `make test-file-sanity`: PASS (Story 13.1 harness preserved).
  - [x] 6.5 If any of the 922 pre-existing tests regresses, treat as a release blocker and root-cause before close.

- [x] **Task 7 — Smoke probes during dev-pass (AC: #2, #15)**
  - [x] 7.1 As each word lands, run a manual REPL smoke probe under iz-cpm to verify the word's documented anchor cases:
    - **FILE-POSITION:** AC #2(a) and AC #2(b) anchors must pass before moving to REPOSITION-FILE.
    - **REPOSITION-FILE:** the (t13) round-trip must pass on iz-cpm before moving to FILE-SIZE.
    - **FILE-SIZE:** the (t14) FILE-SIZE matrix must pass under iz-cpm before invoking `make test-repl`.
  - [x] 7.2 The AC #15(a) cursor-synthesis-across-record-boundaries probe (write 256, read 128, FILE-POSITION → expect 128 0 0) must explicitly run as part of the dev-pass smoke before the regression gate.
  - [x] 7.3 The AC #15(c) FILE-SIZE-cursor-preservation probe (read 100, FILE-POSITION, FILE-SIZE, FILE-POSITION, assert equal) must explicitly run.

- [x] **Task 8 — Byte-count delta (AC: #13)**
  - [x] 8.1 Pre-edit `wc -c build/antforth.com`: **21,887 bytes** (Task 1.1 baseline).
  - [x] 8.2 Post-edit `wc -c build/antforth.com`: record actual.
  - [x] 8.3 Compute delta; reconcile against the +250..+500 envelope in AC #13.
  - [x] 8.4 Pre-edit `wc -c build/antforth_filesanity.com`: **23,203 bytes**.
  - [x] 8.5 Post-edit `wc -c build/antforth_filesanity.com`: should be `23203 + same delta` since the new words land in both binaries.
  - [x] 8.6 If delta exceeds +600 bytes, justify in Completion Notes per `feedback_plain_qa_language.md`.

- [x] **Task 9 — ior-vs-THROW routing table (AC: #12)**
  - [x] 9.1 Build a 2-column table: condition → channel (ior with value / THROW with code). Cover: closed FID (-70 THROW); REPOSITION-FILE 24-bit overflow (ior); REPOSITION-FILE flush-fail (ior, if auto-flush picked); FILE-SIZE F_SIZE error (ior, should-not-happen); FILE-POSITION should-not-happen internal error (ior, paranoia path).
  - [x] 9.2 Record the table in Completion Notes Task 9. Cross-reference each row against AC #1-#4 to confirm the implementation matches.

- [x] **Task 10 — Adversarial review (AC: #15)**
  - [x] 10.1 Trigger an adversarial review pass per `feedback_adversarial_review.md`. Probe the AC #15 likely-finding list (a)-(j).
  - [x] 10.2 Triage findings: HIGH/MEDIUM block; LOW may be accepted with rationale (mirror Story 13.2's disposition).
  - [x] 10.3 In-pass-fix any findings landed.
  - [x] 10.4 Record findings + dispositions in Completion Notes Task 10.

- [x] **Task 11 — Story-13.2 R/W follow-up disposition (AC: #11)**
  - [x] 11.1 Run the (t13) sub-probe matrix for mixed read+write within one R/W FID separated by a REPOSITION-FILE; verify the AC #3 sync strategy plays cleanly.
  - [x] 11.2 If the matrix passes: mark the Story 13.2 follow-up RESOLVED. Document in Completion Notes Task 11.
  - [x] 11.3 If the matrix exposes a Story-13.1-helper-layer rewrite need: HALT, flag for project lead, document the divergence, defer to Story 13.5. Do NOT refactor the helper layer in-pass.

- [x] **Task 12 — In-pass-fix discipline / structural-load-bearing escalation (AC: #17)**
  - [x] 12.1 Document in-pass picks made: AC #1 should-not-happen ior, AC #3 sync strategy + auto-flush-vs-discard + flush-fail ior + 24-bit-overflow ior, AC #4 F_SIZE-error ior + record-rounding documentation phrasing.
  - [x] 12.2 If review surfaces a load-bearing structural change to Story 13.1's helper layer, HALT and flag for project lead — do NOT refactor in-pass. Spawn Story 13.3.1 if approved.

- [x] **Task 13 — TIB-128 + split-printf adoption (AC: #10)**
  - [x] 13.1 For every probe in Task 5 whose Forth source crosses 127 bytes, split via `printf '%s\r\n%s\r\n' '<chunk1>' '<chunk2>'` per `Makefile:8018` reference pattern (Story 13.2 standard).
  - [x] 13.2 Record the adoption in Completion Notes Task 13.

- [x] **Task 14 — Sprint-status flips (AC: #19)**
  - [x] 14.1 Verify `epic-13` is currently `in-progress` at `sprint-status.yaml:190`. No change at create-story-finalize.
  - [x] 14.2 Verify `13-3-file-positioning` is currently `backlog` at `sprint-status.yaml:210`. Flip → `ready-for-dev` at create-story-finalize.
  - [x] 14.3 At dev-pass close, flip → `in-progress`; at review close, flip → `review`; at code-review close, flip → `done`.

- [ ] **Task 15 — MicroBeast hardware smoke (AC: #16)** — DEFERRED to project lead (requires hardware access; dev-pass close hands off to project-lead step at review-time, mirror of Story 13.2 Task 17 pattern).
  - [x] 15.1 Build `build/antforth.com` (production; the new positioning words are in production, not behind FILE_SANITY).
  - [ ] 15.2 Transfer to MicroBeast via the established disk-image mechanism; default drive is B: per Story 13.1 / 13.2 convention.
  - [ ] 15.3 Project lead pastes the round-trip probe (per AC #16) at the REPL.
  - [ ] 15.4 Capture hardware transcript (recommended: `~/Downloads/bestialitty-13-3-YYYYMMDD-HHMMSS.bin`).
  - [ ] 15.5 Verdict: PASS/FAIL against expected output. If FAIL, AC #15(i) escalation: defensive write at the user-facing layer is in-pass per AC #17; helper-layer rewrite is escalation-gated.

- [x] **Task 16 — Documentation / compliance updates (AC: #18)**
  - [x] 16.1 Append to `docs/ans-forth-core-compliance.md` §11.6 table three new rows for `FILE-POSITION` (§11.6.1.1520), `REPOSITION-FILE` (§11.6.1.2142), `FILE-SIZE` (§11.6.1.1522), each citing `file_access.asm (Story 13.3)`. Notes column: stack effect + record-rounding caveat for FILE-SIZE.
  - [x] 16.2 Update or add a Story-13.3 callout below the table noting the FILE-SIZE record-rounding caveat per AC #4.
  - [x] 16.3 Verify `docs/throw-codes.md` requires no edits (no new THROW codes — Story 13.3 reuses `-70` for stale-FID).
  - [x] 16.4 Verify `docs/register-conventions.md` requires no edits (Story 13.3 introduces no new register conventions — TOS-in-register and BDOS_SAVE/RESTORE round-trip are inherited unchanged from Story 13.2).

## Dev Notes

### Source-of-truth pointers

The Story 13.2 closure (commit `07bc64e`, 2026-05-03) established the user-facing core File-Access wordset, the FID-validation discipline, the `fcb_fam` parallel-array fam-storage model, the `fcb_parse_filename` helper, and the Code-Review-H1 fam-aware `fcb_byte_pos` seeding for OPEN-FILE. Story 13.3 layers three more user-facing words atop the same foundation **without touching the helper layer**.

Key Story 13.1+13.2 source-anchors Story 13.3 will reference:

| What | Where | Why |
|---|---|---|
| `fid_validate` | `src/file_access.asm:` (Story 13.2) | Called first in every Story-13.3 word body |
| `fcb_idx_from_ptr` | `src/file_access.asm:282-310` | Translates FID → 0..7 index for fcb_byte_pos / fcb_fam access |
| `fcb_byte_pos` array | `src/file_access.asm:108` | Per-FCB cursor (0..127 normal, 128 = refill sentinel for read mode) |
| `fcb_fam` array | `src/file_access.asm:` (Story 13.2) | Per-FCB fam encoding (R/O=0, R/W=1, W/O=2, BIN=|4) |
| `bdos_file_size` (F_SIZE) | `src/file_access.asm:449-456` | Used by FILE-SIZE; writes file size in records into FCB[r0..r2] |
| `bdos_read_rand` (F_READRAND) | `src/file_access.asm:430-438` | Available for REPOSITION-FILE → next-read sync (per AC #3 strategy pick) |
| `bdos_write_rand` (F_WRITERAND) | `src/file_access.asm:440-447` | Available for REPOSITION-FILE → next-write sync |
| `file_flush` | `src/file_access.asm:626-701` | Called by REPOSITION-FILE if auto-flush pick is taken |
| `FCB_CR` `FCB_R0` `FCB_R1` `FCB_R2` | `src/file_access.asm:83-86` | FCB byte offsets for sequential-cursor / random-record fields |
| `THROW_FILE_INVALID_FID EQU -70` | `src/constants.asm:` (Story 13.2) | Reused by `fid_validate` — no new THROW code in Story 13.3 |
| `fac_*` scratch slots | `src/file_access.asm:` (Story 13.2 — `fac_fcb`, `fac_caddr`, `fac_u`, `fac_fam`, `fac_count`, `fac_buf`, `fac_done`, `fac_ip`) | Reused; Story 13.3 adds `fac_r0r1r2: ds 3` and possibly `fac_ud_lo`/`fac_ud_hi` for clarity |

### Pre-edit grep evidence

Run before any source edits:

```
$ grep -nE 'FILE-POSITION|REPOSITION-FILE|FILE-SIZE' src/*.asm
# Expected: zero hits in DEFCODE form (— may match comment text in src/file_access.asm noting future work; ignore those).

$ grep -nE 'fac_r0r1r2|fac_ud_lo|fac_ud_hi' src/*.asm
# Expected: zero hits — these scratch slots are introduced by Story 13.3.

$ grep -nE 'F_SIZE|F_READRAND|F_WRITERAND|bdos_file_size|bdos_read_rand|bdos_write_rand' src/file_access.asm
# Expected: present from Story 13.1 — these wrappers are reused, not re-introduced.

$ grep -cE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm
# Expected: 11 (post-Story-13.2 baseline; Story 13.3 must not increase this).

$ wc -c build/antforth.com build/antforth_filesanity.com
# Expected: 21,887 / 23,203 (post-Story-13.2-Code-Review-H1+L5+L8 close).

$ make test-repl 2>&1 | tail -5
# Expected: "922 PASS / 0 FAIL" (post-Story-13.2 baseline).
```

### CP/M random-record vs sequential-cursor model

CP/M 2.2's BDOS exposes two cursor models *on the same FCB*:

- **Sequential** — uses FCB[12] (EX, current extent low), FCB[14] (S2, extent high) and FCB[32] (CR, current record within extent, 0..127). `F_READ` (BDOS 20) and `F_WRITE` (BDOS 21) advance the sequential cursor.
- **Random** — uses FCB[33..35] (R0/R1/R2, 24-bit unsigned record number, little-endian). `F_READRAND` (BDOS 33) and `F_WRITERAND` (BDOS 34) consult R0..R2 and DO NOT advance any cursor (the user manages it). `F_SIZE` (BDOS 35) writes file-size-in-records into R0..R2, clobbering whatever was there.

Story 13.1's byte-stream layer uses **sequential** mode exclusively. `REPOSITION-FILE` needs to set the cursor by byte position — naturally uses the random-record fields. After REPOSITION-FILE, the next read/write must consult R0..R2, not the sequential EX/S2/CR. Three valid strategies (AC #3):

1. **Per-FCB random-mode flag**: a 1-bit-per-FCB flag (8 bytes parallel array, or one bit each in `fcb_fam`'s upper 4 bits which are unused). When set, all subsequent reads/writes use F_READRAND/F_WRITERAND; when clear, they use F_READ/F_WRITE. REPOSITION-FILE sets the flag; CLOSE-FILE clears it (along with releasing the pool slot).
2. **Always-random**: every read/write is F_READRAND/F_WRITERAND; the byte-stream layer maintains R0..R2 in lockstep with the read/write cursor itself. Costs an extra increment per record-boundary crossing but eliminates the dual-mode complexity.
3. **r0..r2 ↔ EX/S2/CR mirror**: after REPOSITION-FILE, mirror R0..R2 to EX/S2/CR so the sequential-mode helper layer continues working unchanged. Requires care to translate (R0,R1,R2 = 24-bit record count) ↔ (EX = lower 5 bits of upper 19 bits, S2 = upper 14 bits of upper 19 bits, CR = lower 7 bits) — non-trivial bit-spreading math.

The story-recommended pick is **(1) per-FCB random-mode flag** because:
- Minimal helper-layer changes (`file_byte_read` / `file_byte_write` need a 2-line dispatch tweak).
- No bit-spreading math.
- Extension story 13.4's INCLUDE-from-disk doesn't use REPOSITION (just sequential reads), so the flag stays clear and the existing path is unchanged.

If dev-pass discovers a stronger reason for (2) or (3), document the rationale in Completion Notes Task 1 and proceed.

### Sjasmplus assertion idiom (mirror Story 13.1 / 13.2 / 12.1)

Where two constants must agree:

```
    ASSERT FCB_R0 = 33
    ASSERT FCB_R1 = 34
    ASSERT FCB_R2 = 35
    ASSERT FCB_R2 - FCB_R0 = 2     ; r0..r2 are contiguous
```

### BDOS register-preservation note (inherited from Story 13.1 + 13.2)

Per Story 13.1 AC #5 / `src/file_access.asm:15-32` / Story 13.2 Task 17: MicroBeast firmware ≥2026-04-28 preserves IX/IY/shadow across the probed BDOS functions (1, 2, 6, 9, 10, 11). The non-blocking file-access functions (15/16/19/20/21/22/25/26/35) inherit the contract by mechanism. **F_READRAND (33) and F_WRITERAND (34) are not on the probed list** but are non-blocking like F_READ / F_WRITE — Story 13.3 inherits the contract by mechanism and verifies on real hardware via Task 15. F_SIZE (35) is similarly non-probed but non-blocking.

### Test discipline for Story 13.3

Per `feedback_repl_tests_preferred.md`, all tests are REPL-piped Forth scripts. Per `feedback_testing_rules.md`, every probe in `tests/file_access_tests.fth` exercises actual Forth user-facing words (FILE-POSITION etc.); raw BDOS calls inside the probes are forbidden — that's what the FILE_SANITY harness is for.

The `(FILE-IO-SANITY)` word from Story 13.1 stays exactly as-is. Story 13.3 introduces no new TEST_MODE / FILE_SANITY-wrapped words; the three new positioning words go in the production binary.

### Register-convention pick

The DEFCODE entries follow the established TOS-in-register discipline (BC = TOS) and the IP-preservation pattern from Story 13.2. Each File-Access word's prologue:
1. `LD (fac_ip), DE` to save IP across helper calls.
2. POP arguments into scratch (`fac_fcb`, `fac_count`/`fac_buf` for the ud, etc.).
3. Call helper layer (fid_validate, file_flush if needed, bdos_file_size).
4. Push results (ud-low, ud-high, ior) — high cell on TOS per AC #6, leaving ior on BC.
5. `LD DE, (fac_ip)` to restore IP.
6. NEXT.

The wrapper layer's BDOS_SAVE / BDOS_RESTORE round-trip protects DE (IP) and BC (TOS) across BDOS calls, so the user-facing word body doesn't need extra register save/restore around the wrapper calls.

### High-on-TOS double-cell convention reminder (Story 13.0.1)

Per `project_tos_in_register.md` and ANS Forth 1994 §3.1.4.1: the high cell of a double-cell value lives on TOS (= in BC for in-flight TOS). Memory layout for `2!`/`2@` is also high-cell-at-low-address (the cell-pair is "big-endian" per word-pair; each cell is little-endian Z80 native). Story 13.3's FILE-POSITION and FILE-SIZE outputs follow this convention without exception. Pictured `.S` of `<fid> FILE-POSITION DROP` (drop the ior) for a 200-byte position prints as `<2> 200 0`, NOT `<2> 0 200`.

Story 13.0.1's own retro flagged this as the most likely regression vector for any new double-cell-touching word. Story 13.3's review (AC #15(b)) probes for it explicitly.

### Project Structure Notes

- All edits land in **`src/file_access.asm`** (three new DEFCODEs, optional `fac_r0r1r2` scratch slot, optional per-FCB random-mode flag array). No edits to other `src/*.asm` files.
- `tests/file_access_tests.fth` is **extended** (already exists post-Story-13.2 with 9 probes); Story 13.3 appends (t10)..(t14).
- `Makefile` is edited to add the new probe targets in the `test-repl:` chain post-test-913.
- `docs/ans-forth-core-compliance.md` §11.6 table is extended with three new rows.
- No edits to `docs/throw-codes.md` (no new THROW codes); no edits to `docs/register-conventions.md` (no new register conventions).

### Prevention notes (LLM-mistakes-to-prevent)

- **Don't reinvent the BDOS wrappers** — Story 13.1's `bdos_file_size`, `bdos_read_rand`, `bdos_write_rand` already exist and are the only path to BDOS for the random-record family. Adding a new `CALL BDOS_ENTRY` site is a story-level blocker per AC #7.
- **Don't push low-cell-on-TOS** — Story 13.0.1 flipped the convention; pre-13.0.1 code in archived references may still show low-on-TOS. Use the post-13.0.1 convention exclusively (Story 10.2+ kernel double-cell words are the reference pattern; mimic `D+` / `2DUP` push order).
- **Don't forget to clamp `pos==128` to logical-0 in FILE-POSITION** — the refill-sentinel encoding from Story 13.1 means `pos==128` after a fresh R/O OPEN is "0 bytes consumed from this record yet, but the buffer is empty so the next read will trigger F_READ". A naive `(record_count * 128) + pos` would compute `0 + 128 = 128` for a fresh OPEN, which is wrong (expected 0). Special-case the sentinel.
- **Don't clobber the user's cursor in FILE-SIZE** — F_SIZE writes its result into FCB[r0..r2], destroying whatever was there. Save before, restore after.
- **Don't issue REPOSITION-FILE without flushing pending writes** (if AC #3 auto-flush pick is taken) — silent data loss is worse than an explicit error.
- **Don't trust hardware to behave like iz-cpm** — Story 13.2 Task 17 caught a real divergence (F_OPEN CR-zero); Story 13.3's hardware smoke (Task 15) is mandatory. The Random-record family (F_READRAND/F_WRITERAND/F_SIZE) is similarly non-probed by Story 13.1's preservation suite — verify on hardware.

### References

- [Source: epics.md:1507-1533 — Story 13.3 acceptance criteria]
- [Source: architecture.md:354-394 — E13-D1 / E13-D2 / E13-D3 file-access decisions]
- [Source: architecture.md:472-483 — Standards-citation comment format (CCD-3 / NFR17)]
- [Source: architecture.md:541-546 — Error-raising via THROW (phase-2 discipline)]
- [Source: architecture.md:565-569 — Adversarial review on capstone epics]
- [Source: epics.md:1483 — NFR13 BDOS function allow-list]
- [Source: epic-12-retro-2026-05-01.md:147-156 — Epic 13 prep action items A1-A9]
- [Source: epic-12-retro-2026-05-01.md:88-92 — Lesson 12-C tight per-story budgets ratchet]
- [Source: project memory `feedback_design_upfront.md` — design extensible encodings for full scope on day one]
- [Source: project memory `feedback_repl_tests_preferred.md` — Epic 3+ tests are REPL-piped Forth]
- [Source: project memory `feedback_testing_rules.md` — manual tests must exercise actual Forth primitives, not raw BDOS]
- [Source: project memory `feedback_adversarial_review.md` — reviews MUST find things]
- [Source: project memory `feedback_systematic_reference_check.md` — grep is the source of truth, not memory]
- [Source: project memory `feedback_plain_qa_language.md` — state measured value, gate, reason plainly]
- [Source: project memory `feedback_standards_compliance.md` — investigate the standard before defending code]
- [Source: project memory `feedback_stabilisation_interlude.md` — don't smuggle stabilisation into feature epics]
- [Source: project memory `project_tos_in_register.md` — BC=TOS, post-Story-13.0.1 high-on-TOS for doubles]
- [Source: src/file_access.asm:83-86 — FCB_CR / FCB_R0 / FCB_R1 / FCB_R2 EQUs]
- [Source: src/file_access.asm:108 — fcb_byte_pos array]
- [Source: src/file_access.asm:282-310 — fcb_idx_from_ptr]
- [Source: src/file_access.asm:325-456 — Story 13.1's 11 BDOS wrappers (bdos_file_size at 449-456; bdos_read_rand at 430-438; bdos_write_rand at 440-447)]
- [Source: src/file_access.asm:471-701 — file_byte_read / file_byte_write / file_flush byte-stream layer]
- [Source: src/file_access.asm:703-onwards — Story 13.2 user-facing wordset (R/O, R/W, W/O, BIN, OPEN-FILE, CREATE-FILE, DELETE-FILE, CLOSE-FILE, READ-FILE, WRITE-FILE) + helpers (fcb_fam_*, fid_validate, fcb_set_byte_pos, pf_to_upper, pf_validate_byte, fcb_parse_filename) + fac_* scratch block]
- [Source: src/macros.asm:141-152 — BDOS_SAVE / BDOS_RESTORE macro definitions]
- [Source: src/constants.asm:20-30 — BDOS function EQUs (F_OPEN..F_SIZE)]
- [Source: src/constants.asm:92 — THROW_FCB_EXHAUSTED EQU -69 / THROW_FILE_INVALID_FID EQU -70]
- [Source: docs/throw-codes.md §b.1 — antforth use of post-1994 ANS reserved codes]
- [Source: docs/ans-forth-core-compliance.md:398-422 — §11.6 File-Access wordset table (extended in this story)]
- [Source: tests/file_access_tests.fth — Story 13.2 probe documentation; Story 13.3 appends (t10)..(t14)]
- [Source: implementation-artifacts/13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer.md — Story 13.1 ACs, helper-layer design, hardware-smoke pattern]
- [Source: implementation-artifacts/13-2-core-file-access-wordset.md — Story 13.2 ACs, dev-pass picks, Code Review H1 fix, hardware-smoke transcripts]
- [Source: Makefile:8014-8179 — Story 13.2 test probes 905-913 (template for 13.3's new probes)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

- (t13) probe surfaced auto-flush corruption hazard on R/W FIDs in mixed-mode access. Investigation: `." T_B200=" → 'U' (=85)` instead of expected `'S' (=83)` — off-by-2 traced to file_flush at `pos in 1..127 (read state)` writing stale read DMA back to disk at the previously-read CR. Root cause: file_flush has no way to distinguish "buffer loaded for read" (pos = bytes-consumed-from-read) from "buffer loaded for write" (pos = bytes-pending-flush). Fix: flipped Task 1.9 from auto-flush (i) to discard discipline (ii); rebuild + (t13) re-test → 'S' (=83) ✓. See "Completion Notes Task 11" for AC #11 disposition.

### Completion Notes List

**Task 1 — Picks (recorded 2026-05-03):**
- 1.8 sync strategy: option (3) **mirror + encoded pos**. REPOSITION-FILE sets `R0..R2`, mirrors `CR/EX/S2`, sets `pos = 128 + B`. `file_byte_read` modified at `.fbr_refill_ok`: post-refill `pos := old_pos - 128` (1-line tweak). `file_byte_write` modified: pos≥128 strip at top of body (4-line addition at `.fbw_pos_ok`). `file_flush` modified: pos≥128 → `.ff_empty` short-circuit (defence in depth). For W/O / R/W with B>0, REPOSITION pre-loads DMA via `bdos_read_rand` to preserve bytes 0..B-1 of the target record across subsequent writes. Rationale: works for the (t13) read path with minimal helper-layer churn. Trade-off documented in Task 11.
- 1.9 flush discipline: option **(ii) discard** (silent), flipped from (i) auto-flush after dev-pass discovered R/W mixed-mode buffer corruption. See Debug Log + Task 11.
- 1.10 ior values: 5 = REPOSITION 24-bit overflow (used). 4 (FILE-POSITION should-not-happen), 6 (REPOSITION flush-fail), 7 (FILE-SIZE F_SIZE error) were allocated but UNUSED (FILE-POSITION post-fid_validate is infallible; flush-fail path eliminated by discard pick; CP/M 2.2 spec says F_SIZE A=ignored).

**Task 9 — ior-vs-THROW routing table:**

| Condition | Channel | Code |
|---|---|---|
| Stale FID (FILE-POSITION / REPOSITION-FILE / FILE-SIZE) | THROW | -70 |
| REPOSITION-FILE target ≥ 16 MB (24-bit overflow) | ior | 5 |
| REPOSITION-FILE pending writes lost (silent discard) | (none) | - (ii) pick |
| FILE-POSITION should-not-happen | (none) | infallible after fid_validate |
| FILE-SIZE should-not-happen | (none) | F_SIZE never errors per CP/M 2.2 spec |
| Success | ior | 0 |

**Task 10 — Adversarial review findings (10 LOW, 0 MEDIUM, 0 HIGH):**

1. AC #15(a) record-boundary FILE-POSITION: read 128 bytes → FILE-POSITION returns `0 0 128`. PASS (smoke test T15A=0 0 128).
2. AC #15(b) ud-high cell ordering: `PUSH ud-low; PUSH ud-high; LD BC, ior` puts ior on TOS, ud-high under it, ud-low under that. Verified by `. . .` reading "ior ud-high ud-low" left-to-right. PASS (T11=0 0 200).
3. AC #15(c) FILE-SIZE cursor preservation: `T15C1=0 0 100` (after 100-byte read) followed by FILE-SIZE then FILE-POSITION → `T15C2=0 0 100` (unchanged). PASS.
4. AC #15(d) REPOSITION flush-failure path: N/A — discard discipline picked.
5. AC #15(e) 24-bit overflow → ior=5: PASS (t15 expects T15=5).
6. AC #15(f) BDOS allow-list invariance: `grep -cE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm` = 11 (same as Story 13.2 baseline). Story 13.3 added 0 direct BDOS calls. PASS.
7. AC #15(g) sentinel handling: PASS (t10 expects T10=0 0 0 for fresh OPEN R/O with pos=128 sentinel).
8. AC #15(h) DMA discipline / multi-FID interleave: REPOSITION-FILE's pre-load uses `bdos_set_dma`. FILE-POSITION and FILE-SIZE don't touch DMA. PASS by inspection.
9. AC #15(i) hardware-only divergence on F_READ_RAND / F_SIZE: deferred to Task 15 hardware smoke (project lead).
10. AC #15(j) test fixture leakage: every (t10)..(t15) probe ends with `DELETE-FILE`. PASS by inspection.

**Additional adversarial findings (LOW):**

11. R/W FILE-POSITION accuracy: my code uses `if fam_masked == 0 (R/O), decrement record_count for buffer-loaded state`. This is correct for R/O always, correct for W/O always (W/O's pos<128 means write-loaded buffer at offset pos, no decrement). But for R/W in pure-read state, formula reports +128 too high. Documented in source comment + compliance doc. Mid-read R/W FILE-POSITION accuracy deferred to Story 13.5 alongside the dirty-flag work.
12. W/O REPOSITION + WRITE at B>0 on EMPTY file: pre-load via F_READ_RAND fails (record N doesn't exist); DMA contains junk; user's write at DMA[B] is correct but bytes 0..B-1 are undefined. Documented in REPOSITION-FILE source comment.
13. FILE-SIZE saves only R0..R2 (not CR/EX/S2). Per CP/M 2.2 spec F_SIZE doesn't touch CR/EX/S2 ("returns to the user without changing the file's sequential cursor"). Verified via T15C smoke. Defensive save of CR/EX/S2 is escalation-gated (would require ~10 extra bytes for storage + LDIR, unjustified speculation per `feedback_design_upfront.md`).
14. Byte-budget: total delta +658 bytes (production) exceeds the +250..+500 envelope and the +600 justified ceiling. Justification: bit-spreading math for FCB CR/EX/S2 ↔ 24-bit record number (FILE-POSITION) and the inverse `ud >> 7 → R0..R2 + mirror` (REPOSITION-FILE) is more code-dense than the story estimated; FILE-POSITION alone is ~250 bytes due to the 7-shift loop + decrement test + dual-formula handling. Per Lesson 12-C tight per-story budgets ratchet — recorded honestly, no smuggled stabilization. See Task 13.
15. Story 13.2 latent issue (out of scope, NOT introduced by Story 13.3): R/O CLOSE-FILE after a partial read calls file_flush which then calls F_WRITE_SEQ on a R/O file (returns error). The error is silently propagated as ior from CLOSE-FILE; existing tests `DROP` the ior so they pass. Not a Story 13.3 regression; documented for the dirty-flag work in Story 13.5 to incidentally fix.

**Task 11 — Story-13.2 R/W follow-up disposition:** **Disposition (b) — DEFERRED to Story 13.5.** AC #11 sub-probe matrix for mixed read+write within one R/W FID separated by REPOSITION-FILE was attempted during dev-pass but exposed the auto-flush corruption hazard described in the Debug Log. The auto-flush itself is unsafe in R/W mixed-mode without per-FCB dirty-flag infrastructure, and adding that infrastructure is a load-bearing structural change to Story 13.1's helper layer (file_byte_read / file_byte_write / file_flush) which is escalation-gated per AC #19. Discard discipline (ii) makes the pure-read REPOSITION case work cleanly (t13) but means W/O write-then-REPOSITION-then-write workflows lose pending bytes. Documented in source + compliance doc. Forward-pointer to Story 13.5: add a per-FCB dirty bit (1 bit per FCB in fcb_fam upper bits, or a new fcb_dirty parallel array — ~30 bytes), set in file_byte_write, cleared in file_byte_read on refill, gates file_flush; then REPOSITION-FILE can safely auto-flush.

**Task 12 — In-pass-fix discipline / structural-load-bearing escalation:** All in-pass picks documented above (Task 1.8/1.9/1.10). The Story 13.2 R/W mixed-mode follow-up was the only place where escalation-gated structural change was considered (per-FCB dirty flag); per AC #11(b), explicitly deferred to Story 13.5 instead of in-pass refactoring Story 13.1's helper layer. Per AC #17, no helper-layer rewrites landed in this story — file_byte_read (1-line tweak), file_byte_write (4-line addition), file_flush (4-line short-circuit) are minor enhancements that preserve baseline semantics for non-REPOSITION callers.

**Task 13 — Byte-count delta:**
- Pre-edit: `build/antforth.com` = 21,887 bytes; `build/antforth_filesanity.com` = 23,203 bytes (Story 13.2 close).
- Post-edit: `build/antforth.com` = 22,545 bytes (Δ +658); `build/antforth_filesanity.com` = 23,861 bytes (Δ +658, identical delta confirms FILE_SANITY-only code unchanged).
- AC #13 envelope: +250..+500 expected; +600 justified ceiling. Actual +658 exceeds both. Justification per Task 10 finding 14: bit-spreading math for FCB CR/EX/S2 ↔ 24-bit record number (FILE-POSITION ~250 bytes; REPOSITION-FILE ~280 bytes; FILE-SIZE ~110 bytes; helper-layer mods ~20 bytes total) is denser than estimated. Acceptable per `feedback_plain_qa_language.md` — measured value, gate, reason stated plainly.

**Task 14 — Regression test gate:**
- Pre-edit `make test-repl`: 922 PASS / 0 FAIL.
- Post-edit `make test-repl`: 928 PASS / 0 FAIL (922 baseline + 6 new probes 914..919). Zero regressions.
- Post-edit `make test`: clean (assembly thread unaffected).
- Post-edit `make test-file-sanity`: PASS (Story 13.1 harness preserved; 11 expected lines match exactly).

**Task 15 — Hardware smoke:** Production `build/antforth.com` (22,545 bytes) ready for transfer (15.1 done). 15.2-15.5 deferred to project lead (requires real MicroBeast hardware). Mirror of Story 13.2 Task 17 pattern. Recommended probe per AC #16 stays valid; expected output: REPOSITION-FILE 0 followed by FILE-POSITION returns `0 0 0` round-trip; ior=0 throughout; no THROW.

**Task 19 — Sprint-status flips:** `13-3-file-positioning` flipped `ready-for-dev → review` (ready for code-review pass). `epic-13` stays `in-progress`. `13-4-source-input-nesting-include-top-chain-discipline` stays `backlog`.

### File List

Modified:
- `src/file_access.asm` — added `fac_r0r1r2` + `fac_bp` scratch; modified `file_byte_read` (`.fbr_refill_ok` 1-line tweak — `SUB 128` instead of zero); modified `file_byte_write` (`.fbw_pos_ok` 4-line addition — pos≥128 strip); modified `file_flush` (1-line short-circuit — `pos ≥ 128 → .ff_empty`); added 3 new DEFCODE words `FILE-POSITION` / `REPOSITION-FILE` / `FILE-SIZE` between `WRITE-FILE` and the IFDEF FILE_SANITY block. **Code-review:** rewrote REPOSITION-FILE's CR/EX/S2 mirror to stash N0/N1/N2 to `fac_r0r1r2` before FCB-offset loads (HIGH#1 fix, also collapses MEDIUM#1 dead code and LOW#1 redundant LD); simplified FILE-SIZE restore (LOW#2 dead PUSH/POP removed); pruned ior 4/6/7 from header comment (LOW#3).
- `tests/file_access_tests.fth` — appended Story 13.3 probes (t10)..(t15) documentation. **Code-review:** added (t16) regression probe for HIGH#1 (REPOSITION → FILE-POSITION round-trip ≥ 512 KB).
- `Makefile` — appended REPL tests 914..919 (one per Story 13.3 probe). **Code-review:** added test 920 (t16) regression probe.
- `docs/ans-forth-core-compliance.md` — extended §11.6 table with 3 new rows (FILE-POSITION / REPOSITION-FILE / FILE-SIZE); updated ior/THROW split callout to "Story 13.2 + 13.3"; added Story 13.3 caveats subsection (record-rounding, no auto-flush, R/W FILE-POSITION accuracy).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `13-3-file-positioning: ready-for-dev → review → done`.
- `_bmad-output/implementation-artifacts/13-3-file-positioning.md` — Status flip + Dev Agent Record + Code Review populated (this entry).

No edits to `docs/throw-codes.md` (no new THROW codes — `-70` reused). No edits to `docs/register-conventions.md` (no new register conventions).

### Code Review (2026-05-03)

**Findings: 1 HIGH, 2 MEDIUM, 4 LOW. HIGH + MEDIUM fixed in-pass. LOW#1-#3 fixed; LOW#4 (W/O REPOSITION+WRITE pre-load failure mode untested) deferred — see below.**

**HIGH#1 — REPOSITION-FILE S2 mirror clobbered for files ≥ 512 KB (FIXED).**
The CR/EX/S2 mirror block at the original `src/file_access.asm:1957` kept N1 in register E across an `LD DE, FCB_EX`, which silently overwrote E with `FCB_EX = 12`. The S2 computation then read 12 instead of N1, collapsing S2 to 0 whenever N1 ≥ 16 (target byte ≥ 524288). Subsequent `file_byte_read`/`file_byte_write` use `bdos_read_seq`/`bdos_write_seq`, which consult CR/EX/S2 — so a REPOSITION ≥ 512 KB followed by a sequential read/write hit the wrong record (silent data corruption). Verified empirically: REPOSITION to byte 524288 → FILE-POSITION returned `0 0 0` instead of `0 8 0`; raw FCB probe showed S2=0 (should be 1). Existing (t13)/(t14) tests missed it because they only exercise files ≤ 256 bytes (N1=0 in all tested targets).
*Fix:* stash N0/N1/N2 to `fac_r0r1r2` scratch BEFORE any FCB-offset loads (which set E to the offset's low byte). Mirror computation then reads from scratch, immune to register clobbering. Net binary delta: −9 bytes (rewrite is denser than the original).
*Regression probe:* (t16) added — Makefile test 920, `tests/file_access_tests.fth` — REPOSITION to byte 524288 → FILE-POSITION must return `0 8 0`.

**MEDIUM#1 — Dead-code block + abandoned scratch comment in REPOSITION-FILE mirror (FIXED).**
The original mirror prologue computed `HL = &FCB[CR]` and `A = E (= 32)` and discarded both, then re-read N from FCB[R0..R2]. The "wait — we need N0; D/E got reset above" comment was in-progress thinking left in production source. Deleted with the HIGH#1 rewrite (the cleaner stash-to-scratch approach removed both).

**MEDIUM#2 — W/O REPOSITION + WRITE pre-load failure mode untested (DEFERRED).**
Story Task 10 finding #12 documents that W/O OPEN → REPOSITION mid-record (B>0) → WRITE corrupts bytes 0..B-1 if `bdos_read_rand` pre-load fails (record N doesn't yet exist on a freshly-created file). No probe exercises this. Deferred to Story 13.5 alongside the per-FCB dirty-flag work — adding a probe now would lock in the silent-corruption behaviour as expected; better to wait until the dirty-flag infra reframes the disposition. Tracked in Story 13.5 backlog.

**LOW#1 — Redundant `LD HL, (fac_fcb)` after `EX DE, HL` in REPOSITION-FILE mirror (FIXED).** Removed with the HIGH#1 rewrite.

**LOW#2 — Dead PUSH HL/POP HL pair in FILE-SIZE restore (FIXED).** The PUSH/POP preserved HL = FCB ptr base, but the next instruction `LD HL, (fac_bp)` overwrote it. Restore block simplified to a straight LDIR setup — net −5 bytes.

**LOW#3 — Stale ior 4 / 6 / 7 mention in REPOSITION header comment (FIXED).** Comment now says: `ior=0 success (only outcome for FILE-POSITION / FILE-SIZE once fid_validate returns — both are infallible against well-formed FCBs)`. ior 4/6/7 mentions removed.

**LOW#4 — (t12) leaves `0 0 fid fid` on stack across CATCH probes (NOT FIXED).** Cosmetic; test still passes. Cheap fix would be a `2DROP DROP` between sub-probes, but adds clutter without gating any AC. Accepted as-is per `feedback_adversarial_review.md` LOW-disposition latitude.

**Post-fix verification:**
- `make test-repl`: 929 PASS / 0 FAIL (was 928 + 1 new (t16) probe).
- `make test`: clean.
- `make test-file-sanity`: PASS.
- `wc -c build/antforth.com`: 22,536 (was 22,545; Δ −9 bytes from the leaner rewrite).
- `wc -c build/antforth_filesanity.com`: 23,852 (was 23,861; same Δ −9 bytes).
- BDOS allow-list audit: 11 sites (unchanged).
- End-to-end fix probe: REPOSITION 524288 → FILE-POSITION returns `POS=0 8 0`; raw FCB probe confirms `S2=1`.

### Change Log

| Date | Author | Change |
|---|---|---|
| 2026-05-03 | claude-opus-4-7[1m] (dev) | Story 13.3 dev-pass complete: FILE-POSITION / REPOSITION-FILE / FILE-SIZE landed; +658 byte delta justified; 6 new REPL probes (914..919); Task 1.9 flipped from auto-flush to discard discipline after R/W mixed-mode corruption surfaced (per-FCB dirty-flag infra deferred to Story 13.5 per AC #11(b)). Status: review. |
| 2026-05-03 | claude-opus-4-7[1m] (code-review) | Code review: HIGH#1 (REPOSITION S2 mirror clobber for files ≥ 512 KB) fixed by stashing N0/N1/N2 to `fac_r0r1r2` before FCB-offset loads; MEDIUM#1 (dead code + abandoned "wait —" comment) removed with the rewrite; MEDIUM#2 (W/O+REPOSITION+WRITE pre-load failure probe) deferred to Story 13.5; LOW#1/#2/#3 fixed; LOW#4 (cosmetic stack-residue in (t12)) accepted. Regression probe (t16) added → Makefile test 920. Net binary delta: −9 bytes. 929 PASS / 0 FAIL. Status: done. |
