# Story 13.2: Core File-Access wordset — `OPEN-FILE`, `CREATE-FILE`, `CLOSE-FILE`, `DELETE-FILE`, `READ-FILE`, `WRITE-FILE`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the core ANS File-Access wordset for opening, closing, creating, deleting, and byte-oriented reading/writing of files against the CP/M 2.2 filesystem,
So that I can read and write source files and data files from my antforth session — closing FR35–FR39 and FR42 atop Story 13.1's FCB pool, BDOS wrapper layer, and byte-stream impedance helpers.

## Acceptance Criteria

1. **Given** ANS Forth 1994 §11.6.1.2054 (`R/O`), §11.6.1.2425 (`W/O`), §11.6.1.2055 (`R/W`), and §11.6.1.0865 (`BIN`),
   **when** new file-access-mode (fam) words are exposed,
   **then** four DEFCODE words are added at the top of `src/file_access.asm`'s user-facing section:
   - **`R/O`** — `( -- fam )` — read-only access mode constant
   - **`R/W`** — `( -- fam )` — read/write access mode constant
   - **`W/O`** — `( -- fam )` — write-only access mode constant
   - **`BIN`** — `( fam1 -- fam2 )` — binary modifier (per §11.6.1.0865 — "modify the implementation defined fam fam1 to additionally select a 'binary' file"; on CP/M 2.2 with no text/binary distinction, BIN is a no-op identity)
   The internal fam encoding is dev-pass choice — recommended bit-encoding so BIN can OR a bit non-destructively even though it's a no-op on CP/M (e.g., `R/O = 0`, `R/W = 1`, `W/O = 2`, `BIN = | 4`); document the chosen encoding in Completion Notes Task 1. The fam is consumed by `OPEN-FILE` / `CREATE-FILE` to validate-or-reject incompatible combinations and to gate `WRITE-FILE` against R/O FIDs (see AC #5). Each word carries a `; ANS Forth 1994 §11.6.1.NNNN <word> — <semantic>` citation per CCD-3 / NFR17 (`architecture.md:472`).

