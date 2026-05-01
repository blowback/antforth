# Story 13.1: File I/O sanity — FCB pool + BDOS wrapper layer (PRD risk mitigation)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an antforth maintainer,
I want the 288-byte FCB pool and the internal BDOS wrapper layer implemented and exercised against a known-good CP/M image *before* any user-facing file-access words are introduced,
So that CP/M 128-byte record boundaries, EOF handling, and BDOS call conventions are validated on their own terms — avoiding mid-epic surprises called out in the PRD risk table (epics.md:1323-1357).

## Acceptance Criteria

1. **Given** E13-D1's decision (kernel-resident static array; `architecture.md:354-358`),
   **when** new file `src/file_access.asm` is built,
   **then** it contains `fcb_pool: ds 288` (8 × 36-byte FCBs) as a labelled byte region, linked into the `.COM` binary at build time, accessed by absolute address; the constants `FCB_SIZE EQU 36` and `FCB_POOL_COUNT EQU 8` are defined in this file with citations pointing to `architecture.md:356` (E13-D1) and the CP/M 2.2 BDOS spec FCB layout. The file is wired into `src/antforth.asm`'s INCLUDE chain (mirror the Epic-12 pattern: `src/wordlists.asm` was added in Story 12.1 and INCLUDEd from `antforth.asm` after bootstrap — see `src/antforth.asm` for the existing INCLUDE block; pick the same insertion point). The `fcb_pool:` symbol is exported (i.e., not behind a `MODULE`/`ENDMODULE` private namespace) so future Stories 13.2-13.4 can reference it by name.

2. **Given** E13-D3's BDOS wrapper layer decision (`architecture.md:390-394`) and NFR13's BDOS allow-list (epics.md:1483: functions 1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40),
   **when** `src/file_access.asm` is authored,
   **then** it exposes private (file-private — not dictionary entries) Z80 subroutines for the file-access subset of the allow-list:
   - **`bdos_open_file`** — BDOS function 15 (`F_OPEN`); entry `DE = FCB ptr`; returns `A = directory code` or `0xFF` on error.
   - **`bdos_close_file`** — BDOS function 16 (`F_CLOSE`); entry `DE = FCB ptr`; returns `A = directory code` or `0xFF`.
   - **`bdos_delete_file`** — BDOS function 19 (`F_DELETE`); entry `DE = FCB ptr`; returns `A = directory code` or `0xFF`.
   - **`bdos_create_file`** — BDOS function 22 (`F_MAKE`); entry `DE = FCB ptr`; returns `A = directory code` or `0xFF`.
   - **`bdos_read_seq`** — BDOS function 20 (`F_READ`); entry `DE = FCB ptr`; reads 128-byte record into the FCB-associated DMA buffer; returns `A = 0` (success), `1` (EOF), or other code on error.
   - **`bdos_write_seq`** — BDOS function 21 (`F_WRITE`); entry `DE = FCB ptr`; writes 128-byte record from the DMA buffer; returns `A`.
   - **`bdos_read_rand`** — BDOS function 33 (`F_READRAND`); entry `DE = FCB ptr` (with `r0/r1/r2` set); returns `A`.
   - **`bdos_write_rand`** — BDOS function 34 (`F_WRITERAND`); entry `DE = FCB ptr`; returns `A`.
   - **`bdos_file_size`** — BDOS function 35 (`F_SIZE`); entry `DE = FCB ptr`; computes file size into the FCB's `r0/r1/r2` random-record fields; returns `A`.
   - **`bdos_get_drive`** — BDOS function 25 (`DRV_GET`); no entry args; returns `A = current drive (0=A, 1=B, ...)`.
   - **`bdos_set_dma`** — BDOS function 26 (`F_DMAOFF`); entry `DE = DMA buffer ptr`; no return value of interest. Required because each FCB needs an associated DMA buffer for sequential I/O.
   Each subroutine carries a one-line citation comment of the form `; CP/M 2.2 BDOS function NN (NAME) — purpose` (mirror `src/io.asm` BDOS-call sites which currently cite by function-number constant; a literal section reference to the CP/M 2.2 manual is acceptable but not required since the manual is not in-tree). Per CCD-3 / NFR17 (`architecture.md:472`), every BDOS call site has the function number visible at the source location — either via the cited helper name (`CALL bdos_open_file ; F_OPEN (15)`) or via the inline `LD C, F_OPEN` / `LD C, 15` setup.

3. **Given** AC #2's per-function helpers and AC #1's pool storage,
   **when** byte-oriented I/O is required (the impedance match between CP/M's 128-byte record model and ANS File-Access's byte-stream contract — `architecture.md:392-394`),
   **then** `src/file_access.asm` additionally exposes:
   - **`file_byte_read`** — entry `DE = FCB ptr`, returns `A = byte` on success, signals EOF via a documented protocol (recommended: `CY` flag set on EOF; pick the exact protocol in dev-pass and document in Completion Notes Task 3). Internally tracks the per-FCB DMA buffer and the current byte-within-record cursor; reloads the buffer via `bdos_read_seq` when the cursor crosses a record boundary.
   - **`file_byte_write`** — entry `DE = FCB ptr`, `A = byte`; buffers the byte into the FCB-associated DMA buffer, flushing to disk via `bdos_write_seq` when the buffer fills.
   - **`file_flush`** — entry `DE = FCB ptr`; flushes any partial-record buffered writes via `bdos_write_seq` (callable from `bdos_close_file`-wrapping logic so close implies flush).
   The "in-FCB buffer" wording from epics.md:1337 / architecture.md:392 maps to "the 128-byte DMA buffer associated with the FCB" — CP/M does not literally store the buffer inside the 36-byte FCB, but each FCB has an associated DMA region set via `bdos_set_dma`. **Decision for Story 13.1:** the antforth FCB pool reserves 8 × 128 = 1024 bytes of DMA-buffer space adjacent to (or co-located with) the `fcb_pool` block, so each FCB has a dedicated buffer. The label `fcb_dma_pool: ds 1024` (or equivalent) is added in `src/file_access.asm`. **Constant** `FCB_DMA_SIZE EQU 128` is defined; **constant** `FCB_DMA_POOL_SIZE EQU 1024` is defined. Address-arithmetic helper `fcb_dma_ptr` returns the DMA buffer address for a given FCB-index (entry: `B = FCB index 0..7`; exit: `HL = fcb_dma_pool + B * 128`). If the dev agent picks an alternative co-location (e.g., extending the 36-byte FCB record to 36+128=164 bytes per pool entry rather than two parallel arrays), the choice is documented in Completion Notes Task 3 with the rationale; either layout is acceptable provided the byte-stream impedance is correct and the binary delta is justified.

4. **Given** the pool-acquire primitive (E13-D1's allocation discipline; `architecture.md:356`),
   **when** invoked with all 8 FCBs in use,
   **then** it raises `-69 THROW` (`THROW_FCB_EXHAUSTED EQU -69` already declared at `src/constants.asm:76`; cited as ANS Forth 1994 §9.3.5). The pool is managed via either (a) a free-list bitmap (8 bits in a single byte, `1` = free, `0` = in-use) or (b) a per-slot `in_use` byte array of length 8. **Recommendation: (a) bitmap** — 1 byte total, single-byte mask/test loops, cleaner; pick (a) unless a concrete reason emerges in dev-pass. Internal primitives `pool_acquire` (returns `HL = FCB ptr` or raises -69) and `pool_release` (entry `HL = FCB ptr`, marks slot free) are exposed file-private. **`pool_init`** (called from kernel boot via the existing init chain in `src/antforth.asm`) clears the bitmap to "all free" and zeroes the FCB pool. The init call site is added to whichever cold-start ordering already initialises USER variables (locate it via `grep -n 'cold_start\|cold-start\|init_user' src/*.asm` and place `pool_init` adjacent — pick is dev-pass, recorded in Completion Notes).

5. **Given** the BDOS register-preservation history (Story 11.5.1.2 firmware fix verified clean on the probed function set 1/2/6/9/10/11 — see project memory `project_hardware_crash_audit.md`; the file-access functions 15/16/19/20/21/22/33/34/35 are **NOT** in the probed set),
   **when** the wrapper layer authors each BDOS call site,
   **then** every call is bracketed by the `BDOS_SAVE` / `BDOS_RESTORE` macro pair (`src/macros.asm:141-152`) — saves DE (IP) and BC (TOS) per the existing convention used uniformly in `src/io.asm` (lines 12-15, 63-65, 75-78, 97-100). The wrapper layer **does not** add paranoid IX/IY/shadow-register saves: the firmware fix landed 2026-04-28 (`project_hardware_crash_audit.md`), and the file-access functions are non-blocking on user input (they don't traverse the interrupt-handler path that was the original clobber mechanism) — defensive saves on these functions would be unjustified bloat per `feedback_design_upfront.md`. **However**, a one-line comment block at the top of `src/file_access.asm` documents the assumption (firmware ≥2026-04-28; functions 15/16/19/20/21/22/33/34/35 inherit the fixed BDOS contract; if the assumption turns out false, the mitigation path is to add explicit IX/IY/shadow pushes around the wrapper-internal CALL BDOS_ENTRY sites — symmetric to what would have been Story 11.5.1.1). This decision is recorded in Completion Notes Task 5; an AC #14 finding is reserved for the review case where the dev agent uncovered evidence the assumption is wrong.

6. **Given** Action Item A2 from the Epic 12 retrospective ("Stage drive-A: seed files for iz-cpm in `disk/a/`": one small file ~50–127B, one >128B file ~200–400B for cross-record + EOF tests, one `*.FTH` source file, plus an A:/B: discriminator-pair file and an A:-only file for positive-routing confirmation — `epic-12-retro-2026-05-01.md:148`),
   **when** Story 13.1's dev pass starts,
   **then** the seed files are present in `disk/a/` (currently only contains `.gitkeep`). **Story 13.1 scope** is the primary "open + read-200 + seek + read-EOF + close + delete" sanity probe (epics.md:1347-1349), so Story 13.1's drive-A: requirements are:
   - **`disk/a/HELLO.TXT`** — a file of exactly **200 bytes** of distinguishable content (recommended: the 200-byte string `"AntForth file-access sanity probe — record 1 spans 0..127, record 2 spans 128..199; this file exists to exercise byte-stream reads across the 128-byte CP/M record boundary."` truncated/padded to exactly 200 bytes; trailing `0x1A` (CP/M EOF marker) at offset 200 is **not** present — the file is exactly 200 bytes, sized as 1 full record + 72 bytes of a partial second record). The exact byte content is committed alongside the file so reads are testable byte-for-byte; the dev agent picks the literal content and records it verbatim in Completion Notes Task 6.
   - **`disk/a/SMALL.TXT`** — a sub-record file of **50 bytes** to exercise the read-EOF path within the first record. Exact content recorded in Completion Notes.
   The B:/discriminator and INCLUDE-source seed files (action items A2's full set + A3) are **deferred to Story 13.2 and Story 13.4** since Story 13.1 doesn't yet have user-facing words to test cross-drive routing or INCLUDE flow. Story 13.1 stages **only** the two A: files above — minimum scope to satisfy AC #7's harness. The remaining seed files land when the consuming stories that need them land.

7. **Given** AC #6's seed files and the internal-primitive surface from ACs #2-#4,
   **when** an internal sanity-test harness runs at this story's completion,
   **then** the harness is exposed via a single TEST_MODE-only Forth word `(FILE-IO-SANITY)` (paren-prefix per `architecture.md:438` internal-helper convention) that runs the following sequence and prints **exactly** these lines (one per step, plus the leading "Sanity:" header):
   ```
   Sanity: HELLO.TXT
   open ok
   read200 ok bytes=200 first=A last=y
   seek0 ok
   readEOF ok bytes=0
   close ok
   delete ok
   Done
   ```
   Per Action Item A6 from the Epic 12 retrospective (`epic-12-retro-2026-05-01.md:152`), the harness asserts against these specific lines — **no separate "pre-recorded reference trace" artefact is required**; the AC #7 expected output IS the oracle, removing the trace-capture circularity flagged in A6. The harness:
   - calls `pool_acquire` to take an FCB,
   - opens `A:HELLO.TXT` via `bdos_open_file` (ACQ -> populate FCB drive byte = 1, name = "HELLO   TXT"),
   - reads 200 bytes via `file_byte_read` in a counted loop, verifying first byte = `'A'` (0x41) and last byte = `'y'` (0x79) per the AC #6 content,
   - seeks back to byte 0 (via `bdos_read_rand`-with-r0=0 record reposition + cursor reset; pick the exact mechanism in dev-pass),
   - attempts to read 1 byte past EOF (set the cursor to byte 200, attempt `file_byte_read`, verify EOF signaled and `bytes=0` accumulated),
   - closes via `bdos_close_file`,
   - deletes via `bdos_delete_file`,
   - releases the FCB to the pool via `pool_release`.
   **Decision for Story 13.1:** the sanity test **deletes** the file at the end of the run so successive runs are not order-dependent. **However**, this means `disk/a/HELLO.TXT` must be re-staged before each test run. The Makefile `test-repl` target (or a new `test-file-sanity` sub-target) is responsible for re-copying the seed file from a non-mutable source location into the iz-cpm-visible `disk/a/` directory before invoking the harness. The recommended pattern is to keep the canonical seed at `tests/seed/HELLO.TXT` (committed; immutable) and have the Makefile `cp` it into `disk/a/` as a pre-step. **Alternative**: the test harness re-creates the file via `bdos_create_file` + `file_byte_write` at the start of each run, removing the Makefile copy step entirely. **Recommendation: (b) re-create at start** — self-contained, zero Makefile filesystem manipulation, exercises the create-write path as a free byproduct. The harness then deletes at end, leaving `disk/a/` clean. **Pick (b).** Updated harness output:
   ```
   Sanity: HELLO.TXT
   create ok
   write200 ok bytes=200
   close-w ok
   open ok
   read200 ok bytes=200 first=A last=y
   seek0 ok
   readEOF ok bytes=0
   close ok
   delete ok
   Done
   ```
   The sequence becomes: create (function 22), write 200 bytes via `file_byte_write` + close-flush, re-open (function 15), read 200 bytes, seek-to-zero, read-EOF, close, delete. Each step prints its line on success; on any failure, the harness prints the failed step name + the BDOS return code (e.g., `open FAIL bdos=FF`) and returns to REPL via THROW so `make test` registers a non-zero exit. The dev agent picks one alternative ((a) static-seed + Makefile-copy or (b) re-create-at-start); recommendation is (b) for the reasons given. Recorded in Completion Notes Task 7.

8. **Given** Action Item A7 from the Epic 12 retrospective ("Wire iz-cpm multi-drive invocation in Makefile" — `epic-12-retro-2026-05-01.md:153`) and the `IZCPM = iz-cpm` invocation pattern at `Makefile:12`,
   **when** the harness needs drive-A: to point to `disk/a/`,
   **then** the Makefile is edited to invoke iz-cpm with explicit drive-A: mapping. The exact iz-cpm flag syntax depends on the iz-cpm version installed (per Ant 2026-05-01: iz-cpm supports up to 26 drive letters; the canonical flag is `--disk-a <path>` or equivalent — verify against `iz-cpm --help` in dev-pass). A new top-of-Makefile variable `IZCPM_DISKS = --disk-a disk/a` (or equivalent) is added; the existing `test-repl` target (`Makefile:87`) and the new file-sanity test target both invoke `$(IZCPM) $(IZCPM_DISKS) $(TARGET)`. **Backward compatibility:** existing test-repl tests (1..852) do not need drive-A: since they don't touch file I/O — they are unaffected by the multi-drive flags being present. **Verification:** all 852 existing REPL tests continue to PASS with the new invocation (no regression caused by the iz-cpm flag addition). This is a **per-story regression gate** for AC #11.

9. **Given** AC #4's pool free-list discipline,
   **when** any wrapper holds an FCB across a BDOS call (epics.md:1351-1353: "the FCB state is well-defined — either fully opened, fully closed, or returned to the pool's free list; no intermediate leaks"),
   **then** every code path through `pool_acquire` is paired with either a `pool_release` (file closed gracefully) or a THROW that re-acquires the pool (the THROW path triggers `pool_release` via the existing CATCH/THROW unwind from Epic 11 — see `architecture.md:386` for the design intent). Story 13.1 itself does **not** implement THROW-driven cleanup of orphaned FCBs (that's Story 13.4's NFR9 concern via INCLUDE-TOP chain walk); Story 13.1's sanity harness uses a paired-acquire/release-on-success-path discipline. The harness's failure paths print the failure line and re-raise via THROW, which exits to REPL — leaving the FCB in-use is acceptable for Story 13.1 (the next harness run will re-create the file or the test infrastructure will rebuild iz-cpm state). A **WISHLIST item** is recorded for THROW-driven FCB cleanup hooking into Story 13.4's INCLUDE-TOP walk; the WISHLIST line is added to `docs/WISHLIST.md` if that file exists, else recorded in this story's Completion Notes Task 9.

10. **Given** the NFR13 BDOS allow-list audit (epics.md:1483) is the close-out gate's responsibility (Story 13.5 AC re BDOS-function-allow-list audit — epics.md:1483-1485),
    **when** Story 13.1 lands,
    **then** every BDOS call site newly added in `src/file_access.asm` is auditable via a single grep — `grep -nE 'CALL\s+BDOS_ENTRY|LD\s+C,\s*F_' src/file_access.asm` — and the resulting list is enumerated verbatim in Completion Notes Task 10 with the function number and allow-list status (`P` = on allow-list / `?` = not on allow-list — flagged for review). For Story 13.1, the expected list is exactly the 11 functions from AC #2: 15, 16, 19, 20, 21, 22, 25, 26, 33, 34, 35. All are on the NFR13 allow-list (epics.md:1483 lists them explicitly); the audit should produce all `P` rows. Any `?` row is a story-level blocker.

11. **Given** `make test-repl` 852 PASS / 0 FAIL post-Story-12.6 baseline (per git log `020c3c3`),
    **when** Story 13.1's edits land,
    **then** all 852 existing tests continue to PASS (zero regression — NFR9 / FR45 / FR46 enforced per-story). Pre-edit and post-edit `make test-repl` PASS counts are recorded in Completion Notes Task 11; the post-edit count is `852 + N` where `N` is the number of new tests added by the file-sanity harness. Conservative target: **N = 1 to 3** (the harness counts as a single composite test; if the dev agent splits the harness into per-step micro-tests, each step counts separately — pick is dev-pass). `make test` (assembly thread) likewise runs clean post-edit (mirror Story 12.1 Task 1.3 pattern). Any pre-existing failure is a release blocker per `feedback_standards_compliance.md`.

12. **Given** the byte-count delta budget per `architecture.md:158` ("no per-epic net-negative gate") and the post-Story-12.6 baseline (**18,230 bytes** per `wc -c build/antforth.com` 2026-05-01),
    **when** Story 13.1's build closes,
    **then** the post-edit `wc -c build/antforth.com` is recorded in Completion Notes Task 12 alongside the pre-edit baseline. **Expected envelope: +500 to +900 bytes.** Composition estimate:
    - `fcb_pool: ds 288` — exactly 288 bytes data
    - `fcb_dma_pool: ds 1024` — exactly 1024 bytes data
    - 11 BDOS-wrapper subroutines (~15-25 bytes each) — ~200 bytes code
    - `pool_acquire` / `pool_release` / `pool_init` — ~60 bytes code
    - `file_byte_read` / `file_byte_write` / `file_flush` — ~150 bytes code
    - `(FILE-IO-SANITY)` test harness + 11 string literals — ~300 bytes code+data
    - 1 byte for the free-list bitmap + ~10 bytes of EQUs / scratch USER cells
    Total estimated: **~2050 bytes.** That **exceeds** the +500..+900 envelope above. **Reconciliation:** the 1024-byte DMA pool and the 288-byte FCB pool together are **1312 bytes of static data** that dominates the delta; this is unavoidable per E13-D1's "kernel-resident static array" decision (`architecture.md:356-358`) — the architecture explicitly accepts this cost ("Cost: 288 bytes (8 × 36) added to the `.COM` binary — negligible" per :358; the 1024-byte DMA-pool cost was implicit in the byte-stream impedance design at :392-394 but not enumerated). **Revised envelope: +1800 to +2200 bytes** (data + code), with the 1312-byte data-region cost called out explicitly. Per Lesson 12-C (`epic-12-retro-2026-05-01.md:88`: "tight per-story byte budgets ratchet even when overshot"), the budget is recorded honestly — overshoots tracked as sizing-data, not failures. Any delta beyond +2400 bytes warrants explicit justification in Completion Notes Task 12. Per Lesson 12-B (per-definition saved-state slots), AC #4's bitmap pick (single-byte free-list) is the per-pool-slot saved-state generalisation foreshadowing Story 13.4's INCLUDE-TOP frame discipline.

13. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect") and the project-memory note that Epic 13 (capstone) reviews are unlikely to be clean (`architecture.md:569`),
    **when** Story 13.1's review runs,
    **then** **at least 2-3 LOW/MEDIUM findings are expected** (the "ninth consecutive epic" review-yield trend per Epic 12 retro Lesson 5 — `epic-12-retro-2026-05-01.md:92`). Likely candidates the review must probe:
    - **(a) BDOS register-preservation assumption** — AC #5's "no defensive IX/IY/shadow saves on the file-access functions" is an *assumption*, not a measured verdict. Has anyone run PROBE.COM against functions 15/16/19/20/21/22/33/34/35 on real MicroBeast post-firmware-fix? If not, the review either flags it as a gap (LOW: assumption-without-measurement; mitigation = a follow-up firmware-probe story) or accepts it on the strength of the interrupt-handler-path argument (the file-access functions are non-blocking on user input). The review should pick one and document.
    - **(b) FCB layout drift** — The CP/M 2.2 36-byte FCB has well-defined field offsets (drive at +0; name 8 bytes at +1; ext 3 bytes at +9; ex/s1/s2/rc at +12..+15; data 16 bytes at +16; cr at +32; r0/r1/r2 at +33..+35). The review verifies that any FCB-field-access constants in `src/file_access.asm` (e.g., `FCB_DRIVE EQU 0`, `FCB_NAME EQU 1`, `FCB_R0 EQU 33`) match the CP/M 2.2 spec. A single off-by-one would corrupt every file operation silently.
    - **(c) DMA-buffer aliasing** — Each FCB's associated DMA buffer must be set via `bdos_set_dma` (function 26) before each `bdos_read_seq` / `bdos_write_seq` call — CP/M's DMA pointer is a **process-global** state (one DMA address active at any time, not per-FCB). The review verifies that every `bdos_read_seq` / `bdos_write_seq` call site is preceded by a `bdos_set_dma` call pointing at the FCB's associated buffer slot. Missing the `bdos_set_dma` call would silently read into / write from whatever DMA address was last set (likely the wrong FCB's buffer).
    - **(d) Pool-bitmap initialisation** — The `pool_init` call must happen at cold start *before* any harness invocation. The review verifies the call site placement and that the bitmap is zero-initialised correctly (all 8 bits set to "free"). A 0xFF byte (initial RAM state on emulators) is "all free" by the recommended bitmap convention; a 0x00 byte (BSS-zeroed RAM) is "all in-use" — pick one and stick with it; document the choice in Completion Notes Task 4.
    - **(e) Citation discipline** — Per CCD-3 / NFR17, every BDOS function reference carries an inline function-number citation. Verified via `grep -nE 'BDOS|F_OPEN|F_CLOSE|F_READ|F_WRITE' src/file_access.asm`; every match should have a function-number mention nearby (within ~3 lines).
    - **(f) Test harness output exactness** — The 11 expected lines from AC #7 must match byte-for-byte. The Makefile assertion (added in AC #11) must use either `grep -F` (literal match) or `diff` against a fixture. A loose match (e.g., `grep -q 'Done'`) would silently let regressions through.
    - **(g) Seed file content preservation across git** — Binary content (or near-binary like the 200-byte HELLO.TXT) committed to git must not be CRLF-mangled or trailing-whitespace-stripped by editor / pre-commit hooks. Add `.gitattributes` rule for `disk/a/*.TXT binary` if needed, or stage the seed via the AC #7 (b) "re-create at start" path which sidesteps the issue. The (b) recommendation in AC #7 already handles this; if the dev agent picks (a), the review verifies the .gitattributes guard.
    - **(h) iz-cpm flag stability** — The `--disk-a` flag (or whatever AC #8 picks) is a runtime contract with iz-cpm; an iz-cpm version bump that renames the flag would silently break `make test-repl`. Add a top-of-Makefile comment documenting the iz-cpm version tested against (e.g., `# Verified against iz-cpm vX.Y.Z 2026-05-DD`) so future maintainers know which flag-syntax era the Makefile assumes.

    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Story 12.1 Task 10 / Stories 11.5.2-11.5.7 review-log discipline). Recorded in Completion Notes Task 13.

14. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 12.1 AC #14, Story 11.5.5 AC #12),
    **when** small in-pass refinements are warranted (additional grep-driven scrubs, polished comment phrasing, one-line cross-reference adjustments, reconciliation of the AC #5 BDOS-preservation assumption against any new evidence),
    **then** they are landed inside this story — no spawning further sub-stories. The exception: if the review surfaces **measured** evidence that file-access BDOS functions clobber IX/IY/shadow on real hardware (e.g., a follow-up PROBE.COM run extended to functions 15/16/...), HALT and flag it as a finding for the project lead before adding defensive saves — the change becomes a separate decision (a Story 13.1.1 "file-access defensive saves" if the project lead approves, mirror of the 11.5.1.1 dormant-then-spawned pattern). Documented in Completion Notes Task 14.

15. **Given** Action Item A1 from the Epic 12 retrospective ("Document TIB-128 limit for REPL test authors with the split-`printf` idiom" — `epic-12-retro-2026-05-01.md:147`),
    **when** Story 13.1 introduces new REPL-piped tests (the file-sanity harness invocation),
    **then** the test author(s) split any line longer than 127 bytes into multiple `printf %s\r\n` arguments per the documented idiom. Story 13.1's specific case: invoking `(FILE-IO-SANITY)` is a short token (~16 bytes) so the split-printf idiom may not be needed, but if the dev agent wants to inline the seed-file content as a Forth literal during create (the AC #7 (b) path), that string is ~200 bytes — well over TIB-128 — so the in-source authoring of the harness MUST chunk the content into multiple `S" ..."` segments concatenated via `MOVE` or written byte-by-byte rather than as one long `S"`. **Note**: this is an *internal authoring* concern in `src/file_access.asm`, not a REPL-piped concern — `S"` in assembly is built byte-by-byte at assembly time and TIB-128 doesn't apply to assembly-time strings. The TIB-128 limit applies only to *runtime REPL input*. The test invocation `(FILE-IO-SANITY)` itself is short and unaffected. AC #15 is recorded as satisfied for Story 13.1 because the test invocation is short; the action item is fully landed when a longer-than-TIB-128 REPL test is needed (Story 13.2 forward). Recorded in Completion Notes Task 15.

16. **Given** Epic 13 is the **first** story in the Epic 13 sequence and `epic-13: backlog` at `sprint-status.yaml:190`,
    **when** Story 13.1 is created via `create-story`,
    **then** `epic-13` flips `backlog → in-progress` automatically per the create-story workflow's first-story-in-epic convention (see `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:96`); `13-1-…` flips `backlog → ready-for-dev` at create-story-finalize and progresses through `in-progress → review → done` per the dev-story workflow. Recorded in Completion Notes Task 16.

17. **Given** Action Item A5 from the Epic 12 retrospective ("Mid-epic hardware smoke cadence for Epic 13" — `epic-12-retro-2026-05-01.md:151`: project lead 2026-05-01 *"yep, I love on-hardware testing!"*),
    **when** Story 13.1 closes review,
    **then** the build is transferred to real MicroBeast and the sanity harness is run from the REPL (paste the invocation; observe the 11 expected lines). The MicroBeast hardware smoke records:
    - hardware build path used,
    - the seed-file staging mechanism (per AC #7 (b), the harness re-creates the file at start, so the only hardware staging is the antforth `.COM` itself; no separate disk-image rebuild needed for Story 13.1's harness — the file is created on B: at runtime),
    - the hardware transcript path (recommended: `~/Downloads/bestialitty-13-1-YYYYMMDD-HHMMSS.bin`),
    - PASS/FAIL verdict against the 11-line expected output.
    The hardware run is **per-story for Epic 13** (not just at Story 13.5), per A5. **Note for hardware:** A: on MicroBeast is firmware ROM (read-only); the harness must target B: not A: on hardware. The harness's hardcoded `A:HELLO.TXT` would fail on hardware. **Decision:** AC #7's harness uses the **current default drive** (BDOS function 25 `bdos_get_drive` returns it) rather than a hardcoded `A:` — both iz-cpm and hardware then behave identically (iz-cpm's default is whatever drive iz-cpm's invocation flags select; hardware's default is B:). The seed filename `HELLO.TXT` (no drive prefix) inherits the default drive. The AC #7 expected output lines are unchanged. Recorded in Completion Notes Task 17.

## Tasks / Subtasks

- [ ] **Task 1 — Pre-edit baseline + grep evidence (AC: #11, #12, #16)**
  - [ ] 1.1 `wc -c build/antforth.com` — record post-Story-12.6 baseline. Expected: **18,230 bytes** per 2026-05-01 measurement. Verify; investigate any deviation.
  - [ ] 1.2 `make test-repl` — record total PASS / FAIL. Expected: **852 PASS / 0 FAIL** per Story 12.6 close-out. Investigate any pre-existing failure (release blocker per `feedback_standards_compliance.md`).
  - [ ] 1.3 `make test` (assembly thread) — record clean / fail outcome. Expected: clean (groups 1–6 expected output match per `Makefile:69-85`).
  - [ ] 1.4 `grep -nE 'BDOS|fcb|FCB' src/*.asm | grep -v 'src/file_access.asm'` — verify zero pre-existing FCB references outside the new file (Epic 13 is greenfield per Story 13.1 explore findings).
  - [ ] 1.5 `ls disk/a/ disk/b/ 2>&1` — record current `disk/` state. Expected: `disk/a/` and `disk/b/` may not exist yet; only `disk/.gitkeep` is present.
  - [ ] 1.6 `iz-cpm --help 2>&1 | grep -iE 'disk|drive'` — record the iz-cpm flag syntax for multi-drive invocation. The exact flag name informs AC #8's Makefile edit.

- [ ] **Task 2 — Create `src/file_access.asm` with FCB pool and constants (AC: #1, #3, #4)**
  - [ ] 2.1 Create `src/file_access.asm` with the file-header comment block (mirror existing `src/*.asm` headers — file purpose, AntForth attribution, Story 13.1 cross-reference, BDOS register-preservation assumption note per AC #5).
  - [ ] 2.2 Define `FCB_SIZE EQU 36` with citation `; CP/M 2.2 BDOS spec — FCB is 33-byte open-form + 3-byte random-record extension`.
  - [ ] 2.3 Define `FCB_POOL_COUNT EQU 8` with citation `; architecture.md:356 — E13-D1 (kernel-resident static array, 8 FCBs)`.
  - [ ] 2.4 Define `FCB_DMA_SIZE EQU 128` with citation `; CP/M 2.2 BDOS — sequential read/write transfers 128 bytes per record`.
  - [ ] 2.5 Define `FCB_DMA_POOL_SIZE EQU 1024` with citation `; FCB_POOL_COUNT * FCB_DMA_SIZE = 8 * 128`.
  - [ ] 2.6 Define FCB-field offset constants per the CP/M 2.2 spec: `FCB_DRIVE EQU 0`, `FCB_NAME EQU 1` (8 bytes), `FCB_EXT EQU 9` (3 bytes), `FCB_EX EQU 12`, `FCB_S1 EQU 13`, `FCB_S2 EQU 14`, `FCB_RC EQU 15`, `FCB_DATA EQU 16` (16 bytes — internal), `FCB_CR EQU 32`, `FCB_R0 EQU 33`, `FCB_R1 EQU 34`, `FCB_R2 EQU 35`. Each carries a one-line citation.
  - [ ] 2.7 Declare `fcb_pool: ds FCB_POOL_COUNT * FCB_SIZE` (= 288 bytes).
  - [ ] 2.8 Declare `fcb_dma_pool: ds FCB_POOL_COUNT * FCB_DMA_SIZE` (= 1024 bytes). Place adjacent to `fcb_pool` per AC #3 layout pick (the parallel-arrays form). If the dev agent picks the alternative (extending each FCB record to 36+128 = 164 bytes), document in Completion Notes Task 2.8.
  - [ ] 2.9 Declare `fcb_pool_bitmap: db 0xFF` (single-byte free-list bitmap; `1` = free per AC #4 recommendation; initial `0xFF` = all 8 slots free). Add citation comment.
  - [ ] 2.10 INCLUDE `src/file_access.asm` from `src/antforth.asm` (place per the Story 12.1 pattern — after bootstrap, before tests-INCLUDE). Verify the assembled binary's symbol table emits `fcb_pool`, `fcb_dma_pool`, and `fcb_pool_bitmap` at expected addresses (sjasmplus map file).

- [ ] **Task 3 — Pool acquire / release / init primitives (AC: #4)**
  - [ ] 3.1 Implement `pool_init`: clears `fcb_pool_bitmap` to `0xFF`; zeroes `fcb_pool` (`LD HL, fcb_pool` / `LD DE, fcb_pool+1` / `LD BC, FCB_POOL_COUNT*FCB_SIZE-1` / `LDIR` pattern); zeroes `fcb_dma_pool` likewise. ~20 bytes code.
  - [ ] 3.2 Wire `pool_init` into the kernel cold-start chain. Locate the cold-start init sequence (`grep -n 'cold_start\|init_user\|user_init' src/*.asm`); add a `CALL pool_init` adjacent. Document the chosen call site in Completion Notes Task 3.2.
  - [ ] 3.3 Implement `pool_acquire`: scans `fcb_pool_bitmap` for the first set bit; if none, raises `THROW_FCB_EXHAUSTED` (-69) via the standard THROW path; if found, clears the bit, computes the FCB's address (`HL = fcb_pool + index * 36`), and returns `HL = FCB ptr`, `B = index` (caller may need the index for `fcb_dma_ptr`). ~30 bytes code.
  - [ ] 3.4 Implement `pool_release`: takes `HL = FCB ptr`; computes the index (`(HL - fcb_pool) / 36`); sets the corresponding bit in `fcb_pool_bitmap`; zeros the FCB record (so successive opens start clean). ~25 bytes code.
  - [ ] 3.5 Implement `fcb_dma_ptr`: takes `B = FCB index 0..7`; returns `HL = fcb_dma_pool + B * 128` (a left-shift-by-7 trick — `LD H, 0` / `LD L, B` / 7× `ADD HL, HL` — or table lookup; pick the cheapest). ~10 bytes code.

- [ ] **Task 4 — BDOS wrapper helpers (AC: #2, #5, #10)**
  - [ ] 4.1 Add BDOS-function-number EQUs to `src/constants.asm` (after the existing `C_*` block at lines 9-14). New EQUs: `F_OPEN EQU 15`, `F_CLOSE EQU 16`, `F_DELETE EQU 19`, `F_READ EQU 20`, `F_WRITE EQU 21`, `F_MAKE EQU 22`, `F_READRAND EQU 33`, `F_WRITERAND EQU 34`, `F_SIZE EQU 35`, `DRV_GET EQU 25`, `F_DMAOFF EQU 26`. Each carries a `; CP/M 2.2 BDOS function NN — purpose` citation.
  - [ ] 4.2 Implement each wrapper subroutine per AC #2's list. Standard pattern (mirror `src/io.asm:8-17` `w_EMIT_cf`):
    ```
    bdos_open_file:                      ; ( DE = FCB ptr ) → A
            BDOS_SAVE
            LD      C, F_OPEN            ; F_OPEN (15)
            CALL    BDOS_ENTRY
            BDOS_RESTORE
            RET
    ```
    Each wrapper is **~10 bytes** (BDOS_SAVE expands to 2 bytes; LD C,n is 2 bytes; CALL is 3 bytes; BDOS_RESTORE is 2 bytes; RET is 1 byte). 11 wrappers × ~10 bytes ≈ 110 bytes total.
  - [ ] 4.3 Implement `file_byte_read` (AC #3 byte-stream impedance). Accesses the per-FCB DMA buffer; tracks the cursor via `FCB_CR` (current-record byte offset, 0..127); when the cursor wraps from 127 → 0, calls `bdos_read_seq` to load the next record into the DMA buffer. EOF protocol: `CY` flag set means EOF (recommendation). ~50 bytes code.
  - [ ] 4.4 Implement `file_byte_write` (AC #3). Buffers byte into the FCB's DMA buffer; on cursor-wrap calls `bdos_write_seq`. ~50 bytes code.
  - [ ] 4.5 Implement `file_flush` (AC #3). Forces a `bdos_write_seq` if the DMA buffer has unwritten partial-record data. Called from the harness's close-write path. ~30 bytes code.

- [ ] **Task 5 — BDOS register-preservation discipline (AC: #5)**
  - [ ] 5.1 Add a top-of-file comment block in `src/file_access.asm` documenting the BDOS register-preservation assumption: "MicroBeast firmware ≥2026-04-28 preserves IX/IY/shadow across all probed BDOS functions (1, 2, 6, 9, 10, 11) per `project_hardware_crash_audit.md`. File-access functions (15/16/19/20/21/22/33/34/35) inherit the fixed BDOS contract by virtue of being non-blocking (no interrupt-handler clobber path). Wrapper layer protects only DE/BC via BDOS_SAVE/RESTORE; defensive IX/IY/shadow saves are NOT added here. If a future PROBE.COM run on the file-access function set shows clobber, see Story 13.1 AC #14 for the spawn protocol."
  - [ ] 5.2 Verify every wrapper subroutine uses `BDOS_SAVE` / `BDOS_RESTORE` (or equivalent `PUSH DE` / `PUSH BC` / `POP BC` / `POP DE` if a pattern needs an `LD A, ...` between PUSH and POP). `grep -nE 'BDOS_SAVE|BDOS_RESTORE|CALL\s+BDOS_ENTRY' src/file_access.asm` — every CALL BDOS_ENTRY should sit between a SAVE/PUSH and a matching RESTORE/POP.

- [ ] **Task 6 — Seed file staging (AC: #6, #7 alternative (a))**
  - [ ] 6.1 If AC #7 (b) "re-create at start" is picked (recommended), Task 6 collapses: no static seed files needed in `disk/a/`. Skip 6.2-6.4.
  - [ ] 6.2 If AC #7 (a) "static seed + Makefile copy" is picked, create `tests/seed/HELLO.TXT` with exactly 200 bytes of pre-decided content (recorded in Completion Notes). First byte = `'A'` (0x41), last byte = `'y'` (0x79).
  - [ ] 6.3 Add `.gitattributes` rule `tests/seed/*.TXT binary` to prevent CRLF mangling.
  - [ ] 6.4 Add Makefile pre-step that copies `tests/seed/HELLO.TXT` → `disk/a/HELLO.TXT` before invoking iz-cpm.

- [ ] **Task 7 — File-sanity test harness `(FILE-IO-SANITY)` (AC: #7, #15)**
  - [ ] 7.1 Author the `(FILE-IO-SANITY)` Forth word as a TEST_MODE-only DEFCODE (or DEFWORD; pick per the implementation pattern). The word lives in `src/file_access.asm` adjacent to the wrapper layer.
  - [ ] 7.2 Per AC #7 (b): the harness performs create → write 200 bytes → close-flush → re-open → read 200 → seek0 → read-EOF → close → delete; emits each step's success line (e.g., `bdos_print_str "create ok\r\n"`) on success; raises THROW + prints the failed-step line on failure.
  - [ ] 7.3 The harness is exposed as a single Forth word that the REPL test invokes via `(FILE-IO-SANITY)` then `BYE`. Output is asserted line-by-line by the Makefile target (AC #11).
  - [ ] 7.4 The 11 expected output lines (per AC #7 (b)) are committed as a fixture file at `tests/file_access_tests.fth` (the file's content is the Forth invocation token; the expected output is documented as a comment block at the top of the file).

- [ ] **Task 8 — Makefile multi-drive iz-cpm wiring (AC: #8)**
  - [ ] 8.1 Verify iz-cpm's multi-drive flag syntax via `iz-cpm --help` (recorded in Task 1.6).
  - [ ] 8.2 Add `IZCPM_DISKS = --disk-a disk/a` (or equivalent flag) at the top of `Makefile`. Add a comment line documenting the iz-cpm version verified against (e.g., `# Verified against iz-cpm <version> 2026-05-DD`).
  - [ ] 8.3 Edit `test-repl:` to invoke `$(IZCPM) $(IZCPM_DISKS) $(TARGET)` in place of the bare `$(IZCPM) $(TARGET)` pattern at `Makefile:89` (and all subsequent `printf | $(IZCPM)` lines).
  - [ ] 8.4 Add a new target `test-file-sanity:` that pipes `(FILE-IO-SANITY)\r\nBYE\r\n` into iz-cpm with the multi-drive flags and asserts the 11 expected output lines (use `diff` against the AC #7 expected fixture, or `grep -c` on each line).
  - [ ] 8.5 Verify backward compat: all 852 existing REPL tests continue to PASS with the new flag invocation. Record pre-edit and post-edit PASS counts in Completion Notes Task 8.5.

- [ ] **Task 9 — FCB pool free-list discipline + WISHLIST entry (AC: #9)**
  - [ ] 9.1 Verify the harness's success path pairs every `pool_acquire` with `pool_release`. Static analysis: `grep -nE 'pool_acquire|pool_release' src/file_access.asm` — every acquire should have a release in the same control-flow region.
  - [ ] 9.2 Add a `WISHLIST` entry: "Story 13.4 INCLUDE-TOP THROW-walk should also walk the FCB pool free-list to release orphaned FCBs raised mid-INCLUDE. Currently FCBs are leaked on THROW-out-of-harness; this is acceptable for Story 13.1 (sanity probe re-runnable) but Story 13.4's NFR9 'no orphaned FIDs' demands the cleanup discipline." Add to `docs/WISHLIST.md` if the file exists; else record in Completion Notes Task 9.

- [ ] **Task 10 — NFR13 BDOS allow-list audit at story level (AC: #10)**
  - [ ] 10.1 Run `grep -nE 'CALL\s+BDOS_ENTRY|LD\s+C,\s*F_|LD\s+C,\s*DRV_GET' src/file_access.asm`; classify each match's BDOS function number; verify all are on the NFR13 allow-list (epics.md:1483: 1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40).
  - [ ] 10.2 Expected list: 11 functions — 15, 16, 19, 20, 21, 22, 25, 26, 33, 34, 35. All on the allow-list (`P` rows). Any `?` row blocks the gate.
  - [ ] 10.3 Record the audit table in Completion Notes Task 10.

- [ ] **Task 11 — Regression test gate (AC: #11)**
  - [ ] 11.1 Pre-edit `make test-repl`: 852 PASS / 0 FAIL (Task 1.2 baseline).
  - [ ] 11.2 Post-edit `make test-repl`: should be `852 + N` PASS / 0 FAIL where N = new file-sanity test count. Conservative N = 1 to 3.
  - [ ] 11.3 Post-edit `make test`: clean (assembly threads unaffected).
  - [ ] 11.4 If any of the 852 pre-existing tests regresses, treat as a release blocker and root-cause before close.

- [ ] **Task 12 — Byte-count delta (AC: #12)**
  - [ ] 12.1 Pre-edit `wc -c build/antforth.com`: **18,230 bytes** (Task 1.1 baseline).
  - [ ] 12.2 Post-edit `wc -c build/antforth.com`: record actual.
  - [ ] 12.3 Compute delta; reconcile against the +1800..+2200 envelope in AC #12.
  - [ ] 12.4 If delta exceeds +2400 bytes, justify in Completion Notes per `feedback_plain_qa_language.md` (state value, gate, reason).
  - [ ] 12.5 Note any size-reduction opportunities for follow-up (e.g., the 1024-byte DMA pool: could 4 FCBs share 2 buffers if usage patterns warrant? — wishlist item, not Story 13.1 scope).

- [ ] **Task 13 — Adversarial review (AC: #13)**
  - [ ] 13.1 Trigger an adversarial review pass per `feedback_adversarial_review.md`. Probe the AC #13 likely-finding list (a)-(h).
  - [ ] 13.2 Triage findings: HIGH/MEDIUM block; LOW may be accepted with rationale.
  - [ ] 13.3 In-pass-fix any findings landed (mirror Story 12.1's 3-LOW-fix close).
  - [ ] 13.4 Record findings + dispositions in Completion Notes Task 13.

- [ ] **Task 14 — In-pass-fix discipline / structural-load-bearing escalation gate (AC: #14)**
  - [ ] 14.1 Document in-pass picks made: AC #3 layout (parallel arrays vs extended FCB), AC #4 bitmap orientation (1=free vs 0=free), AC #7 (a) vs (b) seed-staging path, AC #8 iz-cpm flag syntax, AC #5 register-preservation assumption stance.
  - [ ] 14.2 If any review finding (Task 13) surfaces measured evidence file-access BDOS clobbers IX/IY/shadow, HALT and flag for project lead — do NOT add defensive saves in-pass. Spawn Story 13.1.1 if approved.

- [ ] **Task 15 — TIB-128 limit awareness (AC: #15)**
  - [ ] 15.1 Verify the REPL test invocation `(FILE-IO-SANITY)\r\nBYE\r\n` is well under TIB-128 (~16 bytes). No split needed for Story 13.1.
  - [ ] 15.2 Record AC #15 as satisfied; flag for Story 13.2 forward where longer file-content REPL inputs may surface the limit.

- [ ] **Task 16 — Sprint-status flips (AC: #16)**
  - [ ] 16.1 Verify `epic-13` is currently `backlog` at `sprint-status.yaml:190`. Flip → `in-progress` at create-story-finalize (the create-story workflow already does this).
  - [ ] 16.2 Verify `13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer` is currently `backlog` at `sprint-status.yaml:191`. Flip → `ready-for-dev` at create-story-finalize.
  - [ ] 16.3 At dev-pass close, flip → `in-progress` (dev-story workflow does this); at review close, flip → `review`; at code-review close, flip → `done`.

- [ ] **Task 17 — MicroBeast hardware smoke (AC: #17)**
  - [ ] 17.1 Build `build/antforth.com` post-edit; transfer to MicroBeast via the established mechanism (disk-image build + write to MicroBeast media).
  - [ ] 17.2 Project lead Ant runs antforth on hardware; pastes `(FILE-IO-SANITY)\r\nBYE\r\n` at the REPL; observes the 11 expected lines.
  - [ ] 17.3 Capture the transcript to `~/Downloads/bestialitty-13-1-YYYYMMDD-HHMMSS.bin`.
  - [ ] 17.4 Record verdict (PASS/FAIL) + transcript path in Completion Notes Task 17.
  - [ ] 17.5 If FAIL, root-cause before story close; the file-access-on-real-hardware path is exactly the kind of mid-epic surprise the PRD risk table called out (epics.md:1327) — treat any failure as load-bearing.

## Dev Notes

### Pre-edit grep evidence

Run before any source edits:

```
$ grep -nE '\bfcb\b|\bFCB\b' src/*.asm
# Expected: zero hits — Story 13.1 is greenfield for FCB.

$ grep -nE 'CALL\s+BDOS_ENTRY' src/*.asm
# Expected: ~10 hits, all in src/io.asm — only console I/O calls today.

$ grep -nE 'F_OPEN|F_CLOSE|F_READ|F_WRITE|F_MAKE|F_DELETE|F_DMAOFF|DRV_GET|F_READRAND|F_WRITERAND|F_SIZE' src/*.asm
# Expected: zero hits — file-access function constants don't exist yet.

$ ls disk/a/ disk/b/ 2>&1
# Expected: directories may not exist; only disk/.gitkeep is staged.

$ wc -c build/antforth.com
# Expected: 18230 (post-Story-12.6 baseline).
```

### Sjasmplus assertion idiom (mirror Story 12.1 Dev Notes)

Where two constants must agree (e.g., AC #2 sanity-checking `FCB_POOL_COUNT * FCB_DMA_SIZE = FCB_DMA_POOL_SIZE`):

```
    ASSERT FCB_POOL_COUNT * FCB_DMA_SIZE = FCB_DMA_POOL_SIZE
```

Sjasmplus emits an assembly-time error if the equality is violated. Cheap drift-detection.

### BDOS register-preservation note

Per `project_hardware_crash_audit.md` (CLOSED 2026-04-28 firmware-fix verified clean): MicroBeast firmware ≥2026-04-28 preserves shadow registers across the probed BDOS functions (1, 2, 6, 9, 10, 11). The file-access functions (15/16/19/20/21/22/33/34/35) are **not** in the probed set but are non-blocking on user input (no interrupt-handler clobber path), so the firmware fix is presumed to apply by mechanism. Story 13.1's wrapper layer relies on this presumption (AC #5); if a future PROBE.COM probe of the file-access set shows clobber, the wrapper layer must add explicit IX/IY/shadow defensive saves and a Story 13.1.1 spawns.

### Test discipline for Story 13.1

Per `feedback_repl_tests_preferred.md`, tests are REPL-piped Forth scripts, NOT assembly test threads. Story 13.1's sanity harness is exposed as a single Forth word `(FILE-IO-SANITY)` invoked from `tests/file_access_tests.fth` — the AC #7 expected output is the assertion oracle.

The harness uses TEST_MODE-only conditional assembly (mirror existing patterns in `src/tests/test_*.asm`) so the `(FILE-IO-SANITY)` word is **not** present in the production binary. Verify via `grep -nE 'FILE-IO-SANITY' build/antforth.com` (string search on production binary returns zero hits; on test binary returns one or more hits).

### Register-convention pick

The wrapper subroutines follow the established `src/io.asm` convention: caller passes `DE = FCB ptr` (mirror BDOS's own contract); on return, `A = BDOS result code`. The TOS-in-register discipline (BC = TOS) is preserved by `BDOS_SAVE` / `BDOS_RESTORE`. The wrappers are **internal** subroutines (not Forth words), so they don't follow the Forth-word entry/exit conventions — they're plain Z80 subroutines.

User-facing words (`OPEN-FILE`, etc.) land in Story 13.2 and adapt to the Forth-word stack-effect contracts.

### Project Structure Notes

- New file `src/file_access.asm` lives alongside other phase-2 additions (`src/wordlists.asm` from Epic 12; `src/exception.asm` from Epic 11; etc.). Per `architecture.md:703`.
- New test file `tests/file_access_tests.fth` lives alongside other phase-2 test files (`tests/wordlist_tests.fth`, etc.). Per `architecture.md:724`.
- `src/constants.asm` is edited in-place to add the F_* and DRV_GET function-number EQUs. Per `architecture.md:680`.
- `Makefile` is edited to add the multi-drive iz-cpm invocation. The new `test-file-sanity` target lands as part of the existing `test-repl` chain or a peer target.
- No edits to `src/io.asm`'s existing console-I/O code (Story 13.1 doesn't migrate console I/O to the file-access wrapper layer; the architecture.md:686 "factor BDOS helpers" note is a *future* refactor opportunity, not Story 13.1 scope).

### References

- [Source: epics.md:1319-1357 — Story 13.1 acceptance criteria]
- [Source: architecture.md:354-358 — E13-D1 file-handle representation (FCB pool decision)]
- [Source: architecture.md:360-388 — E13-D2 INCLUDE source-input nesting (background, not Story 13.1 scope)]
- [Source: architecture.md:390-394 — E13-D3 BDOS wrapper abstraction level]
- [Source: architecture.md:438 — Internal helper word `(paren)` convention]
- [Source: architecture.md:472-483 — Standards-citation comment format (CCD-3 / NFR17)]
- [Source: architecture.md:541-546 — Error-raising via THROW (phase-2 discipline)]
- [Source: architecture.md:565-569 — Adversarial review on capstone epics]
- [Source: epics.md:1483 — NFR13 BDOS function allow-list]
- [Source: epic-12-retro-2026-05-01.md:147-156 — Epic 13 prep action items A1-A9]
- [Source: epic-12-retro-2026-05-01.md:88-92 — Lesson 12-C tight per-story budgets ratchet]
- [Source: project memory `project_hardware_crash_audit.md` — BDOS register-preservation context (firmware fix CLOSED 2026-04-28)]
- [Source: project memory `feedback_design_upfront.md` — design extensible encodings for full scope on day one]
- [Source: project memory `feedback_repl_tests_preferred.md` — Epic 3+ tests are REPL-piped Forth]
- [Source: project memory `feedback_adversarial_review.md` — reviews MUST find things]
- [Source: project memory `feedback_systematic_reference_check.md` — grep is the source of truth, not memory]
- [Source: project memory `feedback_plain_qa_language.md` — state measured value, gate, reason plainly]
- [Source: src/macros.asm:141-152 — BDOS_SAVE / BDOS_RESTORE macro definitions]
- [Source: src/constants.asm:9-14 — Existing console-I/O BDOS function EQUs (template for new F_* EQUs)]
- [Source: src/constants.asm:76 — THROW_FCB_EXHAUSTED EQU -69 (already declared)]
- [Source: src/io.asm:8-17 — Reference BDOS-call wrapper pattern (w_EMIT_cf)]
- [Source: Makefile:12 — IZCPM = iz-cpm invocation]
- [Source: Makefile:87-89 — test-repl target (template for new file-sanity target)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

### Completion Notes List

### File List