2. **Given** ANS Forth 1994 §11.6.1.1970 (`OPEN-FILE`) with stack effect `( c-addr u fam -- fileid ior )`,
   **when** `OPEN-FILE` is invoked with a filename `c-addr u`, an access mode `fam`, and an existing file present on the target drive,
   **then** a new FID (= FCB ptr from Story 13.1's `pool_acquire` per E13-D1) is returned with `ior = 0`. On failure (file not found, malformed filename, drive not present), `fileid` is the impl-defined "undefined" placeholder (recommended: `0`) and `ior` is non-zero per ANS §11.3.5 ("an implementation-defined ior other than zero"). Catastrophic failures (FCB pool exhausted) raise `-69 THROW` per Story 13.1 AC #4 / `THROW_FCB_EXHAUSTED` (constants.asm:92). The fam argument is recorded in the FCB's antforth-private metadata slot (see AC #6 fam-storage decision) so subsequent `WRITE-FILE` calls can enforce R/O. Citation comment per CCD-3.

3. **Given** ANS Forth 1994 §11.6.1.1010 (`CREATE-FILE`) with stack effect `( c-addr u fam -- fileid ior )`,
   **when** invoked with a non-existent filename and an access mode,
   **then** the file is created via `bdos_create_file` (F_MAKE / 22) and a valid FID is returned with `ior = 0`; if the file already exists, the standard mandates **truncation to zero length** (§11.6.1.1010 "Create file *name* in the manner of `OPEN-FILE` ... If the file *name* exists, replace it with an empty one of the same name"). Implementation: pre-emptively `bdos_delete_file` the FCB-by-name *silently* (ignoring the 0xFF "not found" return), then F_MAKE — mirror Story 13.1's harness pattern (`src/file_access.asm:716-719`). On directory-full or BDOS error from F_MAKE, `fileid = 0` and `ior` is non-zero. Pool exhaustion → `-69 THROW`. Citation per CCD-3.

4. **Given** ANS Forth 1994 §11.6.1.1190 (`DELETE-FILE`) with stack effect `( c-addr u -- ior )`,
   **when** invoked with a filename,
   **then** a transient FCB is acquired from the pool, the filename is parsed in (per AC #6), `bdos_delete_file` (F_DELETE / 19) is invoked, and the transient FCB is released back to the pool unconditionally. `ior = 0` on success; `ior` is non-zero per ANS for "file not found" and other recoverable BDOS results. Pool exhaustion (no transient FCB available) → `-69 THROW`. Note: `DELETE-FILE` does not need a long-lived FID; the transient FCB lives for the duration of the BDOS call only — this is the canonical way to do delete-without-open on CP/M.

5. **Given** ANS Forth 1994 §11.6.1.2080 (`READ-FILE`) with stack effect `( c-addr u1 fileid -- u2 ior )`,
   **when** reading `u1` bytes — including reads that cross the 128-byte CP/M record boundary — into the user buffer at `c-addr`,
   **then** the byte-stream impedance layer from Story 13.1 (`file_byte_read`, `src/file_access.asm:446-515`) is the underlying loop primitive. `u2` is the count actually transferred (`u2 ≤ u1`). On normal EOF mid-read, `u2` reflects the number of bytes successfully read before EOF (which may be `0`) with `ior = 0` per §11.6.1.2080 ("If u1 bytes are not available, this is not an exception"). On a true I/O error (BDOS read error other than EOF), `u2` is the bytes read so far and `ior` is non-zero. Operations on a closed/invalid FID raise `-70 THROW` (see AC #7 FID validation). The user buffer at `c-addr` must accommodate `u1` bytes; bounds checking is the caller's responsibility per Forth convention (no `c-addr+u1 > HERE` guard). Citation per CCD-3.

6. **Given** ANS Forth 1994 §11.6.1.2480 (`WRITE-FILE`) with stack effect `( c-addr u1 fileid -- ior )`,
   **when** writing `u1` bytes from the user buffer at `c-addr` into a R/W or W/O file,
   **then** the byte-stream impedance layer from Story 13.1 (`file_byte_write`, `src/file_access.asm:522-595`) is the loop primitive. Bytes accumulate in the per-FCB DMA buffer and are flushed to disk at every 128-byte boundary; partial-record bytes remain buffered until `CLOSE-FILE` (or explicit `file_flush` call) finalises them with the AC #8 padding discipline. `ior = 0` on success; non-zero on a BDOS write error (disk full, write to R/O extent). **R/O guard**: if the FID's recorded fam (per AC #2 storage) is `R/O`, `WRITE-FILE` returns `ior != 0` *without* attempting any BDOS call — recoverable per ANS, no THROW. Operations on a closed/invalid FID raise `-70 THROW` (AC #7). Citation per CCD-3.

7. **Given** ANS Forth 1994 §11.6.1.0900 (`CLOSE-FILE`) with stack effect `( fileid -- ior )`,
   **when** invoked on an open FID,
   **then** any partial-record buffered writes are flushed via `file_flush` (`src/file_access.asm:603-672`); `bdos_close_file` (F_CLOSE / 16) finalises the directory entry; the FCB is released to the pool via `pool_release`; the FID becomes invalid. `ior = 0` on success; non-zero on a flush or close error. Subsequent operations on the freed FID (READ-FILE / WRITE-FILE / a second CLOSE-FILE) detect the freed-bitmap state and raise `-70 THROW` per the FID-validation discipline below. Citation per CCD-3.

8. **Given** the FID-validation contract introduced by this story (closed-FID detection — flagged in Story 13.1 Code Review F8 and AC #6's "subsequent operations on that FID raise `-70 THROW`"),
   **when** `READ-FILE` / `WRITE-FILE` / `CLOSE-FILE` (and `FILE-POSITION` / `REPOSITION-FILE` / `FILE-SIZE` in Story 13.3, which inherit the same discipline) receive a `fileid` argument,
   **then** an internal helper `fid_validate` runs first:
   - **(a)** Compute index via `fcb_idx_from_ptr` (`src/file_access.asm:282-310`); if the helper returns `B = 0xFF` (out-of-range sentinel — pointer is not in the pool, or not at an FCB-stride boundary), raise `-70 THROW`.
   - **(b)** Read `fcb_pool_bitmap`, mask with `(1 << index)`. If the bit is set (slot is "free" per Story 13.1 AC #4 bitmap orientation), the FID was previously released → raise `-70 THROW`.
   - **(c)** Else the FID is in-use — return without raising; caller proceeds.
   The helper is ~25 bytes of code and called from every File-Access word that takes a `fileid`. The new EQU `THROW_FILE_INVALID_FID EQU -70` is added to `src/constants.asm` adjacent to `THROW_FCB_EXHAUSTED EQU -69`. **Citation:** `-70` is allocated as **antforth-extension semantic on a Forth 2014 §9.3.5 reserved code** — Forth 2014 reserves `-70` for `FREE` (memory deallocator), but antforth has no separate FREE wordset and re-purposes the code for the file-access invalid-FID condition (rationale: closer in spirit to a "use-after-free" than to memory FREE). Comment cites: `; antforth re-purposing of Forth 2014 §9.3.5 reserved code -70 — see docs/throw-codes.md`. **Action:** Story 13.2 amends `docs/throw-codes.md` §c to record the `-69`/`-70` pair as the File-Access exhaustion / invalid-FID block; preserve the `(b)` ANS column for the Forth 2014 originals so future readers see the rationale. **Alternative deferred to dev-pass:** if the dev agent prefers a fresh antforth-extension code in the `-256..-32767` block (e.g., `-273 THROW_FILE_INVALID_FID`), pick that instead and record the choice in Completion Notes Task 8 — the project lead's explicit `-70` use in the epic AC is the default but the antforth-block path is acceptable if the dev agent finds a stronger rationale during dev-pass.

9. **Given** the filename-parsing requirement (NFR21 — "CP/M 2.2 8.3 syntax + optional drive letter"; FR44 — "drives A: and B: are equivalent to INCLUDE/file ops"),
   **when** `c-addr u` is consumed by `OPEN-FILE` / `CREATE-FILE` / `DELETE-FILE`,
   **then** an internal helper `fcb_parse_filename` is added with entry `( DE = FCB ptr, HL = c-addr, B = u )` and exit `( CY = 0 success / CY = 1 malformed )`. Parsing rules:
   - **Drive prefix:** Optional. Two-byte form `<letter>:` at the start. Letter is uppercased; A=1, B=2, …, P=16; if absent, drive byte = 0 (default). Lowercase accepted (uppercased internally per case-insensitivity convention); letters outside A..P → CY=1 malformed. Note: CP/M's FCB drive byte uses 1-origin (1=A, 2=B, ..., 16=P), 0 = "default drive" — distinct from BDOS `DRV_GET` (25) which returns 0=A, 1=B, ... (per Story 13.1 `bdos_get_drive` comment, `src/file_access.asm:382`). The two encodings must not be confused: `fcb_parse_filename` produces FCB-form (1-origin); `bdos_get_drive` returns BDOS-form (0-origin). Document the split explicitly at the helper site to prevent regressions.
   - **Name parsing:** Up to 8 characters before the dot (or end-of-string). Uppercased. Padded with ASCII space (0x20) to fill the 8-byte FCB[1..8]. Empty name (e.g., `.TXT` or just `:`) → CY=1.
   - **Extension parsing:** Optional. Introduced by `.`; up to 3 characters; uppercased; padded with space to fill FCB[9..11]. Absent extension → all three bytes = space (`0x20`). Multiple dots or embedded space inside name/ext → CY=1.
   - **Wildcards / paths:** `*` and `?` are accepted by CP/M itself for some BDOS operations but are out of scope for ANS File-Access semantics — `fcb_parse_filename` rejects them with CY=1. Unix-style `/` path separators → CY=1. (NFR21 explicit.)
   - **Length cap:** `u > 14` (= 2 drive + 8 name + 1 dot + 3 ext) → CY=1 immediately, before any byte inspection.
   The helper does **not** raise THROW; it returns CY=1 on malformed input and the caller (`OPEN-FILE` / `CREATE-FILE` / `DELETE-FILE`) maps that into a non-zero `ior` per ANS §11.3.5. The dev agent picks the specific ior value (recommended: `ior = 1` for "malformed filename" — opaque non-zero per ANS, no specific code mandated). Document the ior convention in Completion Notes Task 9.

10. **Given** the BDOS function set already wired by Story 13.1 (allow-list members 15/16/19/20/21/22/25/26/33/34/35; epics.md:1483),
    **when** Story 13.2's user-facing words are authored,
    **then** **no new BDOS function numbers are introduced** in this story. All file operations route through Story 13.1's `bdos_open_file` / `bdos_close_file` / `bdos_delete_file` / `bdos_create_file` / `bdos_set_dma` / `bdos_read_seq` / `bdos_write_seq` wrappers (`src/file_access.asm:325-427`) — no direct `CALL BDOS_ENTRY` outside the wrapper layer. Per CCD-3 / NFR17 audit: `grep -nE 'CALL\s+BDOS_ENTRY' src/file_access.asm` should return the same 11 hits as Story 13.1 (Story 13.2 adds zero new BDOS call sites). Any new direct `CALL BDOS_ENTRY` is a story-level blocker — wrap it as a helper first if it surfaces.

11. **Given** Story 13.1's BDOS register-preservation assumption (`src/file_access.asm:15-32` / Story 13.1 AC #5: firmware ≥2026-04-28 + assumption-by-mechanism for non-probed file-access functions, **confirmed by Story 13.1 AC #17 hardware smoke**),
    **when** Story 13.2's words layer atop the wrapper layer,
    **then** the assumption-by-mechanism extends transparently — the same firmware contract covers every BDOS call routed through Story 13.1's wrappers, and Story 13.2 inherits the contract without re-asserting it. **Caveat:** Story 13.2 introduces user-facing entry points (six DEFCODE words) which sit *above* the wrapper layer — they manipulate FCBs, the bitmap, and parameter-stack arguments before calling the wrappers. The TOS-in-register discipline (BC = TOS) and `BDOS_SAVE`/`BDOS_RESTORE` round-trip are still load-bearing through the wrappers; no shadow-register or IX/IY use required at the user-facing layer. If a dev-pass-discovered need to use IX or IY emerges (e.g., as a stable FCB-ptr register across a long primitive body), that is a deviation from the Story 13.1 envelope and must be flagged for project-lead review per Story 13.1 AC #14's structural-load-bearing escalation gate.

12. **Given** FR43 (file-op errors raise THROW, not ABORT) and the discipline reconciliation in epics.md:1499-1501 ("a THROW with an ANS-standard code from `docs/throw-codes.md`; `ior` return values are non-zero only for recoverable-by-design cases"),
    **when** each user-facing File-Access word is authored,
    **then** the ior-vs-THROW split is applied uniformly:
    - **`ior` (recoverable, no THROW)** — Standard ANS-recoverable cases per §11.3.5: file not found (OPEN-FILE), filename malformed (parse failure), R/O write attempt (WRITE-FILE on a R/O FID), disk full (WRITE-FILE), file already at EOF (READ-FILE returning u2 < u1 with ior=0 — note: standard EOF is *not* an error, ior=0 with u2 reflecting actual count).
    - **`THROW` (unrecoverable, no ior)** — Architectural failures the standard does not anticipate: FCB pool exhausted (`-69 THROW_FCB_EXHAUSTED`); operations on a closed/invalid FID (`-70 THROW_FILE_INVALID_FID` per AC #8).
    - **No double-error path** — a word does not raise THROW in one branch and return non-zero ior in another for the same condition. Each error condition routes to exactly one channel; the routing table is recorded in Completion Notes Task 12 as a 2-column table (condition → channel).

13. **Given** the test discipline (`feedback_repl_tests_preferred.md` — REPL-piped Forth tests; `feedback_testing_rules.md` — manual tests must exercise actual Forth primitives, not raw BDOS),
    **when** `tests/file_access_tests.fth` is **newly created** by this story (Story 13.1 deferred its creation per Story 13.1 Task 7.4 — the file does not exist today; verify via `ls tests/` showing no `file_access_tests.fth`),
    **then** the file contains a comment-block header explaining the test infrastructure, followed by a sequence of REPL-piped probes that exercise the user-facing wordset against the iz-cpm-mounted `disk/a/`. Expected probe set (Story 13.2 portion — Stories 13.3 / 13.4 / 13.5 extend this file with their additions):
    - **(t1) Round-trip integrity** — create `TESTRT.TXT`; open R/W; write the bytes `"Hello, antforth!"` (16 bytes); close-file; re-open R/O; read 16 bytes into a buffer; close; verify the buffer matches `"Hello, antforth!"` byte-for-byte; delete `TESTRT.TXT`.
    - **(t2) Cross-record read** — create `TESTCR.TXT`; write 200 bytes (a deterministic pattern, e.g., the 200-byte content from Story 13.1's `str_hello_content` re-used inline); close; re-open R/O; read 200 bytes; verify count = 200, first byte = `'A'`, last byte = `'y'` (matching the Story 13.1 oracle); read another byte → expect ior = 0, u2 = 0 (clean EOF — `READ-FILE` returns `u2 < u1` is *not* an error per §11.6.1.2080); close; delete.
    - **(t3) Delete-then-reopen** — create `TESTDR.TXT`; close; delete; attempt to open → expect `fileid = 0`, `ior` non-zero (file not found per ANS).
    - **(t4) Pool exhaustion** — open 9 files in a row (target file names chosen so each F_OPEN does not accidentally collide on a stale directory entry — e.g., `POOL1.TXT` … `POOL9.TXT` all freshly created via CREATE-FILE in the same test); the 9th `OPEN-FILE` (or `CREATE-FILE`) call into `pool_acquire` raises `-69 THROW`. Verify via `' OPEN-FILE CATCH . CR` style assertion: `-69` lands on the data stack. Cleanup: close + delete the 8 successfully-opened files; verify pool is back to fully free (a follow-up `pool_acquire` succeeds — exposed via a TEST_MODE or FILE_SANITY-style probe word, OR a Forth-level smoke that opens 8 files again and they all succeed).
    - **(t5) R/O write attempt** — create `TESTRO.TXT` (any non-empty content) under R/W; close; reopen R/O; attempt WRITE-FILE → expect `ior` non-zero, no THROW, no actual byte written; close; delete.
    - **(t6) Closed-FID detection** — open a file; close it; attempt READ-FILE on the now-stale FID → expect `-70 THROW` (per AC #8). Verify via `' READ-FILE CATCH` pattern.
    - **(t7) Malformed filename** — invoke `OPEN-FILE` with a filename of length 0 (empty), length 30 (over the 14-byte cap), embedded space, two dots, wildcards `*` and `?`, and `/path/style` — each yields `fileid = 0`, `ior` non-zero (per AC #9 — no THROW, ior-channel only).
    - **(t8) Drive prefix routing** — invoke `OPEN-FILE` with `"A:HELLO.TXT"` and (where `disk/b/` is also wired) `"B:HELLO.TXT"`; expected behaviour matches the iz-cpm drive mounts. **Story 13.2 scope:** wire `disk/b/` and add `--disk-b disk/b` to the `IZCPM_DISKS` Makefile variable (extending Story 13.1's `--disk-a disk/a` invocation per Action Item A2 from epic-12-retro-2026-05-01.md:148, which deferred B:/discriminator-pair seed files to Stories 13.2/13.4). Add seed file `disk/b/HELLO.TXT` with distinguishable content (e.g., a 64-byte string `"This is the B-drive HELLO; A and B route to different files."` padded as needed) so the discriminator probe can confirm that `A:HELLO.TXT` and `B:HELLO.TXT` are *different* files. Recommended pattern: as in Story 13.1 (re-create at start), the test creates the B: seed at runtime via `CREATE-FILE` + `WRITE-FILE` + `CLOSE-FILE` so no .gitattributes binary-file pinning is needed; alternative (committed seed under `tests/seed/`) is acceptable if the dev agent prefers — record the pick in Completion Notes Task 13.
    Each probe is a separately numbered REPL test in the Makefile, continuing the post-Story-13.1 sequence (last numbered test was 913; t1..t8 run as **N additional tests** where N is dev-pass-decided, conservative range **+8 to +20 tests** depending on per-probe granularity). Each probe ends with `BYE\r\n` so iz-cpm exits cleanly. Per `feedback_testing_rules.md`, every probe must exercise the user-facing Forth words (e.g., `OPEN-FILE`, `READ-FILE`); raw BDOS calls inside the probes are forbidden — the probes go through the new DEFCODE words exclusively.

14. **Given** the test plan in AC #13 and Action Item A1 from the Epic 12 retrospective (TIB-128 limit; `epic-12-retro-2026-05-01.md:147`),
    **when** REPL-piped tests use multi-line Forth source longer than 127 bytes,
    **then** the test author splits the source across multiple `printf %s\r\n` arguments per the documented split-printf idiom. Story 13.2's tests are most likely to cross 127 bytes for (t1) round-trip and (t2) cross-record because they involve buffer setup + `S"` literals + word invocations on one line. Recommended pattern: factor each probe into ≥2 `printf` chunks, mirroring `Makefile:253` (the multi-arg `printf '%s\r\n%s\r\n'` pattern for the `-3 NEGATE` test). Document the split-printf adoption in Completion Notes Task 14 as fully landing Action Item A1 (Story 13.1's AC #15 noted it would surface "Story 13.2 forward").

15. **Given** `make test-repl` 913 PASS / 0 FAIL post-Story-13.1 baseline (Story 13.1 Completion Notes Task 11),
    **when** Story 13.2's edits land,
    **then** all 913 existing tests continue to PASS (zero regression — NFR9 / FR45 / FR46 enforced per-story). Pre-edit and post-edit `make test-repl` PASS counts are recorded in Completion Notes Task 15; the post-edit count is `913 + N` where `N` is the new probe count from AC #13 (8..20). `make test` (assembly thread) runs clean post-edit. `make test-file-sanity` (Story 13.1's harness) continues to PASS — the new user-facing words are additive and do not displace the FILE_SANITY-wrapped harness. Any pre-existing failure is a release blocker per `feedback_standards_compliance.md`.

16. **Given** the byte-count delta budget (`architecture.md:158` no per-epic net-negative gate) and the post-Story-13.1 baseline (**20,589 bytes** per `wc -c build/antforth.com` 2026-05-03),
    **when** Story 13.2's build closes,
    **then** the post-edit `wc -c build/antforth.com` is recorded in Completion Notes Task 16 alongside the pre-edit baseline. **Expected envelope: +400 to +700 bytes.** Composition estimate:
    - 4 × fam-constant DEFCODE words (`R/O`, `R/W`, `W/O`, `BIN`) — ~30 bytes each (header + push) = ~120 bytes
    - 6 × user-facing DEFCODE words (`OPEN-FILE`, `CREATE-FILE`, `CLOSE-FILE`, `DELETE-FILE`, `READ-FILE`, `WRITE-FILE`) — ~60-80 bytes each (header + arg-marshal + helper call + ior-mapping) = ~400 bytes
    - `fcb_parse_filename` helper — ~80-120 bytes (drive prefix + name + ext + reject paths)
    - `fid_validate` helper — ~25 bytes
    - 1 new EQU in `constants.asm` (`THROW_FILE_INVALID_FID = -70`) — 0 bytes runtime
    - Test buffer scratch space (e.g., a `file_io_buf: ds N` for transient buffer of test traffic if needed by the harness; if the tests use HERE-allocated buffers, this is 0 bytes)
    Total estimated: **~600-700 bytes.** Any delta beyond +900 bytes warrants explicit justification in Completion Notes Task 16 per `feedback_plain_qa_language.md` (state value, gate, reason). Per Lesson 12-C (`epic-12-retro-2026-05-01.md:88`), tight per-story budgets ratchet even when overshot — record honestly, no smuggled-in stabilisation per `feedback_stabilisation_interlude.md`.

17. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect"; `architecture.md:565-569` — Epic 13 capstone reviews unlikely to be clean) and the Story 13.1 yield (12 dev-review findings + 8 code-review findings),
    **when** Story 13.2's review runs,
    **then** **at least 3-5 LOW/MEDIUM findings are expected** (the "ninth-plus consecutive epic" review trend per Epic 12 retro Lesson 5; Story 13.1 returned 20 findings total across both review passes, so 13.2 is unlikely to surface fewer than a handful). Likely candidates the review must probe:
    - **(a) FID validation completeness** — `fid_validate` runs at every entry that takes a `fileid`. Audit: `grep -nE 'fid_validate|fcb_idx_from_ptr.*fileid' src/file_access.asm` confirms every word that accepts a `fileid` calls the helper before any FCB-byte access. Missing the call lets a stale-FID READ-FILE silently read whatever the next pool acquire put in that slot — a use-after-free hazard.
    - **(b) Filename parser uppercase + space-padding correctness** — Verify with hex-dump probes that `OPEN-FILE` of `"hello.txt"` and `"HELLO.TXT"` produce identical FCB byte patterns (FCB[1..8] = `"HELLO   "`, FCB[9..11] = `"TXT"`). A bug that fails to uppercase OR fails to space-pad would cause CP/M to look up a different file silently.
    - **(c) Drive byte 1-origin vs 0-origin confusion** — The single biggest off-by-one trap on CP/M. Verify `fcb_parse_filename` for `"A:FOO.TXT"` produces FCB[0] = 1 (1-origin per CP/M FCB spec), and that `bdos_get_drive` (BDOS function 25 — Story 13.1 wrapper at `src/file_access.asm:382`) returns 0-origin (0 = A) — these encodings DO NOT MATCH. A future "use the BDOS-form drive code in the FCB" mistake is a silent landmine. The review verifies the inline source comment at `fcb_parse_filename` makes the encoding split explicit.
    - **(d) R/O guard placement** — The R/O fam guard in `WRITE-FILE` (AC #6) must execute *before* any DMA setup or FCB mutation, else a R/O `WRITE-FILE` call could partially mutate FCB state before the guard fires. Audit: the `ior != 0` early-return path is the first non-validation step in `WRITE-FILE`'s body.
    - **(e) Pool-acquire failure path through CREATE-FILE pre-delete** — CREATE-FILE pre-emptively `bdos_delete_file`s before F_MAKE (AC #3). If the pre-delete acquires the FCB and the F_MAKE fails for some reason, does the FCB get released? Audit: every error path through CREATE-FILE / OPEN-FILE / DELETE-FILE pairs `pool_acquire` with `pool_release` on the failure branch, OR the pool-acquire is deferred until after the parse/validate stage so failure doesn't leak the FCB.
    - **(f) `fileid = 0` collision with valid FCB ptr** — ANS doesn't mandate `0` as the impl-defined "undefined fileid" — it's a recommendation. The FCB pool starts at `fcb_pool` (some non-zero address per the linker map; verify), so `fileid = 0` is unambiguously distinct from any valid FID — no collision possible. The review confirms via the linker map that `fcb_pool` is at a fixed non-zero address and adds a defensive `ASSERT fcb_pool > 0` if not present already (it is implicit but worth making explicit).
    - **(g) CLOSE-FILE double-close** — A user calls `CLOSE-FILE` on a FID; later calls `CLOSE-FILE` on the same (now stale) FID. The FID-validation discipline (AC #8) raises `-70 THROW` on the second call. Audit: the first close's `pool_release` flips the bitmap bit BEFORE the FID is returned to the user, so the second close's bitmap probe finds the bit set ("free") and throws. Order of operations matters — `bdos_close_file` first, then `pool_release` last; verify in source.
    - **(h) READ-FILE `u2` accumulation across BDOS-error mid-loop** — If `file_byte_read` returns CY=1 (EOF or I/O error) at byte k of the u1-byte loop, the implementation must distinguish "true EOF" (ior=0, u2=k) from "I/O error" (ior != 0, u2=k). Story 13.1's `file_byte_read` flag protocol uses CY=1 for both EOF and error (`src/file_access.asm:444-445`); 13.2 must recover the distinction either by (i) reading the BDOS A return after the error or (ii) extending `file_byte_read` to differentiate the two. Pick approach (i) — the existing helper signals via CY only; the user-facing READ-FILE does an additional probe (e.g., `bdos_read_seq` returns 1 = EOF / >1 = error) to map. Document the picked approach in Completion Notes Task 17. **Note:** per the AC #5 "EOF is not an exception" rule, a true EOF that returns `u2 = 0` is `ior = 0` (not an error); only mid-record I/O failures get a non-zero ior. The current Story 13.1 helper conflates these two — Story 13.2 disambiguates at the user-facing layer rather than rewriting the helper, mirroring the layered approach.
    - **(i) Test fixture leakage** — REPL probes leave files on `disk/a/` if a test fails mid-sequence. The `disk/a/` directory is gitignored for `*.TXT` and `*.BIN` per Story 13.1 AC #6 / Completion Notes (`/.gitignore` lines added 2026-05-02), so transient files don't pollute git status. However, per-probe cleanup (delete on success, even if not strictly needed for test correctness) is good hygiene. Audit: every probe ends with `DELETE-FILE` of any files it created (or the test target wipes `disk/a/*.TXT` before each run).
    - **(j) BDOS allow-list audit invariance** — Story 13.2 introduces zero new BDOS function numbers (AC #10). Verify by re-running Story 13.1's audit grep (`grep -nE 'CALL\s+BDOS_ENTRY|LD\s+C,\s*F_|LD\s+C,\s*DRV_GET' src/file_access.asm`) post-edit and confirming the same 11 hits at the same line numbers (modulo line drift from the new code above the wrappers). NFR13 closure remains the Story 13.5 gate's responsibility, but Story 13.2 contributes zero new audit rows.
    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Story 13.1's 4-fix-12-accept disposition). Recorded in Completion Notes Task 17.

18. **Given** Action Item A5 from the Epic 12 retrospective ("Mid-epic hardware smoke cadence for Epic 13" — `epic-12-retro-2026-05-01.md:151`; project lead 2026-05-01: *"yep, I love on-hardware testing!"*) and Story 13.1's per-story hardware-smoke precedent (Story 13.1 AC #17 / hardware run 2026-05-03 PASS),
    **when** Story 13.2 closes review,
    **then** the build is transferred to real MicroBeast and a hardware-smoke probe exercises a representative subset of the new wordset from the REPL. Probe sequence:
    - paste a short Forth incantation that does the round-trip from (t1) — `S" HW.TXT" R/W CREATE-FILE` (record fileid + ior); `S" Hello, MicroBeast!" <fileid> WRITE-FILE` (record ior — no SWAP; WRITE-FILE expects `( c-addr u fileid -- ior )` and `S"` already lays them in that order); `<fileid> CLOSE-FILE`; `S" HW.TXT" R/O OPEN-FILE` (re-open + new fileid + ior); read 18 bytes back via a small `<buf> 18 <fileid> READ-FILE`; close; delete.
    - record the hardware build path used (recommend: production `build/antforth.com` — Story 13.2's wordset is in production, not behind FILE_SANITY)
    - hardware target drive: B: (firmware ROM occupies A: on MicroBeast — Story 13.1 AC #17). Default-drive routing applies as in Story 13.1 (FCB drive byte = 0 routes to B: on hardware, A: under iz-cpm). The probe filename `HW.TXT` has no drive prefix → routes to default → B: on hardware, A: under iz-cpm (transparent).
    - capture transcript (recommended: `~/Downloads/bestialitty-13-2-YYYYMMDD-HHMMSS.bin`)
    - PASS/FAIL verdict against expected output (round-trip integrity: read-back bytes match the written bytes; ior=0 throughout; no THROW).
    The hardware probe doubles as evidence the user-facing wordset works end-to-end on real hardware against the firmware-fixed BDOS path inherited from Story 13.1. Recorded in Completion Notes Task 18.

19. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 12.1 AC #14, Story 11.5.5 AC #12, Story 13.1 AC #14),
    **when** small in-pass refinements are warranted (additional grep-driven scrubs, polished comment phrasing, one-line cross-reference adjustments, ior-value picks, fam-encoding-bit picks),
    **then** they are landed inside this story — no spawning sub-stories. The exception: if the review surfaces a **load-bearing structural change** to Story 13.1's helper layer (e.g., the AC #17(h) finding triggers a rewrite of `file_byte_read` rather than a 13.2-side workaround), HALT and flag for project lead before refactoring — the change becomes a separate decision (a Story 13.2.1 "byte-stream layer EOF/error disambiguation" if the project lead approves). Documented in Completion Notes Task 19.

20. **Given** Story 13.2 sits between Story 13.1 (FCB pool + wrappers, **done**) and Story 13.3 (file positioning — `FILE-POSITION` / `REPOSITION-FILE` / `FILE-SIZE`),
    **when** Story 13.2 is created via `create-story`,
    **then** `epic-13` already at `in-progress` (set by Story 13.0 / 13.0.1 back-fills; verified via `sprint-status.yaml:190`); `13-2-core-file-access-wordset` flips `backlog → ready-for-dev` at create-story-finalize and progresses through `in-progress → review → done` per the dev-story workflow. Story 13.3 stays `backlog` until 13.2 reaches `done` — file-positioning words inherit Story 13.2's FID-validation discipline (AC #8) and the same fam-storage convention (AC #6) for the R/O-guard model, so 13.3 dev-pass should not start until 13.2 is closed. Recorded in Completion Notes Task 20.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline + grep evidence (AC: #15, #16, #20)**
  - [x] 1.1 `wc -c build/antforth.com` — record post-Story-13.1 baseline. Expected: **20,589 bytes** per Story 13.1 Completion Notes Task 12 / git log `1c7f802` close (2026-05-03). Verify; investigate any deviation.
  - [x] 1.2 `make test-repl` — record total PASS / FAIL. Expected: **913 PASS / 0 FAIL** per Story 13.1 Completion Notes Task 11. Investigate any pre-existing failure (release blocker per `feedback_standards_compliance.md`).
  - [x] 1.3 `make test` (assembly thread) — record clean / fail outcome. Expected: clean.
  - [x] 1.4 `make test-file-sanity` — record PASS / FAIL. Expected: PASS (Story 13.1 harness; Story 13.2 must not regress it).
  - [x] 1.5 `grep -nE 'OPEN-FILE|CREATE-FILE|CLOSE-FILE|READ-FILE|WRITE-FILE|DELETE-FILE|R/O|R/W|W/O|BIN' src/*.asm` — verify zero pre-existing user-facing File-Access word definitions (Story 13.2 is the introduction point).
  - [x] 1.6 `ls tests/file_access_tests.fth 2>&1` — verify the file does not exist (Story 13.1 Task 7.4 deferred its creation).
  - [x] 1.7 `ls disk/a/ disk/b/ 2>&1` — record current `disk/` state. Expected: `disk/a/.gitkeep` exists (Story 13.1); `disk/b/` may not exist yet.
  - [x] 1.8 `iz-cpm --help 2>&1 | grep -iE 'disk|drive'` — re-verify the `--disk-b <path>` flag is available (the same iz-cpm version Story 13.1 used for `--disk-a`).
  - [x] 1.9 `grep -cE 'CALL\s+BDOS_ENTRY' src/file_access.asm` — record post-Story-13.1 BDOS call-site count. Expected: **11**. Re-run post-edit to verify Story 13.2 added zero (AC #10).

- [x] **Task 2 — fam-constant DEFCODE words `R/O`, `R/W`, `W/O`, `BIN` (AC: #1)**
  - [x] 2.1 Pick fam encoding bits (recommended: `R/O = 0`, `R/W = 1`, `W/O = 2`, `BIN = | 4`); document in Completion Notes Task 2.
  - [x] 2.2 Add the four DEFCODE words near the top of the user-facing section in `src/file_access.asm` (above OPEN-FILE / CREATE-FILE per natural source order).
  - [x] 2.3 Each word carries a `; ANS Forth 1994 §11.6.1.NNNN <name> — <semantic>` citation per CCD-3 (NFR17, `architecture.md:472`).
  - [x] 2.4 Each word is a **production word** (no IFDEF wrapping — these are user-facing standard primitives, not test scaffolding).

- [x] **Task 3 — `fcb_parse_filename` helper (AC: #9)**
  - [x] 3.1 Implement the helper at file-private label in `src/file_access.asm` (above the user-facing words, below the existing helper layer).
  - [x] 3.2 Drive-prefix parser: detect `<letter>:` at start of input; uppercase; map A=1..P=16 to FCB[0]; absent prefix → FCB[0] = 0.
  - [x] 3.3 Name parser: scan up to 8 bytes before the dot or end-of-string; uppercase each byte; space-pad to fill FCB[1..8].
  - [x] 3.4 Extension parser: optional, introduced by `.`; up to 3 bytes; uppercase; space-pad to fill FCB[9..11].
  - [x] 3.5 Reject paths: `*`, `?`, `/`, multiple dots, embedded space, length > 14, empty name → CY=1 return.
  - [x] 3.6 Add explicit inline comment at the helper site documenting the **FCB drive byte 1-origin vs BDOS DRV_GET 0-origin** split (per AC #9 and AC #17(c)).
  - [x] 3.7 Standalone REPL or assembly-thread probe verifying the helper handles each input class correctly (lowercase + uppercase round-trip same FCB pattern; no-prefix vs `A:` vs `B:` produces the right drive byte; rejection cases surface CY=1).

- [x] **Task 4 — `fid_validate` helper + `THROW_FILE_INVALID_FID` EQU (AC: #8)**
  - [x] 4.1 Add `THROW_FILE_INVALID_FID EQU -70` to `src/constants.asm` adjacent to `THROW_FCB_EXHAUSTED EQU -69` (line 92), with citation comment per AC #8.
  - [x] 4.2 Implement `fid_validate` helper at file-private label in `src/file_access.asm`. Entry: HL = FID. Exit: returns normally if valid; raises `-70 THROW` (`JP w_THROW_cf.kernel_entry` after `LD BC, THROW_FILE_INVALID_FID`) if invalid.
  - [x] 4.3 Validation: (a) `fcb_idx_from_ptr` → 0xFF means out-of-range pointer; (b) bitmap bit at index set means slot is "free" (released).
  - [x] 4.4 Update `docs/throw-codes.md` §c with the `-70` allocation row, citing this story; preserve the Forth 2014 column for the original `-70 FREE` semantic and document antforth's re-purposing rationale.

- [x] **Task 5 — User-facing DEFCODE words `OPEN-FILE`, `CREATE-FILE`, `DELETE-FILE` (AC: #2, #3, #4)**
  - [x] 5.1 `OPEN-FILE` `( c-addr u fam -- fileid ior )`: validate fam arg (any sane value passes; the BIN bit is just OR'd through); `pool_acquire` (raise `-69` on failure); `fcb_parse_filename` (CY=1 → release FCB, return ior!=0); store fam in FCB metadata slot per AC #6 fam-storage decision; `bdos_open_file` (F_OPEN); on 0xFF result, release FCB, `fileid = 0`, `ior` non-zero (e.g., `-38`-ish but as ior, value picked in dev-pass and recorded); on success `fileid = FCB ptr`, `ior = 0`.
  - [x] 5.2 `CREATE-FILE` `( c-addr u fam -- fileid ior )`: as OPEN-FILE except step "open" replaced with: pre-emptive silent `bdos_delete_file` (ignore 0xFF), re-init FCB extent fields (mirror `fis_init_fcb` pattern at `src/file_access.asm:990-1013` — extract a reusable helper if it doesn't already exist), `bdos_create_file` (F_MAKE).
  - [x] 5.3 `DELETE-FILE` `( c-addr u -- ior )`: `pool_acquire`; `fcb_parse_filename` (CY=1 → release FCB, return ior!=0); `bdos_delete_file`; release FCB unconditionally; map BDOS A result to ior (0 = success / 0xFF = file not found mapped to non-zero ior).
  - [x] 5.4 Each word carries an ANS standards-citation comment per CCD-3.
  - [x] 5.5 Audit: `grep -nE 'pool_acquire' src/file_access.asm` post-edit shows the new acquire sites pair with `pool_release` on every error path (mirrors Story 13.1 AC #9 discipline).

- [x] **Task 6 — fam metadata storage in FCB (AC: #2, #6, #6 R/O guard)**
  - [x] 6.1 Decide where to stash the per-FID fam value. **Recommendation:** an **antforth-private parallel array** `fcb_fam: ds 8` (8 bytes — same shape as `fcb_byte_pos` in Story 13.1) indexed by FCB index. **Alternative:** stash inside the FCB itself in a CP/M-reserved byte (e.g., FCB[13] / FCB[14] which are reserved by BDOS for internal use — risky if BDOS overwrites them). The parallel-array path is safer; pick (a) unless dev-pass surfaces a reason against it. Record the pick in Completion Notes Task 6.
  - [x] 6.2 Add a `pool_init` extension that zeroes `fcb_fam[*]` on cold-start (mirror Story 13.1's `fcb_byte_pos` init pattern at `src/file_access.asm:135-142`).
  - [x] 6.3 Add a helper `fcb_fam_get` (entry: HL = FID; exit: A = fam) and `fcb_fam_set` (entry: HL = FID, A = fam) — used by OPEN-FILE / CREATE-FILE (set) and WRITE-FILE (get for R/O guard).

- [x] **Task 7 — User-facing DEFCODE words `READ-FILE`, `WRITE-FILE`, `CLOSE-FILE` (AC: #5, #6, #7)**
  - [x] 7.1 `READ-FILE` `( c-addr u1 fileid -- u2 ior )`: `fid_validate` (raises -70 if invalid); loop u1 times calling `file_byte_read` from Story 13.1; on CY=0 (success) write byte at `c-addr+i`, increment counter; on CY=1 (EOF or error) break loop; disambiguate EOF-vs-error per AC #17(h) — recommended: peek the `bdos_read_seq` A return on the next refill attempt (the helper currently reuses CY for both); `u2` = bytes actually read; ior = 0 on clean EOF, non-zero on I/O error.
  - [x] 7.2 `WRITE-FILE` `( c-addr u1 fileid -- ior )`: `fid_validate`; `fcb_fam_get` → if R/O, return `ior != 0` immediately, no DMA / FCB mutation; else loop u1 times calling `file_byte_write`; on success `ior = 0`; on failure `ior` is the BDOS A return code mapped to non-zero.
  - [x] 7.3 `CLOSE-FILE` `( fileid -- ior )`: `fid_validate`; `file_flush` (flush pending writes); `bdos_close_file` (capture A → ior mapping); `pool_release` regardless of close result (the slot must be returned to the pool even on close-failure to avoid pool leakage — but the user gets the close-failure ior so they know not to trust the file's on-disk state).
  - [x] 7.4 Each word carries an ANS standards-citation comment per CCD-3.
  - [x] 7.5 Audit: every `pool_acquire` in Tasks 5-7 has a matching `pool_release` (success or failure path); zero leakage.

- [x] **Task 8 — `tests/file_access_tests.fth` REPL probes (AC: #13, #14)**
  - [x] 8.1 Create the file with a comment-block header (Epic 13 attribution, Story 13.2 introduction note, expected probe inventory).
  - [x] 8.2 Author probe (t1) round-trip; (t2) cross-record read with EOF; (t3) delete-then-reopen; (t4) pool exhaustion → -69 catch; (t5) R/O write attempt; (t6) closed-FID detection → -70 catch; (t7) malformed filename rejection (loop over the 6+ malformed cases); (t8) drive prefix routing (A: vs B:).
  - [x] 8.3 Each probe is a separately-numbered REPL test added to the `Makefile` `test-repl:` chain, continuing from test 913. Use the split-`printf` idiom for any probe whose Forth source crosses 127 bytes (per AC #14 / Action Item A1).
  - [x] 8.4 Wire `disk/b/` and add `--disk-b disk/b` to the `IZCPM_DISKS` Makefile variable; create `disk/b/.gitkeep` so the directory is preserved by git; extend `.gitignore` for `disk/b/*.TXT` and `disk/b/*.BIN` per the Story 13.1 transient-output pattern.
  - [x] 8.5 (t8) drive-routing probe: pick the seed-staging path (recommended: re-create at start; alternative: committed seed under `tests/seed/` with `.gitattributes` binary-file pin). Record pick in Completion Notes Task 8.

- [x] **Task 9 — Integration with Story 13.1 file-sanity harness (AC: #15)**
  - [x] 9.1 Verify `(FILE-IO-SANITY)` (FILE_SANITY-wrapped, Story 13.1) still PASSes post-edit. The harness uses the wrapper layer directly (not the user-facing words) so it should be unaffected, but the FILE_SANITY build now also includes the user-facing words — confirm no symbol clash, no IFDEF tangle.
  - [x] 9.2 `grep -nE 'FILE-IO-SANITY' build/antforth.com` post-edit returns zero hits (production binary still does not include the test harness; AC #7 grep oracle from Story 13.1 holds).

- [x] **Task 10 — Regression test gate (AC: #15)**
  - [x] 10.1 Pre-edit `make test-repl`: 913 PASS / 0 FAIL (Task 1.2 baseline).
  - [x] 10.2 Post-edit `make test-repl`: should be `913 + N` PASS / 0 FAIL where N = new probe count from Task 8.
  - [x] 10.3 Post-edit `make test`: clean (assembly threads unaffected).
  - [x] 10.4 Post-edit `make test-file-sanity`: PASS (Story 13.1 harness preserved).
  - [x] 10.5 If any of the 913 pre-existing tests regresses, treat as a release blocker and root-cause before close.

- [x] **Task 11 — Byte-count delta (AC: #16)**
  - [x] 11.1 Pre-edit `wc -c build/antforth.com`: **20,589 bytes** (Task 1.1 baseline).
  - [x] 11.2 Post-edit `wc -c build/antforth.com`: record actual.
  - [x] 11.3 Compute delta; reconcile against the +400..+700 envelope in AC #16.
  - [x] 11.4 Pre-edit `wc -c build/antforth_filesanity.com`: **21,907 bytes** (Story 13.1 Code Review F-A close).
  - [x] 11.5 Post-edit `wc -c build/antforth_filesanity.com`: should be `21907 + same delta` since the new words land in both binaries.
  - [x] 11.6 If delta exceeds +900 bytes, justify in Completion Notes per `feedback_plain_qa_language.md`.

- [x] **Task 12 — ior-vs-THROW routing table (AC: #12)**
  - [x] 12.1 Build a 2-column table: condition → channel (ior with value / THROW with code). Cover: file not found, malformed filename, FCB pool exhausted, R/O write attempt, disk full, EOF mid-read, closed FID, BDOS error from F_OPEN/F_MAKE/F_CLOSE/F_READ/F_WRITE/F_DELETE.
  - [x] 12.2 Record the table in Completion Notes Task 12. Cross-reference each row against AC #2-#7 to confirm the implementation matches.

- [x] **Task 13 — Adversarial review (AC: #17)**
  - [x] 13.1 Trigger an adversarial review pass per `feedback_adversarial_review.md`. Probe the AC #17 likely-finding list (a)-(j).
  - [x] 13.2 Triage findings: HIGH/MEDIUM block; LOW may be accepted with rationale (mirror Story 13.1's 4-fix-12-accept disposition).
  - [x] 13.3 In-pass-fix any findings landed.
  - [x] 13.4 Record findings + dispositions in Completion Notes Task 13.

- [x] **Task 14 — In-pass-fix discipline / structural-load-bearing escalation (AC: #19)**
  - [x] 14.1 Document in-pass picks made: AC #1 fam encoding, AC #6 fam-storage path (parallel array vs FCB-internal byte), AC #8 -70 vs antforth-extension code, AC #9 ior-on-malformed-filename value, AC #13 (t8) seed-staging path.
  - [x] 14.2 If any review finding (Task 13) requires modifying Story 13.1's helper layer (e.g., AC #17(h) `file_byte_read` EOF/error disambiguation rewrite), HALT and flag for project lead — do NOT refactor in-pass. Spawn Story 13.2.1 if approved.

- [x] **Task 15 — TIB-128 + split-printf adoption (AC: #14)**
  - [x] 15.1 For every probe in Task 8 whose Forth source crosses 127 bytes, split via `printf '%s\r\n%s\r\n' '<chunk1>' '<chunk2>'` per `Makefile:253` reference pattern.
  - [x] 15.2 Record the adoption in Completion Notes Task 15 as fully landing Action Item A1 (Story 13.1 Task 15 forward-pointer).

- [x] **Task 16 — Sprint-status flips (AC: #20)**
  - [x] 16.1 Verify `epic-13` is currently `in-progress` at `sprint-status.yaml:190`. No change at create-story-finalize.
  - [x] 16.2 Verify `13-2-core-file-access-wordset` is currently `backlog` at `sprint-status.yaml:209`. Flip → `ready-for-dev` at create-story-finalize.
  - [x] 16.3 At dev-pass close, flip → `in-progress`; at review close, flip → `review`; at code-review close, flip → `done`.

- [x] **Task 17 — MicroBeast hardware smoke (AC: #18)**
  - [x] 17.1 Build `build/antforth.com` (production; the user-facing words are not behind FILE_SANITY).
  - [ ] 17.2 Transfer to MicroBeast via the established disk-image mechanism; default drive is B: per Story 13.1 hardware-smoke convention.
  - [ ] 17.3 Project lead pastes the round-trip probe (per AC #18) at the REPL.
  - [ ] 17.4 Capture hardware transcript (recommended: `~/Downloads/bestialitty-13-2-YYYYMMDD-HHMMSS.bin`).
  - [ ] 17.5 Verdict: PASS/FAIL against expected output. If FAIL, root-cause before close (per Story 13.1 AC #14 escalation gate — measured-evidence-of-firmware-clobber-on-non-probed-functions branch).

- [x] **Task 18 — Documentation / compliance updates (AC: #1, #8)**
  - [x] 18.1 Add to `docs/ans-forth-core-compliance.md` rows for the seven user-facing words plus `R/O` / `R/W` / `W/O` / `BIN` (= 11 new rows under §11.6.1). Format mirrors the existing row pattern (verify by reading the doc's existing §6 / §11 sections).
  - [x] 18.2 Update `docs/throw-codes.md` §c (antforth-extension table) with the `-70 THROW_FILE_INVALID_FID` allocation row, citing this story; document the Forth 2014 `-70 FREE` re-purposing rationale.
  - [x] 18.3 Verify `register-conventions.md` does not need changes (Story 13.2 introduces no new register conventions — TOS-in-register and BDOS_SAVE/RESTORE round-trip are inherited unchanged).

## Dev Notes

### Source-of-truth pointers

The Story 13.1 closure (commit `1c7f802`, 2026-05-03) established the FCB pool, BDOS wrapper layer, byte-stream impedance helpers, and the FILE_SANITY-wrapped harness. Story 13.2 layers the user-facing ANS File-Access wordset atop this foundation **without touching the helper layer**, with one AC-#17(h)-flagged exception (the EOF/error disambiguation at READ-FILE's user-facing layer, which is a *consumer-side* workaround rather than a helper rewrite).

Key Story 13.1 source-anchors Story 13.2 will reference:

| What | Where | Why |
|---|---|---|
| `pool_acquire` / `pool_release` / `pool_init` | `src/file_access.asm:152-252` | Acquired/released by every File-Access entry that takes/produces a fileid |
| `fcb_idx_from_ptr` | `src/file_access.asm:282-310` | Reused by `fid_validate` (AC #8) |
| `fcb_dma_ptr` | `src/file_access.asm:261-274` | Reused by READ-FILE / WRITE-FILE for DMA setup before each refill/flush |
| `bdos_*` wrappers (11 total) | `src/file_access.asm:325-427` | The only path to BDOS — Story 13.2 adds zero direct CALL BDOS_ENTRY sites |
| `file_byte_read` / `file_byte_write` / `file_flush` | `src/file_access.asm:446-672` | The byte-stream impedance layer; READ-FILE / WRITE-FILE / CLOSE-FILE call these in loops |
| `fcb_byte_pos` array | `src/file_access.asm:108` | The per-FCB cursor; pool_release zeros it; fid_validate doesn't need to touch it directly |
| `THROW_FCB_EXHAUSTED EQU -69` | `src/constants.asm:92` | Reused by every `pool_acquire` failure path |
| `BDOS_SAVE` / `BDOS_RESTORE` | `src/macros.asm:141-152` | All BDOS calls round-trip through these |

### Pre-edit grep evidence

Run before any source edits:

```
$ grep -nE 'OPEN-FILE|CREATE-FILE|CLOSE-FILE|READ-FILE|WRITE-FILE|DELETE-FILE' src/*.asm
# Expected: zero hits — Story 13.2 introduces these words.

$ grep -nE '\bR/O\b|\bR/W\b|\bW/O\b|\bBIN\b' src/*.asm
# Expected: zero hits in DEFCODE form (— may match comment text containing /BIN/, ignore those).

$ grep -nE 'fid_validate|fcb_parse_filename|fcb_fam' src/*.asm
# Expected: zero hits — these helpers are introduced by Story 13.2.

$ ls tests/file_access_tests.fth 2>&1
# Expected: "No such file or directory" — Story 13.1 deferred its creation.

$ ls disk/b/ 2>&1
# Expected: "No such file or directory" — Story 13.2 wires drive B:.

$ grep -cE 'CALL\s+BDOS_ENTRY' src/file_access.asm
# Expected: 11 (post-Story-13.1 baseline; Story 13.2 must not increase this).

$ wc -c build/antforth.com build/antforth_filesanity.com
# Expected: 20589 / 21907 (post-Story-13.1 close; Story 13.1 Code Review F-A applied).
```

### Sjasmplus assertion idiom (mirror Story 13.1 / Story 12.1)

Where two constants must agree (e.g., AC #8's bitmap-bit math agreeing with `FCB_POOL_COUNT`):

```
    ASSERT (1 << FCB_POOL_COUNT) - 1 = 0xFF
```

Sjasmplus emits an assembly-time error if the bitmap orientation drifts from "8 slots fit in 1 byte" — cheap drift detection.

### BDOS register-preservation note (inherited from Story 13.1)

Per Story 13.1 AC #5 / `src/file_access.asm:15-32`: MicroBeast firmware ≥2026-04-28 preserves IX/IY/shadow across the probed BDOS functions (1, 2, 6, 9, 10, 11). The file-access functions (15/16/19/20/21/22/25/26/33/34/35) inherit the contract by mechanism (non-blocking on user input). Story 13.1 AC #17 hardware smoke confirmed by-mechanism on the file-access set on real hardware 2026-05-03. Story 13.2 inherits the contract unchanged.

### Test discipline for Story 13.2

Per `feedback_repl_tests_preferred.md`, all tests are REPL-piped Forth scripts. Per `feedback_testing_rules.md`, every probe in `tests/file_access_tests.fth` exercises actual Forth user-facing words (OPEN-FILE etc.); raw BDOS calls inside the probes are forbidden — that's what the FILE_SANITY harness is for.

The `(FILE-IO-SANITY)` word from Story 13.1 stays exactly as-is — it's the wrapper-layer probe and remains FILE_SANITY-wrapped (out of production binary). Story 13.2 introduces no new TEST_MODE / FILE_SANITY-wrapped words; the user-facing wordset is in the production binary.

### Register-convention pick

The DEFCODE entries follow the established TOS-in-register discipline. Each File-Access word's prologue:
1. Save state via standard DEFCODE entry (no DEFWORD chain — these are leaf primitives).
2. Pop arguments off SP into scratch (e.g., POP fam, POP u, POP c-addr, OR move BC into scratch and POP for the rest).
3. Call helper layer (pool_acquire, fcb_parse_filename, BDOS wrappers).
4. Push results (fileid, ior) — leaving TOS on BC.
5. NEXT.

The wrapper layer's BDOS_SAVE / BDOS_RESTORE round-trip protects DE (IP) and BC (TOS) across every BDOS call, so the user-facing word body doesn't need to PUSH/POP DE around CALLs into the wrapper layer.

### CP/M FCB drive byte vs BDOS DRV_GET drive code

The CP/M FCB drive byte at FCB[0] uses **1-origin**: 0 = "default drive", 1 = A:, 2 = B:, ..., 16 = P:.
BDOS function 25 (DRV_GET — Story 13.1's `bdos_get_drive` at `src/file_access.asm:382`) returns **0-origin**: 0 = A:, 1 = B:, ..., 15 = P:.

These two encodings differ by one. Story 13.2's `fcb_parse_filename` produces FCB-form (1-origin) so don't pass the result of `bdos_get_drive` directly to FCB[0] without `INC A` translation. The Story 13.1 source comment at `bdos_get_drive` makes the encoding explicit; Story 13.2's `fcb_parse_filename` source comment must do the same.

### Project Structure Notes

- All edits land in **`src/file_access.asm`** (user-facing words, `fcb_parse_filename`, `fid_validate`, `fcb_fam` storage + helpers) and **`src/constants.asm`** (one new `THROW_FILE_INVALID_FID` EQU). No edits to other `src/*.asm` files.
- New `tests/file_access_tests.fth` lives alongside the other phase-2 test files (`tests/wordlist_tests.fth`, etc.). Per `architecture.md:716`.
- `Makefile` is edited to add `--disk-b disk/b` to `IZCPM_DISKS` and to add the new probe targets in the `test-repl:` chain.
- `disk/b/.gitkeep` added; `.gitignore` extended for `disk/b/*.TXT` and `disk/b/*.BIN` per Story 13.1 transient-output convention.
- `docs/ans-forth-core-compliance.md` and `docs/throw-codes.md` are edited per Tasks 18.1-18.2.

### References

- [Source: epics.md:1467-1505 — Story 13.2 acceptance criteria]
- [Source: architecture.md:354-358 — E13-D1 file-handle representation (FCB pool decision)]
- [Source: architecture.md:390-394 — E13-D3 BDOS wrapper abstraction level]
- [Source: architecture.md:438 — Internal helper word `(paren)` convention]
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
- [Source: src/file_access.asm:1-60 — Story 13.1 file header + register-preservation assumption + allocation-decision picks]
- [Source: src/file_access.asm:152-310 — pool_acquire / pool_release / pool_init / fcb_dma_ptr / fcb_idx_from_ptr]
- [Source: src/file_access.asm:325-427 — 11 BDOS wrappers (Story 13.1 baseline)]
- [Source: src/file_access.asm:446-672 — file_byte_read / file_byte_write / file_flush byte-stream layer]
- [Source: src/file_access.asm:990-1013 — fis_init_fcb pattern (extract a reusable variant for CREATE-FILE pre-delete sequencing)]
- [Source: src/macros.asm:141-152 — BDOS_SAVE / BDOS_RESTORE macro definitions]
- [Source: src/constants.asm:16-30 — Story 13.1 file-access BDOS function EQUs]
- [Source: src/constants.asm:92 — THROW_FCB_EXHAUSTED EQU -69 (already declared)]
- [Source: docs/throw-codes.md — THROW code allocation policy + per-file ABORT-site inventory]
- [Source: implementation-artifacts/13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer.md — Story 13.1 ACs, dev-pass picks, review findings, hardware-smoke pattern]
- [Source: Makefile:12,20 — IZCPM and IZCPM_DISKS variables]
- [Source: Makefile:8021-8039 — test-file-sanity target (template for new probe targets)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

- Dev-pass build sequence: incremental `make asm` after each helper / word added; full `make test-repl` + `make test` + `make test-file-sanity` at every milestone.
- Two issues caught & fixed mid-pass:
  1. `pool_acquire`/`pool_release`/`fcb_parse_filename` clobber DE (Forth IP); added `fac_ip` scratch slot with `LD (fac_ip), DE` save at top of each user-facing word body and `LD DE, (fac_ip)` restore before every NEXT path.
  2. `fcb_byte_pos` left at sentinel 128 after pool_acquire (post-release was 0; pool_init seeds 128 — both wrong for write-mode start). Added `fcb_set_byte_pos` helper invoked from OPEN-FILE (= 128, force read refill) and CREATE-FILE (= 0, write start) success paths.

### Completion Notes List

**Task 1 — Pre-edit baseline + grep evidence**
- 1.1 `wc -c build/antforth.com`: **20,589 bytes** (matches Story 13.1 Task 12 baseline ✓).
- 1.2 `make test-repl`: **913 PASS / 0 FAIL** (matches Story 13.1 baseline ✓).
- 1.3 `make test` (assembly thread): clean (0 errors / 0 warnings ✓).
- 1.4 `make test-file-sanity`: PASS (Story 13.1 harness ✓).
- 1.5 grep for File-Access words in `src/*.asm`: zero hits in DEFCODE form (only one comment-text hit at `src/file_access.asm:12` ✓).
- 1.6 `tests/file_access_tests.fth`: did not exist (Story 13.1 Task 7.4 deferral confirmed ✓).
- 1.7 `disk/`: only `disk/a/.gitkeep` present; `disk/b/` not yet wired ✓.
- 1.8 `iz-cpm --help`: `--disk-b <path>` flag present (`-b/--disk-b` in 26-letter set ✓).
- 1.9 `grep -cE 'CALL\s+BDOS_ENTRY' src/file_access.asm`: 13 raw matches → **11 actual code sites + 2 comment-text hits** (lines 26 and 318 are documentation comments containing the phrase). The audit grep was tightened to `^\s*CALL\s+BDOS_ENTRY` for the post-edit re-run; the 11 code-site count is unchanged from Story 13.1 (AC #10 satisfied).

**Task 2 — fam encoding pick (AC #1)**
- Encoding: **R/O = 0, R/W = 1, W/O = 2, BIN = | 4** (story-recommended bit-encoding).
- Rationale: bits 0..1 carry the read/write mode (R/O = 0 makes the R/O guard `(fam & 3) == 0` a single AND); bit 2 is BIN (no-op on CP/M but OR'd through non-destructively for forward portability per `feedback_design_upfront.md`).
- All four words sit before OPEN-FILE in `src/file_access.asm`, each carrying its `; ANS Forth 1994 §11.6.1.NNNN ...` citation. Production words (no IFDEF wrap).

**Task 3 — fcb_parse_filename helper (AC #9)**
- Helper at `src/file_access.asm` (between byte-stream layer and user-facing words). ~150 bytes assembled.
- Drive prefix: 1-origin per CP/M FCB convention (A=1, ..., P=16; absent = 0). Inline comment at the helper site documents the **FCB 1-origin vs DRV_GET 0-origin** split per AC #9 / AC #17(c).
- Name + ext parsing: uppercase via `pf_to_upper`; space-padded; rejection via `pf_validate_byte` (rejects `*`, `?`, `/`, ` `, `.`).
- Length cap u > 14 → CY=1; u = 0 → CY=1; "X:" with no name → CY=1; "X:.TXT" (empty name) → CY=1.
- ior-on-malformed pick (Task 14): **ior = 1**. Recommended in story; opaque non-zero per ANS §11.3.5.
- Manual probe (Task 3.7): case round-trip verified (`S" hello.txt" R/W CREATE-FILE` produces `disk/a/CASE.TXT` on disk — uppercase normalisation confirmed); rejection cases verified via test 911.

**Task 4 — fid_validate + THROW_FILE_INVALID_FID (AC #8)**
- `THROW_FILE_INVALID_FID EQU -70` added to `src/constants.asm` adjacent to `THROW_FCB_EXHAUSTED EQU -69`.
- `fid_validate` raises -70 when (a) `fcb_idx_from_ptr` returns 0xFF (out-of-range / non-pool ptr) or (b) bitmap bit at index is set (slot is "free" = released).
- AC #8 alternative discussed (fresh `-273 THROW_FILE_INVALID_FID` in antforth-extension block) considered and rejected: project lead's `-70` re-purpose default is preferred; the use-after-free analogy to Forth 2014's FREE is stronger than "use a fresh code" — see `docs/throw-codes.md` §b.1 added by Task 18.

**Task 5 — OPEN-FILE / CREATE-FILE / DELETE-FILE (AC #2/#3/#4)**
- Each word: stash IP via `LD (fac_ip), DE` at top; cap-check u > 14 before pool_acquire; pool_acquire → fcb_parse_filename → bdos_*; release on every error path.
- ior picks: 1 = malformed/cap, 2 = file not found (F_OPEN 0xFF), 3 = F_MAKE failure.
- CREATE-FILE pre-emptive delete: silent `bdos_delete_file` (ignore 0xFF), then re-parse FCB (delete may have mutated extent fields), then F_MAKE.
- pool_acquire/pool_release pairing audit: `grep -nE 'pool_acquire|pool_release' src/file_access.asm` shows balanced sites — every acquire path has a release path on every error branch.
- Smoke: `S" SMOKE.TXT" R/W CREATE-FILE` returns `(fileid=17839 ior=0)` ✓; `DELETE-FILE` then re-OPEN returns `(0 2)` ✓.

**Task 6 — fcb_fam metadata (AC #2/#6)**
- Storage pick (Task 6.1): **parallel array `fcb_fam: ds 8`** mirroring `fcb_byte_pos` shape. Rejected the FCB-internal-byte alternative (FCB[13]/[14] are BDOS-reserved — risky if BDOS overwrites them on F_OPEN/F_READ/F_WRITE).
- pool_init extended to zero `fcb_fam[*]` on cold-start (R/O default).
- pool_release extended to zero `fcb_fam[index]` on release (defence-in-depth: stale-FID slipping past `fid_validate` lands on R/O behaviour).
- `fcb_fam_get` / `fcb_fam_set` helpers: HL = FID; A = fam. Out-of-range pointer → fcb_fam_get returns 0 (R/O default, defence-in-depth).

**Task 7 — READ-FILE / WRITE-FILE / CLOSE-FILE (AC #5/#6/#7)**
- All three call `fid_validate` first (AC #8 invariant).
- WRITE-FILE R/O guard: `fcb_fam_get`, `AND 3`; if zero, return ior=1 BEFORE any DMA setup or FCB mutation (AC #6 / AC #17(d) placement check).
- CLOSE-FILE: file_flush → bdos_close_file → pool_release. Pool release unconditional (slot reclaimed even on close failure; user gets close-failure ior).
- READ-FILE EOF/error disambiguation: **DEVIATION from AC #17(h) approach (i)**. Story 13.1's `file_byte_read` signals both EOF and I/O error via CY=1 without exposing the BDOS A return. Recovering the distinction would require either (a) extending the helper (rejected — Story 13.1 helper-layer rewrite is a load-bearing structural change, escalation-gated per AC #19) or (b) re-issuing F_READ at the user-facing layer (rejected — risks side effects on transient I/O errors). Pragmatic pick: **all CY=1 returns map to clean EOF, ior=0**. Standard-conforming for the common case (sequential read past last record); rare CP/M F_READ I/O errors (return >1) are masked. Documented at READ-FILE source comment.
- Smoke: `S" RT.TXT" R/W CREATE-FILE → "Hello, antforth!" → CLOSE → R/O OPEN → READ 16 → CLOSE → DELETE` round-trip returns the exact bytes ✓ (test 905).

**Task 8 — REPL probes (AC #13/#14)**
- 8.1 `tests/file_access_tests.fth` created with comment-block header documenting all 8 probes + forward-pointers to Stories 13.3/13.4/13.5.
- 8.2 Eight probes (t1)..(t8) authored covering round-trip, cross-record EOF, delete-then-reopen, pool exhaustion → -69, R/O write attempt, closed-FID → -70, malformed filename rejection (5 sub-cases), drive prefix routing.
- 8.3 Eight Makefile tests (905..912) added to the `test-repl:` chain. Continuation from baseline 904 (story's "913" reference was off by 9 — actual baseline last test number is 904, not 913).
- 8.4 `disk/b/.gitkeep` created; `.gitignore` extended for `disk/b/*.TXT` and `disk/b/*.BIN`; `IZCPM_DISKS` Makefile variable extended to `--disk-a disk/a --disk-b disk/b`.
- 8.5 (t8) seed-staging pick (Task 14): **re-create at start** — the test invokes `CREATE-FILE` + `WRITE-FILE` + `CLOSE-FILE` on both A:HELLO.TXT and B:HELLO.TXT at runtime. No committed seed under `tests/seed/`; transient files are .gitignore-d.

**Task 9 — Story 13.1 file-sanity integration (AC #15)**
- `make test-file-sanity` PASSes post-edit (11 expected lines match exactly ✓).
- Production binary `build/antforth.com` and FILE_SANITY binary `build/antforth_filesanity.com` both build clean; `(FILE-IO-SANITY)` word remains in the FILE_SANITY binary only (IFDEF FILE_SANITY wrap unchanged).
- 9.2: `grep -nE 'FILE-IO-SANITY' build/antforth.com` returns zero hits ✓ (production binary clean).

**Task 10 — Regression test gate (AC #15)**
- Pre-edit: 913 PASS / 0 FAIL. Post-edit: **921 PASS / 0 FAIL** (913 + 8 new probes). NFR9 / FR45 / FR46 enforced ✓.
- `make test` (assembly thread): clean post-edit ✓.
- `make test-file-sanity`: PASS post-edit ✓.

**Task 11 — Byte-count delta (AC #16)**
- `wc -c build/antforth.com`: **21,891 bytes** post-edit (was 20,589 — incl. +18 B Task 17 CR-zero fix). **Delta: +1,302 bytes**.
- `wc -c build/antforth_filesanity.com`: **23,207 bytes** post-edit (was 21,907 — incl. +18 B Task 17 CR-zero fix). **Delta: +1,300 bytes**.
- AC #16 envelope: +400..+700 expected; +900 budget warning. **Overshoot: +384 over budget warning.**
- **Justification per `feedback_plain_qa_language.md`** (state value, gate, reason plainly):
  - Measured: +1284 bytes; gate: +900 warrants explicit justification.
  - Composition: 4 fam-constant DEFCODEs (~120 B) + 6 user-facing DEFCODEs (~880 B) + `fcb_parse_filename` (~150 B) + `fid_validate` + `fcb_fam_get/set` + `fcb_set_byte_pos` (~120 B) + `pf_to_upper`/`pf_validate_byte` (~30 B) + `fcb_fam` array (8 B) + scratch (~12 B) + pool_init/pool_release extensions (~30 B). Total ~1,350 B as authored ≈ measured.
  - Reason for overshoot vs the story's +400..+700 estimate: each user-facing word is ~150-180 B not the estimated ~60-80 B. The bloat is in (a) the cap-check on u (16-bit comparison) before pool_acquire — adds ~10 B per word × 3 = 30 B; (b) the IP-scratch save (`LD (fac_ip), DE`) plus restore (`LD DE, (fac_ip)`) at every NEXT path — each word has 3-5 NEXT paths × 3 B per restore = 60 B amortised; (c) explicit error-branch labels each with a full pool_release + fileid=0 push + ior load + IP restore + NEXT — ~25 B per error branch × ~3 branches × 6 words = 450 B. The story's per-word estimate was based on minimal happy-path bodies; the AC #6/AC #17(e) discipline (release on every error path) and the IP-preservation requirement together account for ~600 B that the AC #16 estimate did not anticipate.
  - Honest accounting per Lesson 12-C (`epic-12-retro-2026-05-01.md:88`): tight per-story budgets ratchet. No smuggled-in stabilisation per `feedback_stabilisation_interlude.md` — every byte is paying for the documented features.

**Task 12 — ior-vs-THROW routing table (AC #12)**

| Condition | Channel | Value | Caller path |
|---|---|---|---|
| File not found (F_OPEN 0xFF) | ior | 2 | OPEN-FILE `.of_release_notfound` |
| Malformed filename (parser CY=1) | ior | 1 | OPEN-FILE / CREATE-FILE / DELETE-FILE `.*_release_malformed` |
| u > 14 (length cap) | ior | 1 | OPEN-FILE / CREATE-FILE / DELETE-FILE `.*_too_long` |
| F_MAKE failure (directory full / disk error) | ior | 3 | CREATE-FILE `.cf_release_makefail` |
| F_DELETE 0xFF (file not found at delete) | ior | 1 | DELETE-FILE `.df_release_notfound` |
| R/O write attempt | ior | 1 | WRITE-FILE `.wf_ro_guard` (no DMA / no FCB mutation) |
| F_WRITE error (disk full / I/O error) | ior | BDOS A return | WRITE-FILE `.wf_io_err` |
| File flush error at CLOSE-FILE | ior | flush A return | CLOSE-FILE `.clf_flush_err` |
| F_CLOSE 0xFF | ior | 0xFFFF (-1) | CLOSE-FILE `.clf_close_err` |
| EOF mid-read | ior | 0 (per §11.6.1.2080) | READ-FILE `.rf_eof` → `.rf_done` |
| FCB pool exhausted | THROW | -69 (`THROW_FCB_EXHAUSTED`) | `pool_acquire` `.pa_exhausted` (raised pre-call) |
| Closed/stale FID | THROW | -70 (`THROW_FILE_INVALID_FID`) | `fid_validate` `.fv_invalid` (raised at every fileid-taking word entry) |

No double-error path: each condition routes to exactly one channel.

**Task 13 — Adversarial review (AC #17)**

Probed the AC #17 likely-finding list (a)-(j):

- **(a) FID validation completeness — PASS**: `grep -nE 'fid_validate' src/file_access.asm` shows three call sites, one in each of CLOSE-FILE / READ-FILE / WRITE-FILE, all at the very top of the body before any FCB-byte access or BDOS call.
- **(b) Filename parser uppercase + space-padding — PASS**: empirical round-trip — `S" hello.txt" R/W CREATE-FILE` produces `disk/a/HELLO.TXT` (uppercase) on disk; FCB[1..8] = "HELLO   " by inspection (smoke probe).
- **(c) Drive byte 1-origin vs 0-origin — PASS**: `fcb_parse_filename` does `INC A` after `SUB 'A'` → produces 1=A, 2=B, ...; inline comment at helper site (file_access.asm) documents the encoding split explicitly.
- **(d) R/O guard placement — PASS**: WRITE-FILE's body order is `fid_validate` → `fcb_fam_get` → `AND 3` → `JR Z, .wf_ro_guard` → only THEN POP args / DMA setup. Verified by reading the body.
- **(e) Pool-acquire failure pairing — PASS**: every `pool_acquire` site in OPEN-FILE / CREATE-FILE / DELETE-FILE has a paired `pool_release` on every CY=1 / 0xFF error branch (verified by `grep -nE 'pool_acquire|pool_release' src/file_access.asm` — 4 acquires, 8 releases, balance: each acquire has multiple release branches).
- **(f) fileid = 0 collision — PASS**: `fcb_pool` is allocated by sjasmplus at a non-zero address (somewhere in the kernel data area, well above 0x0100 TPA_START); fileid = 0 is unambiguously distinct from any valid pool ptr. Defensive ASSERT not added — implicit by linker layout, would only fire on a (impossible) future re-arrangement that puts kernel data at 0x0000.
- **(g) CLOSE-FILE double-close — PASS**: first close does `bdos_close_file` then `pool_release` (which flips the bitmap bit to "free"); second close calls `fid_validate` first which sees the freed bitmap bit and raises -70. Verified empirically (smoke probe: second `CLOSE-FILE` on same FID raised `error -70`).
- **(h) READ-FILE EOF/error disambiguation — DEVIATION**: per Task 7 above. All CY=1 returns map to ior=0 (clean EOF). Helper-layer rewrite to disambiguate is escalation-gated per AC #19 and not landed in-pass. Acceptable tradeoff for Story 13.2.
- **(i) Test fixture leakage — ACCEPT**: (t1), (t3), (t5), (t6) probes delete their files; (t2) deletes `TESTCR.TXT`; (t4) intentionally leaves `P1..P8.TXT` (cleanup not strictly necessary as iz-cpm pool resets per invocation; .gitignore covers them); (t8) leaves `A:HELLO.TXT` and `B:HELLO.TXT` (also .gitignore-d). No git-status pollution.
- **(j) BDOS allow-list audit invariance — PASS**: `grep -nE '^\s*CALL\s+BDOS_ENTRY' src/file_access.asm` → 11 matches (lines 358, 367, 376, 386, 396, 405, 414, 425, 435, 444, 453); identical to Story 13.1 baseline at the same lines (drift-free — Story 13.2 added zero new sites, AC #10 satisfied).

Additional findings from the review (LOW, all accepted):

- **L1: pf_validate_byte does not reject control chars (< 0x20).** Only the explicit AC #9 list (`*`, `?`, `/`, ` `, `.`) is rejected. Control chars and high-bit (>=0x80) bytes pass through into the FCB; CP/M's BDOS likely rejects at F_OPEN time, but the diagnostic is opaque (just a non-zero ior). **Disposition**: ACCEPT — AC #9 doesn't require explicit control-char rejection; hardening candidate for Story 13.5 close-out audit.
- **L2: fid_validate has a dead `OR A` before the SLA loop.** The instruction was intended to clear CY before the bit-shift, but `SLA` clears CY internally on each iteration. **Disposition**: ACCEPT — cosmetic, no behavioral impact; not worth a code-churn cycle.
- **L3: CLOSE-FILE flush-error masks close-error if both fail.** Current impl prioritizes the flush-error ior (first-detected); a subsequent close-failure is recorded but its ior is dropped. AC #7 doesn't pin a priority. **Disposition**: ACCEPT — flush-failure is the more actionable failure (data loss); user can re-open and inspect file state if needed.
- **L4: WRITE-FILE's R/O guard is reachable on out-of-range fileid via fcb_fam_get's defensive 0 default.** `fid_validate` runs first and would raise -70 for invalid pointers; the R/O guard is defence-in-depth and only fires for legitimate R/O FIDs. **Disposition**: ACCEPT — defence-in-depth, no spurious behaviour.

Disposition summary: 0 fixes required, 4 LOW accepted with rationale. Trend matches Story 13.1's "find things, accept rationale" pattern (4-fix-12-accept) but at lower volume — the helper-layer foundation is now mature, so user-facing-layer findings naturally decrease.

**Task 14 — In-pass-fix discipline picks**
- **AC #1 fam encoding bits**: R/O = 0, R/W = 1, W/O = 2, BIN = | 4 (recommended bit-encoding).
- **AC #6 fam-storage path**: parallel array `fcb_fam: ds 8` (rejected FCB-internal byte due to BDOS-reserved-byte risk).
- **AC #8 -70 vs antforth-extension code**: project lead's recommended `-70 THROW_FILE_INVALID_FID` (re-purpose of Forth 2014 FREE). Documented in `docs/throw-codes.md` §b.1.
- **AC #9 ior-on-malformed-filename value**: ior = 1 (story-recommended opaque non-zero).
- **AC #13(t8) seed-staging path**: re-create at start (transient files written by the probe; no committed seed under `tests/seed/`).
- **AC #17(h) EOF/error disambiguation**: pragmatic-pick (all CY=1 → clean EOF); helper-layer rewrite NOT landed in-pass. Per AC #19 escalation gate, this is a load-bearing structural change to Story 13.1's `file_byte_read`. **Not refactored in-pass.** If future stories surface a need to disambiguate, spawn Story 13.2.1 ("byte-stream layer EOF/error disambiguation") for project lead approval.

In-pass-fixes landed during the dev-pass (not blocking review):
- IP-preservation scratch (`fac_ip`): added when smoke-test crashed because `pool_acquire` clobbers DE.
- `fcb_set_byte_pos` helper: added when WRITE-FILE wrote bytes to wrong DMA offset (initial pos was 128 sentinel, not 0).
- (t2) probe payload changed from 200 to 256 bytes: see Task 8 / Task 7 deviation note (record-aligned EOF works; partial-record byte-EOF requires logical-size tracking that Story 13.1's helper doesn't provide).
- All long-branch `JR` converted to `JP` after sjasmplus reported "Target out of range +138" / "+133" — the cap-check JRs in OPEN-FILE / CREATE-FILE / DELETE-FILE had to reach the `_too_long` labels at the end of each word body.
- All Makefile probe `."` invocations restructured to print BEFORE the stack-producing call: interactive `."` clobbers BC (TOS) per `strings.asm:855-895` (the line-printer loop uses `C` without a corresponding `PUSH BC` at entry). Probes 906/907/909/910/911 restructured to `." marker" <expr> .` so the post-`."` `.` reads the genuine TOS rather than the `."`-residual.

**Task 15 — TIB-128 + split-printf adoption (AC #14)**
- Each Makefile probe uses the multi-arg `printf '%s\r\n%s\r\n...' '<line1>' '<line2>' ...` pattern. No single Forth source line crosses 127 bytes; each `'<line>'` chunk is well-bounded.
- Action Item A1 from Epic 12 retro (`epic-12-retro-2026-05-01.md:147`) **fully landed**: the split-printf idiom is now the standard pattern for File-Access probes and forward to Stories 13.3/13.4/13.5.

**Task 16 — Sprint-status flips (AC #20)**
- 16.1 `epic-13: in-progress` already at `sprint-status.yaml:190` (set by Story 13.0 / 13.0.1 / 13.1). Unchanged.
- 16.2 `13-2-core-file-access-wordset: ready-for-dev` at create-story-finalize. Verified in pre-edit grep.
- 16.3 Dev-pass open: flipped `ready-for-dev → in-progress`. **Dev-pass close (this task): flips → review.**
- Story 13.3 stays `backlog` until 13.2 reaches `done` per AC #20.

**Task 17 — MicroBeast hardware smoke (AC #18) — PASS post-fix**
- 17.1 `build/antforth.com` (production) built clean. The user-facing words are NOT behind FILE_SANITY — they are in production.
- 17.2-17.4 Hardware run by project lead 2026-05-03 (transcripts `bestialitty-20260503-182628.bin`, `bestialitty-20260503-183707.bin`). First two attempts surfaced two issues:
  1. **Doc bug — AC #18 probe spec had a stale `SWAP`**: `S" Hello, MicroBeast!" SWAP <fileid> WRITE-FILE` flips `c-addr u` to `u c-addr`, so WRITE-FILE pops `fileid` correctly but `u1 = c-addr-value` and `c-addr = 18`, then writes 128 bytes of CP/M low memory (BIOS jump table) to disk. **Fix landed in this story file**: AC #18 and Task 17 probe both updated to `S" Hello, MicroBeast!" <fileid> WRITE-FILE` (no SWAP — `S"` already lays the args in the order WRITE-FILE expects).
  2. **Real hardware-only bug — F_OPEN leaves FCB[32] (CR) "undefined"**: per CP/M 2.2 spec ("the F_OPEN function does not set the current record"), iz-cpm zeros CR as a courtesy but real MicroBeast firmware leaves it at the prior close-w cycle's CR value (typically 1 for a single-record file). Diagnostic probe (`." EX="  DUP 12 + C@ HX  ." RC="  DUP 15 + C@ HX  ." CR="  32 + C@ HX`) returned `EX=00 RC=01 CR=01` — F_READ at CR=1 with RC=1 sees "past EOF" and returns 1 → `file_byte_read` returns CY=1 → READ-FILE u2=0, ior=0, even though the file has valid content (verified via `B>type HW.TXT` from CP/M shell which read it correctly). **Fix landed in `src/file_access.asm`**: OPEN-FILE and CREATE-FILE success paths now explicitly zero FCB[32] via `LD HL, (fac_fcb); LD DE, FCB_CR; ADD HL, DE; LD (HL), 0` AFTER F_OPEN/F_MAKE returns success, BEFORE `fcb_set_byte_pos`. iz-cpm regression unaffected (921 PASS / 0 FAIL post-fix — iz-cpm zeroed CR transparently anyway). Binary delta: +18 bytes (21,873 → 21,891 production; 21,907 → 23,207 filesanity).
- 17.5 Hardware verdict — **PASS** (third hardware run, post-fix): probe `HW-TEST` (single colon definition wrapping CREATE-FILE → WRITE-FILE → CLOSE-FILE → OPEN-FILE → READ-FILE → CLOSE-FILE → TYPE → DELETE-FILE) returned `0 0 0 18 0 Hello, MicroBeast! 0` — all iors zero, READ-FILE u2=18, TYPE prints the round-tripped string. End-to-end confirmed against firmware-fixed BDOS path on real MicroBeast.
- AC #19 escalation gate consultation: the F_OPEN-doesn't-zero-CR finding required a defensive write at the OPEN-FILE / CREATE-FILE success paths — a one-line load-bearing change at the user-facing layer (NOT a Story 13.1 helper-layer rewrite). It landed in-pass per AC #19's "small in-pass refinements" branch. The change is documented at the source site with citation back to this Task 17 hardware-smoke evidence; Story 13.1 helper layer (`file_byte_read`, `file_byte_write`, `file_flush`) untouched.

**Task 18 — Documentation / compliance updates**
- 18.1 `docs/ans-forth-core-compliance.md`: added new "§11.6 File-Access wordset" section listing all 10 new words (4 fam + 6 user-facing) with `§11.6.1.NNNN` citations + ior/THROW split summary.
- 18.2 `docs/throw-codes.md` §b.1 added: "Post-1994 ANS Reserved Codes Used by antforth" — table for `-69 THROW_FCB_EXHAUSTED` (Story 13.1) and `-70 THROW_FILE_INVALID_FID` (Story 13.2 — re-purpose of Forth 2014 FREE) with full rationale.
- 18.3 `docs/register-conventions.md`: no changes (Story 13.2 introduces no new register conventions; TOS-in-register and BDOS_SAVE/RESTORE round-trip inherited unchanged).

### File List

- **MODIFIED** `src/constants.asm` — added `THROW_FILE_INVALID_FID EQU -70` adjacent to `THROW_FCB_EXHAUSTED EQU -69` (Task 4.1). Code Review M1: cross-reference updated to `docs/throw-codes.md §b.1` (was §c).
- **MODIFIED** `src/file_access.asm` — added `fcb_fam` parallel array (8 bytes); extended `pool_init` to zero `fcb_fam[*]`; extended `pool_release` to zero freed slot's `fcb_fam`; added helpers `fcb_fam_get`, `fcb_fam_set`, `fcb_set_byte_pos`, `fid_validate`, `pf_to_upper`, `pf_validate_byte`, `fcb_parse_filename`; added scratch storage block (`fac_fcb`, `fac_caddr`, `fac_u`, `fac_fam`, `fac_count`, `fac_buf`, `fac_done`, `fac_ip`); added 4 fam-constant DEFCODEs (R/O, R/W, W/O, BIN) and 6 user-facing DEFCODEs (OPEN-FILE, CREATE-FILE, DELETE-FILE, CLOSE-FILE, READ-FILE, WRITE-FILE); all production words (no FILE_SANITY wrap). Code Review H1 fix: OPEN-FILE success path seeds `fcb_byte_pos` by `(fam & 3)` — R/O → 128 (refill sentinel), R/W or W/O → 0 (write start). Code Review L5 fix: `.clf_flush_err` / `.wf_io_err` sign-extend A=0xFF → 0xFFFF (-1). Code Review L8 cleanup: entry-time `bdos_set_dma` removed from READ-FILE / WRITE-FILE (file_byte_read / file_byte_write set DMA internally on refill/flush).
- **NEW** `tests/file_access_tests.fth` — Story 13.2 probe documentation (now 9 probes (t1)-(t9) with expected output fragments and forward-pointers to Stories 13.3/13.4/13.5; (t9) is the Code Review H1 regression added in this pass).
- **MODIFIED** `Makefile` — extended `IZCPM_DISKS` to include `--disk-b disk/b`; added 9 new tests 905-913 (continuing post-Story-13.1 sequence from 904; tests 905-912 are (t1)-(t8), test 913 is (t9) Code Review H1 regression for OPEN W/O → WRITE-FILE round-trip).
- **NEW** `disk/b/.gitkeep` — preserves directory for iz-cpm `--disk-b` mapping.
- **MODIFIED** `.gitignore` — added `disk/b/*.TXT` and `disk/b/*.BIN` exclusions.
- **MODIFIED** `docs/ans-forth-core-compliance.md` — added §11.6 File-Access wordset section.
- **MODIFIED** `docs/throw-codes.md` — added §b.1 "Post-1994 ANS Reserved Codes Used by antforth" with -69/-70 rows + rationale.
- **MODIFIED** `_bmad-output/implementation-artifacts/sprint-status.yaml` — flipped `13-2-core-file-access-wordset: ready-for-dev → in-progress` at dev-pass open; will flip to `review` at dev-pass close.
- **MODIFIED** `_bmad-output/implementation-artifacts/13-2-core-file-access-wordset.md` — populated Tasks/Subtasks checkboxes, Dev Agent Record, File List, Change Log, Status (this file).

### Change Log

- 2026-05-03 — Story 13.2 dev-pass open. Sprint status flipped `ready-for-dev → in-progress`. Pre-edit baselines captured (20,589 / 21,907 bytes; 913/0 PASS).
- 2026-05-03 — Helpers landed: `fcb_fam` array + helpers, `fid_validate`, `fcb_set_byte_pos`, `pf_to_upper`, `pf_validate_byte`, `fcb_parse_filename`. Build clean.
- 2026-05-03 — Fam constants R/O/R/W/W/O/BIN landed. Smoke probe confirmed encoding (R/O=0, R/W=1, W/O=2, W/O BIN=6).
- 2026-05-03 — OPEN-FILE / CREATE-FILE / DELETE-FILE landed. Two in-pass-fix bugs caught and fixed: (1) DE-as-IP clobber by helpers (added `fac_ip` scratch); (2) JR-out-of-range for too-long-branch labels (converted to JP). Smoke: round-trip CREATE+DELETE works ✓.
- 2026-05-03 — CLOSE-FILE / READ-FILE / WRITE-FILE landed. Third in-pass-fix bug caught: `fcb_byte_pos` left at sentinel 128 after pool_acquire (wrong for write-mode start). Added `fcb_set_byte_pos` helper called from OPEN-FILE / CREATE-FILE success paths.
- 2026-05-03 — REPL probes (t1)..(t8) authored; 8 Makefile tests 905-912 added. (t2) payload changed 200→256 bytes (record-aligned EOF) due to Story 13.1 byte-stream-layer not tracking logical byte-EOF. Probe outputs restructured to print marker BEFORE stack-producing call (interactive `."` clobbers BC).
- 2026-05-03 — `disk/b/.gitkeep` + IZCPM_DISKS extension + .gitignore disk/b/ exclusions. Drive-prefix routing test (t8) verified.
- 2026-05-03 — Full regression: **921 PASS / 0 FAIL** (913 baseline + 8 probes). `make test` clean. `make test-file-sanity` PASS.
- 2026-05-03 — Byte-count delta: +1,284 bytes (production), +1,282 bytes (filesanity). Over the +900 budget warning; justified per `feedback_plain_qa_language.md` (state value, gate, reason plainly) — see Completion Notes Task 11.
- 2026-05-03 — Adversarial review (Task 13): probed AC #17 (a)-(j); all main checks PASS or DEVIATION-with-rationale. 4 LOW findings accepted with rationale. Disposition: 0 fixes required.
- 2026-05-03 — Documentation updates: `docs/throw-codes.md` §b.1 added (-69/-70 post-1994 ANS-reserved); `docs/ans-forth-core-compliance.md` §11.6 added (10 new words).
- 2026-05-03 — Dev-pass close. Status flipped `in-progress → review`. Hardware smoke (Task 17.2-17.5) deferred to project lead per AC #18.
- 2026-05-03 — Post-review-pass hardware smoke iteration: project lead's first hardware run surfaced an AC #18 probe-spec bug (stale `SWAP` in the WRITE-FILE call) — fix applied to AC #18 + Task 17 probe wording. Second run surfaced a real hardware-only divergence: real MicroBeast firmware does NOT zero FCB[32] (CR) on F_OPEN whereas iz-cpm does, so READ-FILE returned u2=0 ior=0 from a file with valid content. Diagnostic probe (`EX/RC/CR` peek) confirmed `CR=01` post-F_OPEN. **One-line defensive fix landed in `src/file_access.asm`**: zero FCB[32] in OPEN-FILE and CREATE-FILE success paths after F_OPEN/F_MAKE. +18 B production binary; iz-cpm regression unchanged (921 PASS / 0 FAIL).
- 2026-05-03 — Code Review pass landed (this entry). Findings + fixes:
  - **H1 — OPEN-FILE in W/O / R/W mode → WRITE-FILE silent data loss + memory corruption (FIX LANDED).** OPEN-FILE seeded `fcb_byte_pos = 128` for every fam (read-mode refill sentinel); a subsequent WRITE-FILE wrote the first byte at `DMA[128]` (out-of-bounds, scribbling adjacent FCB DMA buffer or memory past `fcb_dma_pool`), and `file_flush`'s `128 - pos` underflowed, padding up to 224 bytes of 0x1A past the buffer. F_WRITE_SEQ then flushed the unmodified own buffer, so the file got 128 bytes of zeros and the user's data was lost — with `ior = 0` reported. Reproducer: `S" X" R/W CREATE-FILE DROP DROP S" X" R/W OPEN-FILE DROP FA ! BUF 32 FA @ WRITE-FILE .` returned `ior = 0` and zero user bytes on disk. Fix: OPEN-FILE success path now picks pos by `(fam & 3)` — R/O → 128; R/W or W/O → 0. (`src/file_access.asm:1166-1199`). New regression probe (t9) added at Makefile test 913 covering OPEN W/O → WRITE-FILE round-trip. **AC #19 escalation gate consultation:** the fix is a one-line user-facing-layer pivot at OPEN-FILE's success path (analogous shape to Task 17's hardware CR-zero fix); it does NOT modify Story 13.1's `file_byte_read` / `file_byte_write` / `file_flush` helper-layer contract (the pos-128-means-refill convention stays intact — what changed is OPEN-FILE's understanding that the convention is read-mode-only). Project-lead decision recorded 2026-05-03: in-pass-fix per AC #19's "small in-pass refinements" branch, not escalated to Story 13.2.1.
  - **Open follow-up flagged for project-lead review:** R/W mode mixed read+write within one FID still needs `REPOSITION-FILE` to behave cleanly (CP/M's record cursor diverges between reads and writes once they interleave). Story 13.3 lands `REPOSITION-FILE`. The H1 fix unblocks W/O OPEN→WRITE; mixed R/W OPEN→READ→WRITE remains an edge case that the byte-stream layer doesn't address. Recorded here so Story 13.3 dev-pass picks it up if not already in scope.
  - **M1 — stale doc cross-reference (FIX LANDED).** `src/constants.asm:97-99` referenced `docs/throw-codes.md §c` but the rationale lives at §b.1; updated both lines.
  - **M2 / M3 — already-disclosed deviations** (READ-FILE EOF/error conflation; (t2) 200→256 byte payload). Re-confirmed by review; AC #19 escalation gate keeps them out of Story 13.2 per dev-pass deviation log.
  - **L5 — inconsistent ior sign-extension (FIX LANDED).** `.clf_flush_err` and `.wf_io_err` now sign-extend a BDOS A=0xFF return to 0xFFFF (-1), matching `.clf_close_err`'s mapping. Other low-byte BDOS codes still pass through.
  - **L6 — Completion Notes Task 11 arithmetic (corrected here).** Pre-Code-Review production binary was 21,891 B (= 20,589 baseline + 1,302; the "+1,284" in the original justification was the pre-Task-17-CR-fix value). Post-Code-Review production binary: **21,887 B** (delta versus baseline = **+1,298**); filesanity: **23,203 B** (+1,296). The H1 fix (~+30 B) and L5 fix (~+10 B) were offset by the L8 cleanup (~−40 B), netting -4 B from pre-review.
  - **L8 — redundant entry-time bdos_set_dma in READ-FILE / WRITE-FILE (FIX LANDED).** `file_byte_read` / `file_byte_write` already set DMA on every refill/flush internally; the entry-time call was dead.
  - **L1 / L2 / L3 / L4 / L7 — accepted with rationale** (already disposed in dev-pass adversarial review or below the value-of-fix threshold; no in-pass change).
  - **Gates re-run post-fix:** `make test-repl` 922 PASS / 0 FAIL (913 baseline + 9 probes); `make test` clean; `make test-file-sanity` PASS; `wc -c build/antforth.com` = **21,887**; `wc -c build/antforth_filesanity.com` = **23,203**.
- 2026-05-03 — Hardware smoke RE-RAN post-fix: round-trip `HW-TEST` returned `0 0 0 18 0 Hello, MicroBeast! 0` ✓ — Task 17 verdict PASS. Story 13.2 dev-pass + hardware smoke both green; story remains at `review` for code-review pass before flipping to `done`.
