# Story 12.1: Wordlist struct + hash parameterisation + `FORTH-WORDLIST` bootstrap

Status: done

## Change Log

- 2026-04-29 — Dev pass complete. New file `src/wordlists.asm` + relocated FORTH-WORDLIST struct emission. 9 live `LD hash_table` references renamed to `LD forth_wordlist + WORDLIST_BUCKET0` across `src/{dictionary,compiler,system,inner_interpreter,assembler}.asm`. `HASH_BUCKETS` retired; `WORDLIST_BUCKETS` is the sole source of truth. New file `tests/wordlist_tests.fth` + 5 new Makefile REPL tests (802–806). Binary delta +2 bytes (within +0..+20 envelope). REPL tests 815/0 (= 810 baseline + 5 new). Asm tests PASS. Status: ready-for-dev → review.
- 2026-04-29 — Code review pass complete. Fixed 3 LOW findings in-pass: (R1) added `ASSERT WORDLIST_BUCKETS = 64` in `src/wordlists.asm` plus drift-warning comments in `src/macros.asm:9,54` and `src/hash.asm:30` (literals stay because the LUA table init runs before `wordlists.asm` is INCLUDEd, but the assertion catches future drift); (R2) `tests/wordlist_tests.fth` `\ expect:` comments rewritten to mirror the actual Makefile assertion strings per test; (R3) the dangerous `: TWGHOST [']  TWBAR ;` documentation snippet replaced with safe `\`-prefixed line comments. Binary unchanged at 17,543 bytes. REPL tests 815/0; asm tests clean. Status: review → done.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an antforth maintainer,
I want the per-wordlist 130-byte struct defined, the dictionary hash lookup parameterised on a wordlist-struct address, and the existing flat dictionary migrated to live inside a canonical `FORTH-WORDLIST`,
so that the kernel has a working multi-vocabulary infrastructure before any user-facing wordlist words are introduced (FR28 delivered; FR23–FR29, FR31 unblocked — FR30 withdrawn 2026-04-27).

## Acceptance Criteria

1. **Given** E12-D1's layout (2-byte next-wordlist chain pointer + 64-entry × 2-byte hash-bucket array; `architecture.md:326-330`),
   **when** the kernel boots,
   **then** a pre-built `FORTH-WORDLIST` struct exists in known-address kernel memory, populated with all existing kernel primitives' dictionary entries across its 64 buckets (i.e., the assembly-time LUA `_hash_buckets` table from `src/macros.asm:7-12` populates the FORTH-WORDLIST struct's bucket array, not a separate global table). The struct's next-wordlist chain link is initialised to `0` (FORTH-WORDLIST is the canonical end of the chain). The pre-built struct's address is exported via an assembler symbol — proposed `forth_wordlist:` — referenceable by other source files at link time.

2. **Given** `src/hash.asm`'s lookup primitive,
   **when** the XOR-rotate 64-bucket lookup is refactored,
   **then** dictionary lookup takes a wordlist-struct address as a parameter (per register conventions — see Dev Notes "Register-convention pick"), and hashes into *that* struct's bucket array. **No global fixed bucket table label remains as a callable destination** — the legacy label `hash_table` either (a) is renamed to `forth_wordlist + 2` arithmetic at every call site, or (b) survives only as an `EQU forth_wordlist + 2` alias; in either case, every site that today reads `hash_table[bucket]` either passes a `wid` argument or computes the bucket address relative to a `wid`. Verified by `grep -n 'hash_table' src/*.asm` returning either zero hits or only the `EQU` alias line in `src/wordlists.asm`. The pure `hash_name` subroutine itself (`src/hash.asm:14-31`) may keep its current `(name, length) -> bucket index in A` signature — it is *not* required to internalise the wordlist-struct addressing — provided the parameterisation is done at the call sites or in a thin helper.

3. **Given** `src/dictionary.asm` (FIND, WORDS), `src/compiler.asm` (`build_header`, COMP-ERROR), `src/system.asm` (MARKER), `src/inner_interpreter.asm` (DOMARKER), and `src/assembler.asm` (asm_unlink_labels + CODE-rollback path),
   **when** word insertion / lookup / unlink runs,
   **then** every site that today operates on the global `hash_table` operates on FORTH-WORDLIST's bucket array via the AC #2 parameterisation. For Story 12.1, the wid is hard-wired to FORTH-WORDLIST at every call site (no user-facing wordlist control yet — that is Story 12.2 and onwards). No more hard-wired single-table assumptions remain in any of these files. **Specific call sites to migrate** (verified via the grep evidence in Dev Notes "Pre-edit grep evidence"):
   - `src/dictionary.asm:47-48` (FIND bucket-head load)
   - `src/dictionary.asm:166-167` (WORDS bucket-array walk; also touches `HASH_BUCKETS` constant — see AC #5 on the constant)
   - `src/compiler.asm:215-220` (build_header bucket-head update)
   - `src/compiler.asm:438-440` (COMP-ERROR rollback bucket-head restore)
   - `src/system.asm:51-72` (MARKER snapshot — see AC #6 on the byte-count question)
   - `src/inner_interpreter.asm:134-137` (DOMARKER restore — paired with AC #6)
   - `src/assembler.asm:427-432` (CODE-mode error rollback bucket-head restore)
   - `src/assembler.asm:839-850` (asm_unlink_labels per-slot bucket-head restore)
   - `src/assembler.asm:2345` (comment reference to `hash_table[0]`; update to match the rename)

4. **Given** the kernel at boot,
   **when** FORTH-WORDLIST is the only wordlist in the (implicit-for-Story-12.1) search order,
   **then** every pre-Epic-12 word is findable exactly as before — zero lookup regression for the single-wordlist case. NFR9 (`make test-repl` 810 PASS / 0 FAIL post-Story-11.5.7 baseline; `make test` clean) is verified as a per-story gate, with the full multi-vocab envelope deferred to Story 12.6 (CCD-4 close-out gate). Pre-edit and post-edit `make test-repl` PASS counts are recorded in Completion Notes Task 1 and must be identical (any new wordlist-test additions per AC #7 are recorded as the explicit + delta).

5. **Given** new file `src/wordlists.asm`,
   **when** the struct and supporting macros are defined,
   **then** the file declares (at minimum):
   - `WORDLIST_SIZE EQU 130` — citation: `; architecture.md:328 — E12-D1 (2-byte next link + 64×2-byte buckets)`
   - `WORDLIST_BUCKETS EQU 64` — citation: `; architecture.md:328 — E12-D1; matches HASH_BUCKETS (src/constants.asm:21)`
   - layout-offset constants for the struct fields, e.g., `WORDLIST_NEXT EQU 0` (next-wordlist chain link offset), `WORDLIST_BUCKET0 EQU 2` (first bucket offset). The dev agent picks the exact constant names but documents them in Completion Notes Task 5; future stories (12.2, 12.3, 12.4) consume these constants by name, so they must be readable.
   - The `forth_wordlist:` symbol itself, with the assembly-time LUA expansion of the bucket array (lifted from `src/antforth.asm:202-207`). The 2-byte `DW 0` next-link cell precedes the LUA `for i = 0, 63` loop.
   - **Sanity self-check** at assembly time: an `IF WORDLIST_BUCKETS != HASH_BUCKETS / ASSERT / ENDIF` guard (sjasmplus syntax — see Dev Notes "Sjasmplus assertion idiom") ensures the legacy `HASH_BUCKETS` and the new `WORDLIST_BUCKETS` cannot drift apart. (If the legacy `HASH_BUCKETS` is retired in this story per AC #5(d), the guard is omitted.)
   - **(d) `HASH_BUCKETS` retirement decision.** `src/constants.asm:21` defines `HASH_BUCKETS EQU 64`, used at `src/dictionary.asm:167` (WORDS bucket-array walk). The dev agent picks one of: (i) retire `HASH_BUCKETS` entirely and use `WORDLIST_BUCKETS` everywhere (cleanest; +1 file edit but eliminates the duplication risk), or (ii) keep both as aliases (`HASH_BUCKETS EQU WORDLIST_BUCKETS` or vice versa) and add the assertion guard above. Recommendation: **(i) retire** — single source of truth per `feedback_design_upfront.md`; the constant has only one consumer. Recorded in Completion Notes Task 5(d).

6. **Given** MARKER (`src/system.asm:23-86`) and DOMARKER (`src/inner_interpreter.asm:114-145`) currently snapshot/restore exactly 128 bytes (the global `hash_table` bucket array — see `src/system.asm:56` `LD BC, 128` and `src/inner_interpreter.asm:136` `LD BC, 128`),
   **when** Story 12.1 lands,
   **then** the MARKER body layout `[saved_here(2)][saved_hash_table(128)]` is **preserved unchanged** — the byte count stays at 128 bytes (snapshotting only FORTH-WORDLIST's 64-entry bucket array, *not* including the next-wordlist link cell). Rationale: (a) Story 12.1 has only one wordlist (FORTH-WORDLIST), so the next-wordlist link is always `0` and snapshotting it is a no-op; (b) preserving the body byte-count means any markers created post-Story-12.1 are byte-compatible with the pre-Epic-12 MARKER body layout, minimising the binary delta and keeping the change reversible; (c) full-graph MARKER (snapshot ALL wordlists + their bucket arrays + the search-order array + CURRENT) is a future-story concern (proposed Story 12.5 or a deferred Epic-12 close-out item) — **not in Story 12.1's scope**. The source-rewrite is purely the swap from `LD HL, hash_table` → `LD HL, forth_wordlist + WORDLIST_BUCKET0` (or equivalent per the AC #2 renaming pick); no logic change. Recorded in Completion Notes Task 6 with the byte-count audit (post-edit `LD BC, 128` lines re-verified).

7. **Given** new file `tests/wordlist_tests.fth`,
   **when** it runs at this story's completion via the Makefile's REPL-test target,
   **then** the file exists with at minimum a smoke test that confirms FORTH-WORDLIST behaviour through the regression net: defining a word, looking it up via FIND, executing it, MARKER-rolling it back, and re-confirming it is gone. (FORTH-WORDLIST is implemented as a user-facing word in Story 12.3; for Story 12.1 the test cannot push the `wid` directly via `FORTH-WORDLIST` — see Dev Notes "Test discipline for Story 12.1" for the workaround options.) The Makefile is updated to include the new test file in `make test-repl`. Per-story PASS-count delta is recorded in Completion Notes Task 7. Conservative test target: **+3 to +5 new tests** (mirror Stories 11.5.2 / 11.5.3 / 11.5.6 in-story test additions); the heavy multi-wordlist coverage lands in Stories 12.2-12.5.

8. **Given** the `feedback_systematic_reference_check.md` discipline ("'Complete X' story specs must cross-reference the authoritative manual, not enumerate from memory"),
   **when** the dev agent surveys the residual `hash_table` references for AC #3,
   **then** the survey command is run literally — `grep -nE '\bhash_table\b' src/*.asm src/tests/*.asm` — and the full output is classified line-by-line, **not** enumerated from memory. The dev agent does NOT skim the AC #3 list above and assume it is exhaustive — the grep is the source of truth. Any line found in the grep that is not in the AC #3 list above is investigated and either added to the AC #3 list (in-pass amendment) or scrubbed in-pass. Documented in Completion Notes Task 8.

9. **Given** `src/assembler.asm`'s 3 raw-`hash_table` references (`:427`, `:844`, `:2345`),
   **when** the rename lands,
   **then** the references are updated mechanically (the assembler subsystem is **unchanged** in Phase 2 per `architecture.md:677` and the 2026-04-27 rollback — no opcode-word migration, no ASSEMBLER wordlist activation, no auto-activation hooks). The opcode words remain kernel-resident in FORTH-WORDLIST exactly as they do today; only the bucket-array address arithmetic changes. The Story 10.7 asm-`#` dispatch hack (per `project_asm_hash_dispatch_hack.md`) is **untouched** — its in-FORTH-WORDLIST registration is unaffected by the Story-12.1 rename. Recorded in Completion Notes Task 9 as a sanity check.

10. **Given** the `feedback_adversarial_review.md` discipline ("reviews MUST find things; absence of findings is suspect"),
    **when** Story 12.1's review runs,
    **then** **at least 1-2 LOW/MEDIUM findings are expected**. Likely candidates the review must probe:
    - **(a) `hash_table` orphan reference** — Did the rename hit every site? Re-run AC #8's grep independently and cross-check against the dev agent's classification — at least one mismatch (a hit not in the dev's classified list, or vice versa) is expected if the grep is being used honestly.
    - **(b) MARKER byte-count drift** — Per AC #6, the body layout stays at 128 bytes. The review verifies `grep -nE 'LD BC, 128' src/{system,inner_interpreter}.asm` returns exactly the pre-edit set of lines (typically 2). Any new-128 line or removed-128 line is investigated.
    - **(c) FORTH-WORDLIST struct address consumer audit** — `grep -n 'forth_wordlist' src/*.asm` enumerates every consumer; verify that all the AC #3 sites use the same symbol (no typos like `forth_wordlist` vs `forth_wordlist_buckets` vs `FORTH_WORDLIST`); a single canonical symbol per `feedback_systematic_reference_check.md`.
    - **(d) Next-wordlist link initialisation** — The `DW 0` cell at offset `WORDLIST_NEXT` must be present in the assembled binary at the start of the FORTH-WORDLIST struct. Verified by reading the binary at `forth_wordlist:` (sjasmplus map file lookup) — the first two bytes are `00 00`. If a future Story 12.2 `WORDLIST` allocates a new struct without zero-initialising the bucket array, that's a future bug — but Story 12.1 only has the kernel-resident FORTH-WORDLIST, so the assembly-time `DW 0` is the gate.
    - **(e) Sjasmplus LUA table state at FORTH-WORDLIST emission point** — The `_hash_buckets` LUA table is populated by every `DEFCODE` / `DEFWORD` invocation during assembly passes (`src/macros.asm:75-86, 109-117`). The FORTH-WORDLIST struct's bucket-array LUA expansion (lifted from `src/antforth.asm:202-207`) must run **after** all DEFCODE/DEFWORD invocations have completed — i.e., the `forth_wordlist:` label must be placed at the same location as the current `hash_table:` label (after all `INCLUDE`s of primitives + bootstrap). Moving it earlier would emit an empty bucket array. The review verifies the struct is emitted in the data section after `INCLUDE "bootstrap.asm"` (currently at `src/antforth.asm:202` immediately following `kernel_end` doesn't apply — the data area starts at `:202` after all code includes; verify by re-reading `src/antforth.asm:147-157`). The dev agent has a choice: (i) move the struct emission to `src/wordlists.asm` and `INCLUDE` it from `antforth.asm` after bootstrap (cleanest source-organisation per `architecture.md:702`), or (ii) keep the struct emission inline in `src/antforth.asm` and put only the `EQU`s and helpers in `src/wordlists.asm` (smaller diff). Either is acceptable; the review confirms the emission ordering is correct.
    - **(f) Citation discipline preserved** — Per CCD-3 / NFR17, every standard-derived word/EQU carries a one-line citation. `WORDLIST_SIZE` and `WORDLIST_BUCKETS` cite `architecture.md:326-330` (E12-D1, internal architectural decision — not an ANS section per AC #5); the future user-facing `FORTH-WORDLIST` Forth word (Story 12.3) will cite `ANS Forth 1994 §16.6.1.1595`. Story 12.1 adds no Forth-word standards citations; it only adds architectural-decision citations. Verified by re-grepping `src/wordlists.asm` for `architecture.md:` references.

    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Stories 11.5.2 / 11.5.3 / 11.5.4 / 11.5.5 / 11.5.6 / 11.5.7 review-log discipline). Recorded in Completion Notes Task 10.

11. **Given** the `feedback_repl_tests_preferred.md` discipline (Epic 3+ tests are REPL-piped Forth, not assembly threads),
    **when** Story 12.1 adds tests,
    **then** they are REPL-piped Forth scripts in `tests/wordlist_tests.fth`, wired into the Makefile's `test-repl` target. **No new assembly test threads.** No edits to `src/tests/*.asm`. Recorded in Completion Notes Task 11.

12. **Given** the `feedback_follow_process.md` discipline ("Don't ask permission for obvious next steps; just execute the workflow"),
    **when** the dev agent encounters edge cases during the rename (e.g., the `hash_table` rename pick of (a) full-rename vs (b) `EQU` alias from AC #2; the `HASH_BUCKETS` retirement pick from AC #5(d); the struct-emission location pick from AC #10(e)),
    **then** the dev agent picks the recommended option in the relevant AC and proceeds — escalation to the project lead is reserved for the AC #14 structural-load-bearing case only. All in-pass picks are recorded in Completion Notes per the Tasks below.

13. **Given** the byte-count delta budget per `architecture.md:158` ("no per-epic net-negative gate") and Story 12.1's expected envelope (the rename is mechanical; the new file `src/wordlists.asm` adds EQUs and the FORTH-WORDLIST struct preamble; net binary delta is expected to be **+0 to +20 bytes** — the +0 case if the struct emission stays at the current `hash_table` location and only the 2-byte `DW 0` next-link is added; the +20 envelope covers per-call-site arithmetic differences if the dev agent picks the AC #2 (a) full-rename path with longer addressing modes),
    **when** the build closes,
    **then** `wc -c build/antforth.com` post-edit is recorded in Completion Notes Task 13 alongside the pre-edit baseline (post-Story-11.5.7 baseline: **17,541 bytes** per `_bmad-output/implementation-artifacts/11.5-7-…md` Task 1.1). Any delta beyond +20 bytes needs explicit justification tied to the design pick (e.g., the AC #2 full-rename with longer effective addressing); large negative deltas (more than -10 bytes) are also flagged for justification (mechanical rename should be near-neutral). Recorded plainly per `feedback_plain_qa_language.md` (state value, gate, conclusion).

14. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 11.5.5 AC #12),
    **when** small in-pass refinements are warranted (additional grep-driven scrubs surfaced during AC #8, polished comment phrasing, a one-line cross-reference adjustment),
    **then** they are landed inside this story — no spawning further sub-stories. The exception: if the AC #8 grep surfaces a `hash_table` reference in a load-bearing structural location not enumerated in AC #3 (e.g., an inline assembly fragment in a different subsystem or a docs assertion that affects build-time correctness), HALT and flag it as a finding for the project lead before scrubbing — the change becomes a separate decision, not in-pass cleanup. Documented in Completion Notes Task 14.

15. **Given** Epic 12 is the **first** story in the Epic 12 sequence and `epic-12: backlog` at `sprint-status.yaml:181`,
    **when** Story 12.1 is created via `create-story`,
    **then** `epic-12` flips `backlog → in-progress` automatically per the create-story workflow's first-story-in-epic convention (see `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:96`); `12-1-…` flips `backlog → ready-for-dev` at create-story-finalize and progresses through `in-progress → review → done` per the dev-story workflow. Recorded in Completion Notes Task 15.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline + grep evidence (AC: #4, #8, #13)**
  - [x] 1.1 `wc -c build/antforth.com` — record post-Story-11.5.7 baseline. Expected: **17,541 bytes** per Story 11.5.7 Task 1.1. Verify; investigate any deviation.
  - [x] 1.2 `make test-repl` — record total PASS / FAIL. Expected: **810 PASS / 0 FAIL** per Story 11.5.7 Task 1.4. Investigate any pre-existing failure (release blocker per `feedback_standards_compliance.md`).
  - [x] 1.3 `make test` (assembly thread) — record clean / fail outcome. Expected: clean (groups 1–6 expected output match per `Makefile:55-71`).
  - [x] 1.4 `grep -nE '\bhash_table\b' src/*.asm src/tests/*.asm` — record verbatim output as the AC #8 baseline; classify each line per AC #3's enumerated list. Note any hits NOT in AC #3 — these are scope-amendment candidates per AC #14.
  - [x] 1.5 `grep -nE 'LD BC, 128' src/{system,inner_interpreter}.asm` — record current 128-byte snapshot/restore lines (AC #6 / AC #10(b) baseline).
  - [x] 1.6 `grep -n 'HASH_BUCKETS' src/*.asm` — record current consumers (AC #5(d) baseline).

- [x] **Task 2 — Create `src/wordlists.asm` with EQUs, FORTH-WORDLIST struct, and helper(s) (AC: #1, #5)**
  - [x] 2.1 Create `src/wordlists.asm` with the file-header comment (mirror existing `src/*.asm` headers).
  - [x] 2.2 Define `WORDLIST_SIZE EQU 130` with citation `; architecture.md:328 — E12-D1 (2-byte next link + 64×2-byte buckets)`.
  - [x] 2.3 Define `WORDLIST_BUCKETS EQU 64` with citation `; architecture.md:328 — E12-D1; matches HASH_BUCKETS (src/constants.asm:21)` (or, if AC #5(d) chooses retirement of `HASH_BUCKETS`, omit the matches-clause and add the retirement reference instead).
  - [x] 2.4 Define layout-offset constants. Recommended naming:
    - `WORDLIST_NEXT EQU 0` (next-wordlist chain pointer offset)
    - `WORDLIST_BUCKET0 EQU 2` (first bucket entry offset; per-bucket stride is 2 bytes)
    Each EQU carries a citation pointing to `architecture.md:326-330`.
  - [x] 2.5 Decide AC #10(e) emission location: (i) move FORTH-WORDLIST struct emission to `src/wordlists.asm` (clean source-organisation) or (ii) keep emission inline in `src/antforth.asm` and emit only EQUs in `src/wordlists.asm`. Pick (i) recommended; record choice in Completion Notes Task 2.
  - [x] 2.6 If pick (i): emit the FORTH-WORDLIST struct at the end of `src/wordlists.asm` (so that `INCLUDE "wordlists.asm"` placement in `src/antforth.asm` controls when the LUA `_hash_buckets` table is consumed). Layout:
    ```
    forth_wordlist:
        DW 0                            ; WORDLIST_NEXT — chain end (FORTH-WORDLIST is canonical)
    forth_wordlist_buckets:             ; (optional alias / EQU forth_wordlist + WORDLIST_BUCKET0)
        LUA ALLPASS
            for i = 0, WORDLIST_BUCKETS - 1 do
                _pc(string.format("DW 0x%04X", _hash_buckets[i]))
            end
        ENDLUA
    ```
  - [x] 2.7 (Optional) Define a small helper subroutine `wordlist_bucket_addr` per AC #2's call-site simplification (input: wid in HL, bucket index in A; output: HL = &bucket_head). Inlined arithmetic at each call site is also acceptable; pick whichever yields the cleanest diff. Record choice in Completion Notes Task 2.
  - [x] 2.8 Verify `src/wordlists.asm` assembles standalone (sjasmplus syntax check via `make`).

- [x] **Task 3 — `INCLUDE` `src/wordlists.asm` from `src/antforth.asm` in correct order (AC: #1, #10(e))**
  - [x] 3.1 Read `src/antforth.asm:127-156` (current INCLUDE order).
  - [x] 3.2 Add `INCLUDE "wordlists.asm"` immediately after `INCLUDE "bootstrap.asm"` (`src/antforth.asm:155`) and before any data emission, so all DEFCODE/DEFWORD primitives have populated `_hash_buckets[]` before the FORTH-WORDLIST struct is emitted. **Critical ordering** per AC #10(e): the struct emission consumes the LUA table; if INCLUDEd too early, the bucket array emits zeros.
  - [x] 3.3 Delete the old `hash_table:` emission at `src/antforth.asm:202-207` (now relocated to `src/wordlists.asm`).
  - [x] 3.4 Verify `make` builds clean (0 errors / 0 warnings).

- [x] **Task 4 — Refactor `src/hash.asm` per AC #2 (AC: #2)**
  - [x] 4.1 Read `src/hash.asm:14-31` (`hash_name` subroutine).
  - [x] 4.2 Decide pick: (a) keep `hash_name` interface as-is `(name, length) -> bucket index in A` and parameterise at call sites; (b) replace with a wid-aware `hash_name_wid` returning `&bucket_head in HL`. Recommendation: **(a)** — minimal-diff, the pure hash function is reusable, and all 5 call sites already compute bucket addresses inline. Record decision in Completion Notes Task 4.
  - [x] 4.3 If (a): no edits to `src/hash.asm` needed (pure function unchanged); the parameterisation is at the call sites in Tasks 5–8.
  - [x] 4.4 If (b): refactor `hash_name` and update all callers; document interface in the file header.

- [x] **Task 5 — Refactor `src/dictionary.asm` (FIND, WORDS) (AC: #3)**
  - [x] 5.1 Read `src/dictionary.asm:43-48` (FIND bucket-head load).
  - [x] 5.2 Replace `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0` (or equivalent — match the rename pick). Verify the byte-count is unchanged (both are 16-bit immediates).
  - [x] 5.3 Read `src/dictionary.asm:165-167` (WORDS bucket-array walk).
  - [x] 5.4 Replace `LD HL, hash_table` → `LD HL, forth_wordlist + WORDLIST_BUCKET0`; replace `LD A, HASH_BUCKETS` → `LD A, WORDLIST_BUCKETS` (or per AC #5(d) keep `HASH_BUCKETS` if not retired).
  - [x] 5.5 Verify `make` builds clean; verify `make test-repl` PASS count is unchanged (Task 1.2 baseline).

- [x] **Task 6 — Refactor `src/compiler.asm` (build_header, COMP-ERROR) (AC: #3)**
  - [x] 6.1 Read `src/compiler.asm:215-220` (build_header bucket-head update).
  - [x] 6.2 Replace `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0`.
  - [x] 6.3 Read `src/compiler.asm:438-440` (COMP-ERROR rollback).
  - [x] 6.4 Replace `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0`.
  - [x] 6.5 Verify `make` builds clean; spot-check a `:` definition and a deliberate COMP-ERROR (define a colon with an unknown word) — the rollback should still print "WORD ?" and recover the dictionary cleanly.

- [x] **Task 7 — Refactor `src/system.asm` MARKER + `src/inner_interpreter.asm` DOMARKER (AC: #3, #6)**
  - [x] 7.1 Read `src/system.asm:51-72` (MARKER snapshot block).
  - [x] 7.2 Replace `LD HL, hash_table` (line 55) → `LD HL, forth_wordlist + WORDLIST_BUCKET0`. **Keep `LD BC, 128`** (`src/system.asm:56`) — the body byte-count stays at 128 per AC #6.
  - [x] 7.3 Read `src/inner_interpreter.asm:134-137` (DOMARKER restore).
  - [x] 7.4 Replace `LD DE, hash_table` (line 135) → `LD DE, forth_wordlist + WORDLIST_BUCKET0`. **Keep `LD BC, 128`** (line 136).
  - [x] 7.5 Spot-check MARKER + a forget-then-redefine cycle in the REPL — the dictionary state should round-trip correctly. Add a REPL-piped test if not already covered (Task 9 below).

- [x] **Task 8 — Refactor `src/assembler.asm` `hash_table` references (AC: #3, #9)**
  - [x] 8.1 Read `src/assembler.asm:425-432` (CODE-mode error rollback).
  - [x] 8.2 Replace `LD BC, hash_table` (line 427) → `LD BC, forth_wordlist + WORDLIST_BUCKET0`.
  - [x] 8.3 Read `src/assembler.asm:842-848` (asm_unlink_labels per-slot bucket-head restore).
  - [x] 8.4 Replace `LD DE, hash_table` (line 844) → `LD DE, forth_wordlist + WORDLIST_BUCKET0`.
  - [x] 8.5 Read `src/assembler.asm:2345` (comment reference to `hash_table[0]`).
  - [x] 8.6 Update comment to match the renamed symbol (purely cosmetic — keeps the comment honest).
  - [x] 8.7 Spot-check: `CODE FOO …` in the REPL with a deliberate operand error (e.g., bad bit-range per Story 11.5.6's `-272` test) — the error rollback should print correctly and the assembler should leave the dictionary clean (per Story 11.5.6's regression net).

- [x] **Task 9 — Add `tests/wordlist_tests.fth` + Makefile wire-in (AC: #4, #7, #11)**
  - [x] 9.1 Create `tests/wordlist_tests.fth`. File header comment per `tests/throw_migration_tests.fth` style (NFR17 citation discipline).
  - [x] 9.2 Add a smoke test for FORTH-WORDLIST behaviour through the regression net. Suggested coverage (3–5 tests; expand or trim per AC #7):
    - **T1 — Define + lookup + execute**: `: TWFOO 42 ; TWFOO .` → emit `42 ` (confirms `:` lands in FORTH-WORDLIST and FIND retrieves it).
    - **T2 — MARKER round-trip**: `MARKER TWMK : TWBAR 99 ; TWBAR . TWMK` → `99 ` then `TWBAR` is gone (post-MARKER `' TWBAR` should `-13 THROW` undefined-word; covered via `CATCH` per Story 11.4.1's harness).
    - **T3 — WORDS smoke**: `WORDS` runs without crash and includes a known kernel primitive (e.g., `DUP`).
    - **T4 — Pre-Epic-12 regression sentinel**: A representative one-liner from Phase-1 / Epic-9/10/11 tests passes unchanged (e.g., `1 2 + 3 = .` → `-1 `).
    - **T5 (optional)** — A FIND of the kernel's MARKER word returns a valid xt (`-1` flag for non-IMMEDIATE). Validates that bucket walk hits the right entry.
  - [x] 9.3 Update `Makefile` to include `tests/wordlist_tests.fth` in the `test-repl` target. Follow the existing pattern (mirror how `tests/throw_migration_tests.fth` is wired). Increment the test-number sequence (current top is 810 per Story 11.5.7 Task 1.4; new tests start at 811+).
  - [x] 9.4 `make test-repl` — record post-edit total PASS / FAIL. Expected: **810 + N PASS / 0 FAIL** where N = the count from Task 9.2.

- [x] **Task 10 — Systematic-reference-check honesty (AC: #8)**
  - [x] 10.1 Re-run Task 1.4's grep verbatim post-edit: `grep -nE '\bhash_table\b' src/*.asm src/tests/*.asm`. Expected post-edit: **either zero hits, or only the `EQU forth_wordlist + WORDLIST_BUCKET0` alias line in `src/wordlists.asm`** (per AC #2).
  - [x] 10.2 Cross-check against AC #3's enumeration. Any hit not in AC #3 is investigated per AC #14.
  - [x] 10.3 Recorded in Completion Notes Task 10.

- [x] **Task 11 — Adversarial self-review (AC: #10)**
  - [x] 11.1 Self-review against all six probe categories (a)-(f) from AC #10.
  - [x] 11.2 Triage findings: HIGH/MEDIUM block the gate; LOW may be accepted with rationale.
  - [x] 11.3 Record findings table in Completion Notes Task 11 (mirror Stories 11.5.4 / 11.5.5 / 11.5.6 / 11.5.7 review-log format).

- [x] **Task 12 — In-pass-fix discipline + structural-load-bearing escalation gate (AC: #12, #14)**
  - [x] 12.1 Log any in-pass fixes with one-line rationale.
  - [x] 12.2 Confirm no HALT condition triggered (no structural-load-bearing finding requiring project-lead escalation).
  - [x] 12.3 Record in Completion Notes Task 12.

- [x] **Task 13 — Binary delta + plain-language verdict (AC: #13)**
  - [x] 13.1 `wc -c build/antforth.com` post-edit. Compute delta vs Task 1.1 baseline.
  - [x] 13.2 Compose a plain-language verdict: pre-edit X bytes, post-edit Y bytes, delta Z bytes; gate "+0 to +20 envelope per AC #13"; conclusion PASS / NEEDS-JUSTIFICATION.
  - [x] 13.3 Record in Completion Notes Task 13 per `feedback_plain_qa_language.md`.

- [x] **Task 14 — Sprint-status row flip (AC: #15)**
  - [x] 14.1 At dev-pass start: flip `12-1-wordlist-…: ready-for-dev` → `in-progress` at `sprint-status.yaml:182`.
  - [x] 14.2 At dev-pass close: flip `12-1-wordlist-…: in-progress` → `review`.
  - [x] 14.3 The `review → done` flip is owned by `code-review` per the standard dev-story workflow (mirror Story 11.5.7 Task 10.4 reasoning).
  - [x] 14.4 The `epic-12: backlog → in-progress` flip is owned by `create-story` (executed at story-creation time per the workflow); verify it has happened (`sprint-status.yaml:181` should read `epic-12: in-progress` post-create-story).
  - [x] 14.5 Recorded in Completion Notes Task 14.

## Dev Notes

### Story summary

This is the **first story in Epic 12** — the kernel-side multi-vocabulary infrastructure that all subsequent Epic 12 stories depend on. **Mostly mechanical**: a new file `src/wordlists.asm` defines the per-wordlist struct shape (130 bytes; 2-byte next-wordlist chain link + 64×2-byte hash bucket array per E12-D1), the existing global `hash_table:` symbol relocates into a canonical FORTH-WORDLIST struct, and ~9 call sites across 5 files swap `hash_table` → `forth_wordlist + WORDLIST_BUCKET0`. **No user-facing words land in this story** — `WORDLIST` / `SEARCH-WORDLIST` arrive in Story 12.2; `GET-ORDER` / `SET-ORDER` / `FORTH-WORDLIST` in Story 12.3; `GET-CURRENT` / `SET-CURRENT` / `DEFINITIONS` in Story 12.4; `ONLY` in Story 12.5. The CCD-4 close-out gate is Story 12.6 (post-Story-11.5.5 redraft renumbering — formerly Story 12.7).

The regression net is the existing 810-test REPL suite (post-Story-11.5.7 baseline) plus 3-5 new wordlist-specific smoke tests in `tests/wordlist_tests.fth`. NFR2 (10% multi-vocab lookup-cycle regression budget) is **not** measured here — that's Story 12.6's gate. Story 12.1's gate is purely zero-regression on the single-wordlist path.

### Architecture decisions driving this story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§326-330 E12-D1: Per-wordlist hash table layout.** 130-byte struct = 2-byte next-wordlist chain pointer + 64×2-byte hash bucket array. Identical bucket layout to today's single hash table — just instanced per wordlist. Preserves the established XOR-rotate 64-bucket scheme.
- **§332-336 E12-D2: Search-order storage.** 16-slot fixed array in user area + `SEARCH-ORDER-DEPTH` USER variable. **Story 12.1 does NOT add this** — that is Story 12.3's scope. The lookup hard-codes FORTH-WORDLIST until the array exists.
- **§338-342 E12-D3: Wordlist identifier representation.** `wid` = raw address of the 130-byte struct. Zero-cost identifier, directly usable as a pointer to the bucket array (with a +2 offset for the next-wordlist link). FORTH-WORDLIST's wid is the assembler-symbol address `forth_wordlist`.
- **§344-348 E12-D4 (WITHDRAWN 2026-04-27).** No ASSEMBLER wordlist, no auto-activation. Story 12.1's assembler-rename touches `src/assembler.asm:427` / `:844` / `:2345` mechanically — opcode words remain in FORTH-WORDLIST as they do today; the Story-10.7 asm-`#` dispatch hack is permanent (per `project_asm_hash_dispatch_hack.md`).
- **§802-804 Integration patterns.** "Dictionary lookup is parameterised on a wordlist-struct address (Epic 12); callers pass the struct, `dictionary.asm` does the hash and linked-list walk." This is precisely Story 12.1's deliverable.

### Pre-edit grep evidence (from Task 1.4 baseline)

The current (pre-Story-12.1) `hash_table` reference set, captured at story-drafting time via `grep -nE '\bhash_table\b' src/*.asm`:

```
src/antforth.asm:83:        ; 9. Hash table is pre-populated in the binary (see hash_table below)
src/antforth.asm:202:hash_table:
src/assembler.asm:427:        LD      BC, hash_table
src/assembler.asm:428:        ADD     HL, BC                          ; HL = &hash_table[bucket]
src/assembler.asm:839:        ; Compute &hash_table[bucket]
src/assembler.asm:844:        LD      DE, hash_table
src/assembler.asm:2345:        ; uninitialised bucket=0 / old_head=0 fields and zero hash_table[0],
src/compiler.asm:84:bh_bucket_addr:      DW 0   ; Address in hash_table
src/compiler.asm:212:        CALL    hash_name                       ; A = bucket index
src/compiler.asm:215:        ; Compute bucket head address: hash_table + A*2
src/compiler.asm:219:        LD      BC, hash_table
src/compiler.asm:220:        ADD     HL, BC                          ; HL = &hash_table[bucket]
src/compiler.asm:438:        LD      BC, hash_table
src/compiler.asm:439:        ADD     HL, BC                          ; HL = &hash_table[bucket]
src/dictionary.asm:43:        ; Compute bucket head address: hash_table + A*2
src/dictionary.asm:47:        LD      BC, hash_table
src/dictionary.asm:48:        ADD     HL, BC          ; HL = &hash_table[bucket]
src/dictionary.asm:166:        LD      HL, hash_table
src/dictionary.asm:167:        LD      A, HASH_BUCKETS         ; 64
src/hash.asm:4:; Provides hash_name subroutine for dictionary lookup.
src/hash.asm:6:; function in macros.asm (forth_hash).
src/hash.asm:8:; === hash_name — Compute dictionary hash for a name string ===
src/inner_interpreter.asm:112:; Body at cf+3: [saved_here(2)][saved_hash_table(128)]
src/inner_interpreter.asm:135:        LD      DE, hash_table          ; DE = destination
src/system.asm:19:;   Body layout: [saved_here(2)][saved_hash_table(128)]
src/system.asm:55:        LD      HL, hash_table          ; HL = source
```

**Classification (live `LD` references requiring rename, vs comment-only references):**

| Site | File:line | Kind | Action |
|---|---|---|---|
| FIND bucket-head load | `dictionary.asm:47` | live `LD BC, hash_table` | rename to `forth_wordlist + WORDLIST_BUCKET0` (Task 5.2) |
| WORDS bucket-array walk | `dictionary.asm:166` | live `LD HL, hash_table` | rename (Task 5.4) |
| WORDS bucket-count | `dictionary.asm:167` | live `LD A, HASH_BUCKETS` | swap to `WORDLIST_BUCKETS` per AC #5(d) (Task 5.4) |
| build_header bucket-head update | `compiler.asm:219` | live `LD BC, hash_table` | rename (Task 6.2) |
| COMP-ERROR rollback | `compiler.asm:438` | live `LD BC, hash_table` | rename (Task 6.4) |
| MARKER snapshot source | `system.asm:55` | live `LD HL, hash_table` | rename, keep `LD BC, 128` (Task 7.2) |
| DOMARKER restore destination | `inner_interpreter.asm:135` | live `LD DE, hash_table` | rename, keep `LD BC, 128` (Task 7.4) |
| asm CODE-mode rollback | `assembler.asm:427` | live `LD BC, hash_table` | rename (Task 8.2) |
| asm_unlink_labels | `assembler.asm:844` | live `LD DE, hash_table` | rename (Task 8.4) |
| `hash_table:` definition | `antforth.asm:202` | label definition | relocate to `src/wordlists.asm` (Task 3.3) |
| Banner comment | `antforth.asm:83` | comment only | update to "FORTH-WORDLIST is pre-populated…" (mechanical comment fix) |
| `bh_bucket_addr` comment | `compiler.asm:84` | comment only | update wording (mechanical) |
| Comment in build_header | `compiler.asm:215` | comment only | update wording |
| Comment in FIND | `dictionary.asm:43` | comment only | update wording |
| Comment in asm CODE-mode rollback | `assembler.asm:428` | comment only | update wording |
| Comment in asm_unlink_labels | `assembler.asm:839` | comment only | update wording |
| Comment in lbl_no_name | `assembler.asm:2345` | comment only | update wording (Task 8.6) |
| MARKER docstring | `system.asm:19` | comment only | update to reference FORTH-WORDLIST struct |
| DOMARKER docstring | `inner_interpreter.asm:112` | comment only | update to reference FORTH-WORDLIST struct |
| `hash.asm:4-8` references to "hash table" | `hash.asm:4-8` | comment only | leave as-is (these refer to the bucket-array concept, not the renamed label) |

**Summary: 9 live `LD`-instruction renames + 1 `HASH_BUCKETS → WORDLIST_BUCKETS` swap + 1 label relocation + ~10 comment updates.** The grep is the source of truth — re-run at dev-pass per AC #8.

### Register-convention pick (AC #2)

The current `hash_name` returns the bucket index in `A`. Callers compute `&bucket_head = hash_table + 2*A` themselves (5 sites; 5-byte sequence per site: `LD L,A / LD H,0 / ADD HL,HL / LD BC, hash_table / ADD HL, BC`). After the rename, the sequence becomes `LD L,A / LD H,0 / ADD HL,HL / LD BC, forth_wordlist + WORDLIST_BUCKET0 / ADD HL, BC` — identical encoded length (the immediate is still 16-bit). **Recommendation: keep `hash_name` interface as-is (`(name, length) -> bucket index in A`)** and parameterise at the call sites. This minimises diff and preserves the pure-function character of `hash_name`. Story 12.2's `WORDLIST` implementation will need to allocate a struct, zero its bucket array, and link it; Story 12.3's lookup walk will iterate the search-order array passing each `wid` to a small helper — at that point a `wordlist_bucket_addr` helper subroutine may pay for itself, but Story 12.1 doesn't need it.

If the dev agent prefers (b) — refactor `hash_name` to take a `wid` and return `&bucket_head` directly — that's also acceptable. The 5 call sites collapse to a single `CALL`, but `hash_name` becomes wordlist-aware (interface widened beyond a pure hash function). Document the choice in Completion Notes Task 4.

### Sjasmplus assertion idiom

Per AC #5 (sanity self-check), if `HASH_BUCKETS` survives as a separate constant from `WORDLIST_BUCKETS`, an assembly-time assertion is recommended. Sjasmplus syntax for a compile-time check:

```
    ASSERT WORDLIST_BUCKETS = HASH_BUCKETS
```

Or equivalently via `IF / DISPLAY / ENDIF`:

```
    IF WORDLIST_BUCKETS != HASH_BUCKETS
        DISPLAY "ERROR: WORDLIST_BUCKETS / HASH_BUCKETS mismatch"
        STOP
    ENDIF
```

If AC #5(d) chooses retirement (recommended), the assertion is unnecessary — `HASH_BUCKETS` is removed and `WORDLIST_BUCKETS` is the single source of truth. Verify retirement leaves zero `HASH_BUCKETS` references via `grep -n 'HASH_BUCKETS' src/*.asm` (should return only the `EQU` line in `src/constants.asm` if retirement is the chosen path; that line itself is then deleted).

### Test discipline for Story 12.1

Per AC #7, FORTH-WORDLIST is not yet a Forth word in Story 12.1 — the user-facing word lands in Story 12.3 (per the redrafted epic spec at `epics.md:1199-1233`). Workaround options for the test file:

- **(i) Test by-construction**: Don't try to read FORTH-WORDLIST's wid from Forth code. Instead, test the regression net — `:` defines a word; FIND retrieves it; MARKER rolls it back. The "FORTH-WORDLIST is the current wordlist" property is verified by-construction (no other wordlist exists). **Recommendation: (i)**.
- **(ii) Temporary `CONSTANT` shim**: Define a temporary `forth_wordlist CONSTANT FORTH-WORDLIST` somewhere kernel-resident (or as the first line of the test file). When Story 12.3 lands, replace this shim with the real CODE word. Adds 1 dictionary entry; minimal cost.
- **(iii) Defer FORTH-WORDLIST-specific tests**: Land all FORTH-WORDLIST behavioural verification in Story 12.3's test additions; Story 12.1's tests are pure regression smoke tests.

(i) is recommended — minimal-surface, no shim debt. The smoke tests in Task 9.2 follow this discipline.

### MARKER body-layout preservation rationale (AC #6)

The current MARKER body is `[saved_here(2)][saved_hash_table(128)]` = 130 bytes. If Story 12.1 changed this to snapshot the full FORTH-WORDLIST struct (130 bytes including the next-wordlist link), the body grows to `[saved_here(2)][saved_forth_wordlist(130)]` = 132 bytes — a +2-byte body-layout drift. That drift breaks:

- Pre-Story-12.1 markers stored on disk (currently no such mechanism — markers are kernel-resident only — but if a future feature stores them, byte-compatibility matters).
- Future MARKER stories that need to extend the body to cover the full search-order graph (Story 12.5 candidate). A clean extension is easier from a known-stable 128-byte baseline than from a Story-12.1-perturbed 130-byte baseline.
- The pre-edit binary delta. AC #13's +0 to +20 byte envelope assumes mechanical rename; a +2-byte body-layout change cascades through DOMARKER's hard-coded 128 → 130 swap.

Conclusion: **keep the byte-count at 128**. The next-wordlist link (always `0` for FORTH-WORDLIST in Story 12.1) is not part of the snapshot. Future stories that need full-graph MARKER will redesign — at that point, the +2-byte cost is paid in service of the new feature, not as Story 12.1 collateral. Per AC #6 / AC #10(b), the `LD BC, 128` lines stay unchanged.

### `src/assembler.asm` is unchanged in Phase 2 (per 2026-04-27 rollback)

Per `architecture.md:677` and `epics.md:142` (post-Story-11.5.5 redraft), the hard-coded assembler in `src/assembler.asm` is **unchanged in Phase 2**: no ASSEMBLER wordlist, no `CODE`/`END-CODE` auto-activation hooks, no opcode-word migration. Story 12.1's edits to `src/assembler.asm` are purely the `hash_table` rename — *not* a step toward an ASSEMBLER wordlist. The Story-10.7 asm-`#` dispatch hack (per `project_asm_hash_dispatch_hack.md`) is **permanent** — no retirement vehicle planned. The `w_HASH_cf` runtime dispatch site at `src/assembler.asm` (the asm-`#` hack itself) is not affected by the Story-12.1 rename — it continues to live in FORTH-WORDLIST as it does today. Verified via Task 8 spot-check.

### Standards-citation discipline (NFR17 / CCD-3)

Story 12.1 introduces only architectural-decision citations (`architecture.md:326-330` for E12-D1), not ANS-Forth-section citations — because Story 12.1 lands no user-facing Forth words. The future ANS citations land with their respective user-facing words:
- `WORDLIST` (Story 12.2) → `; ANS Forth 1994 §16.6.1.2460`
- `SEARCH-WORDLIST` (Story 12.2) → `; ANS Forth 1994 §16.6.1.2192`
- `GET-ORDER` (Story 12.3) → `; ANS Forth 1994 §16.6.1.1647`
- `SET-ORDER` (Story 12.3) → `; ANS Forth 1994 §16.6.1.2195`
- `FORTH-WORDLIST` (Story 12.3) → `; ANS Forth 1994 §16.6.1.1595`
- `GET-CURRENT` (Story 12.4) → `; ANS Forth 1994 §16.6.1.1643`
- `SET-CURRENT` (Story 12.4) → `; ANS Forth 1994 §16.6.1.2193`
- `DEFINITIONS` (Story 12.4) → `; ANS Forth 1994 §16.6.1.1180`
- `ONLY` (Story 12.5) → `; ANS Forth 1994 §16.6.2.1965`

### Project Structure Notes

- **Edits / additions for this story:**
  - **New file:** `src/wordlists.asm` (per `architecture.md:702`) — EQUs (`WORDLIST_SIZE`, `WORDLIST_BUCKETS`, `WORDLIST_NEXT`, `WORDLIST_BUCKET0`), the `forth_wordlist:` struct, optionally a `wordlist_bucket_addr` helper.
  - **New file:** `tests/wordlist_tests.fth` (per `architecture.md:722`) — 3-5 REPL-piped Forth tests per AC #7.
  - **Edits:** `src/dictionary.asm` (FIND, WORDS — Task 5); `src/compiler.asm` (build_header, COMP-ERROR — Task 6); `src/system.asm` (MARKER — Task 7); `src/inner_interpreter.asm` (DOMARKER — Task 7); `src/assembler.asm` (CODE-rollback, asm_unlink_labels — Task 8); `src/antforth.asm` (INCLUDE order, delete relocated `hash_table:` — Task 3); `src/constants.asm` (retire `HASH_BUCKETS` if AC #5(d)(i) — Task 5); `Makefile` (wire `wordlist_tests.fth` into `test-repl` — Task 9).
  - **No new EQUs in `src/constants.asm`** — the `WORDLIST_*` EQUs live in `src/wordlists.asm` (per single-source-of-truth: each subsystem owns its constants).
  - **Sprint-status flips:** `12-1-…: backlog → ready-for-dev` (create-story); `epic-12: backlog → in-progress` (create-story, first-story-in-epic convention); through `in-progress → review → done` (dev-story + code-review).
- **Alignment with unified project structure:** Matches `architecture.md:702` exactly (new `src/wordlists.asm`); matches `architecture.md:722` exactly (new `tests/wordlist_tests.fth`); matches `architecture.md:789` Epic-to-file mapping exactly. No detected conflicts or variances.
- **No source-tree restructure.** Edited files retain their existing responsibilities; the rename is mechanical address-arithmetic.

### Previous-Story Intelligence — Stories 11.5.1 to 11.5.7 (Epic 11.5 close-out)

Key inherited learnings relevant to Story 12.1:

1. **Verdict tables in Completion Notes** (Stories 11.5.2 / 11.5.3 / 11.5.4 / 11.5.5 / 11.5.6 / 11.5.7): one row per AC / Task, columns `Gate text | Evidence | Verdict`. Mirror this format.
2. **Per-task evidence with explicit grep / wc commands** — "ran command X, got output Y, here's the implication" — no hand-waving. AC #8 / Task 1.4 / Task 10 follow this.
3. **Re-grep at dev-pass** before publishing — line numbers cited above (e.g., `src/dictionary.asm:47`) are from story-drafting time and may have drifted post-Story-11.5.7. Re-verify per `feedback_systematic_reference_check.md` (the `feedback_systematic_reference_check.md` discipline applies in spirit to code refactors as well as document-surgery).
4. **Adversarial-review-finding triage table** — Story 11.5.5 / 11.5.6 / 11.5.7 review log format (ID / Severity / Category / Description / Resolution columns) replicated in Completion Notes Task 11.
5. **Standards-compliance discipline** (`feedback_standards_compliance.md`): NFR9 zero-regression is non-negotiable. If the rename surfaces a regression in the 810-test baseline, debug the root cause; do not paper over.
6. **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use plain "PASS" / "FAIL" / measured numbers — no florid audit phrasing. State the value, the gate, and the conclusion.
7. **Adversarial review** (`feedback_adversarial_review.md`): a mechanical-rename story has zero-finding temptation; Task 11's reviewer must hunt harder. Zero findings would be suspect. Expect ≥1-2 LOW findings per AC #10.
8. **Follow the process** (`feedback_follow_process.md`): the rename is mechanical — execute it; don't ask permission for the rename pick (default to AC #2 (a), AC #5(d)(i), AC #10(e) (i)).
9. **REPL tests preferred** (`feedback_repl_tests_preferred.md`): Story 12.1 adds REPL-piped Forth tests in `tests/wordlist_tests.fth` — no new assembly tests.
10. **Design upfront** (`feedback_design_upfront.md`): the wordlist-struct EQUs and `forth_wordlist:` symbol are designed for **the full Epic 12 scope** on day one — Stories 12.2-12.5 consume these names without renaming. Pick names that read clearly when there are 5+ wordlists, not just one. AC #5's recommended naming follows this.
11. **Systematic reference check** (`feedback_systematic_reference_check.md`): AC #8 / Task 1.4 / Task 10 cross-reference the actual `grep` output, not memory. Cite the live grep verbatim.
12. **Verdict-only audit pattern** (`feedback_verdict_only_audit.md`): does NOT apply here — Story 12.1 is a code-implementation story, not a cross-stack audit. The verdict-only pattern is reserved for cases where the defect spans multiple subsystems and the verdict + reproducer is the deliverable.
13. **Stabilisation interlude epics** (`feedback_stabilisation_interlude.md`): does NOT apply directly — Story 12.1 is the first story of a feature epic (Epic 12), not a stabilisation interlude. But the precedent matters: if the rename surfaces unexpected debt (e.g., a `hash_table` reference in a documentation file or test thread that requires non-trivial editing), prefer to land the rename cleanly and spawn a dedicated debt-cleanup item, rather than smuggling cleanup into Story 12.1.

### Git intelligence — recent commits relevant to Story 12.1

| Commit | Title | Relevance |
|---|---|---|
| `3ead2d8` | post retro 11.5 | Closes Epic 11.5; baseline for Story 12.1 = post-Story-11.5.7 binary (17,541 bytes) |
| `d184de4` | split THROW -271 into -271 disp range / -272 bit range | Story 11.5.6 — adds `-272 THROW_ASM_BIT_RANGE`; Task 8.7's CODE-mode error spot-check exercises this path |
| `88093d6` | redraft Epic 12 to drop ASSEMBLER wordlist + scrub residual forward-looking references | Story 11.5.5 — Story 12.1 lands against the **redrafted** Epic 12 spec (no ASSEMBLER wordlist, no auto-activation; FR30 withdrawn) |
| `4f1dec3` | harden print_throw_description table walk with wrap-safe 16-bit ADD HL,DE | Story 11.5.4 — no direct Story-12.1 dependency; touches `src/exception.asm` only |
| `822b5a8` | make EVALUATE THROW-safe so caught -58 / -258..-271 work via EVALUATE harness | Story 11.5.3 — Task 9.2's REPL test harness is EVALUATE-safe |

The Epic 11.5 close-out (commit `3ead2d8`) is the immediate ancestor; Story 12.1 starts from a known-clean baseline (per Story 11.5.7's CCD-4 verdict: all 7 gates PASS).

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` — Story 12.1 adds no new EXX-bounded handlers. The rename is purely address-arithmetic at existing call sites; no shadow-register pressure changes. The kernel-internal-entry contract (`w_THROW_cf.kernel_entry` requires primary-set entry) is unaffected.

### Sjasmplus build-time considerations

The FORTH-WORDLIST struct's bucket array is emitted via the LUA `_hash_buckets` table (currently at `src/antforth.asm:202-207`, relocating to `src/wordlists.asm` per AC #10(e)(i)). The LUA table is populated by `DEFCODE` / `DEFWORD` invocations at every primitive (`src/macros.asm:75-86, 109-117`). **Critical ordering**: the struct emission must occur **after** all DEFCODE/DEFWORD invocations, otherwise the bucket array emits zeros. Per Task 3.2, `INCLUDE "wordlists.asm"` lands immediately after `INCLUDE "bootstrap.asm"` (the last code-include in `src/antforth.asm:155`) — i.e., the same location where the existing data-area emission begins (`src/antforth.asm:201-202`).

### References

- `_bmad-output/planning-artifacts/epics.md:1133-1169` — Story 12.1 authoritative spec (post-Story-11.5.5 redraft)
- `_bmad-output/planning-artifacts/epics.md:1133-1302` — Epic 12 charter + all 6 stories (redrafted)
- `_bmad-output/planning-artifacts/architecture.md:326-330` — E12-D1 (per-wordlist hash table layout — the load-bearing decision for Story 12.1)
- `_bmad-output/planning-artifacts/architecture.md:332-336` — E12-D2 (search-order storage — Story 12.3 scope, not 12.1)
- `_bmad-output/planning-artifacts/architecture.md:338-342` — E12-D3 (wordlist identifier representation — `wid` = struct address)
- `_bmad-output/planning-artifacts/architecture.md:344-348` — E12-D4 WITHDRAWN 2026-04-27 (no ASSEMBLER wordlist; opcode words stay in FORTH-WORDLIST)
- `_bmad-output/planning-artifacts/architecture.md:677` — `src/assembler.asm` unchanged in Phase 2
- `_bmad-output/planning-artifacts/architecture.md:702` — `src/wordlists.asm` new file (Epic 12 addition)
- `_bmad-output/planning-artifacts/architecture.md:722` — `tests/wordlist_tests.fth` new file (Epic 12 test addition)
- `_bmad-output/planning-artifacts/architecture.md:789` — Epic-to-file mapping (Epic 12 row)
- `_bmad-output/planning-artifacts/architecture.md:802-804` — Integration patterns ("Dictionary lookup is parameterised on a wordlist-struct address")
- `_bmad-output/planning-artifacts/architecture.md:158` — no per-epic net-negative gate (Task 13 justification framing)
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline (AC #10(f) / NFR17 reference)
- `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 per-epic benchmark gate (Story 12.6's gate, not Story 12.1's)
- `_bmad-output/planning-artifacts/prd.md` (Epic 12 FRs — FR23, FR28, FR31)
- `_bmad-output/implementation-artifacts/11.5-7-epic-11-5-close-out-gate.md` — immediate predecessor; Epic 11.5 closed; verdict "Epic 12 UNBLOCKED"
- `_bmad-output/implementation-artifacts/11.5-5-epic-12-redraft.md` — Epic 12 redraft story (Story 12.1's spec is the redrafted version per this story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml:181-188` — Epic 12 row set (post-redraft)
- `src/macros.asm:7-12, 75-86, 109-117` — LUA `_hash_buckets` table populated by DEFCODE / DEFWORD (the assembly-time mechanism Story 12.1 preserves)
- `src/macros.asm:47-56` — `forth_hash` LUA function (assembly-time hash; matches runtime `hash_name`)
- `src/hash.asm:14-31` — runtime `hash_name` subroutine (Task 4 — unchanged in recommended pick (a))
- `src/dictionary.asm:5-244` — FIND / WORDS implementation (Task 5)
- `src/compiler.asm:80-277, 412-473` — `build_header` + COMP-ERROR (Task 6)
- `src/system.asm:23-86` — MARKER implementation (Task 7)
- `src/inner_interpreter.asm:114-145` — DOMARKER implementation (Task 7)
- `src/assembler.asm:410-441, 822-854, 2330-2353` — CODE-mode rollback + asm_unlink_labels (Task 8)
- `src/antforth.asm:127-156, 201-241` — INCLUDE order + data area (Task 3)
- `src/constants.asm:21` — `HASH_BUCKETS EQU 64` (Task 5; AC #5(d) retirement candidate)
- `src/structures.asm:18-30` — `UserArea` struct (no Story-12.1 edits — search-order USER vars land in Story 12.3)
- `tests/throw_migration_tests.fth` — exemplar REPL-test file structure (Task 9 model)
- `Makefile` — `test-repl` target (Task 9.3 wire-in)
- `docs/register-conventions.md` — EXX shadow-register convention (no Story-12.1 changes)
- DPANS94 §16.6.1 — Search-Order wordset (cited by future Stories 12.2-12.5; not by Story 12.1 directly)
- Project memories:
  - `feedback_adversarial_review.md` — reviews MUST find things (AC #10)
  - `feedback_standards_compliance.md` — investigate root cause; never paper over (AC #4)
  - `feedback_systematic_reference_check.md` — re-grep at dev-pass (AC #8 / Task 10)
  - `feedback_follow_process.md` — execute the recommended picks; don't ask permission (AC #12)
  - `feedback_design_upfront.md` — wordlist EQU names designed for full Epic 12 scope (AC #5)
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth tests, not assembly threads (AC #11)
  - `feedback_plain_qa_language.md` — measured value + gate + conclusion (AC #13 / Task 13)
  - `project_phase2_scope.md` — Phase-2 epic plan; Epic 12 = Search-Order Wordset only (post-redraft)
  - `project_assembler_keep_assembly.md` — `src/assembler.asm` stays as-is (AC #9 / Task 8)
  - `project_asm_hash_dispatch_hack.md` — Story-10.7 asm-`#` dispatch is permanent; unaffected by rename (Task 8.7)
  - `project_epic12_redraft_required.md` — closure note pointing at Story 11.5.5; Story 12.1's spec is the redrafted version

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

(no defects requiring debug-log archival)

### Completion Notes List

#### Task 1 — Pre-edit baselines

| Probe | Command | Pre-edit value | Status |
|---|---|---|---|
| 1.1 binary | `wc -c build/antforth.com` | **17,541 bytes** | matches expected |
| 1.2 REPL tests | `make test-repl` | **810 PASS / 0 FAIL** | matches expected |
| 1.3 asm tests | `make test` | clean (groups 1–6 OK) | matches expected |
| 1.4 hash_table grep | `grep -nE '\bhash_table\b' src/*.asm src/tests/*.asm` | 21 hits across 7 files (incl. 9 live `LD` references; 1 label definition; 11 comment-only) | classification matches AC #3 / Dev Notes "Pre-edit grep evidence" exactly |
| 1.5 LD BC,128 grep | `grep -nE 'BC,\s*128' src/{system,inner_interpreter}.asm` | 2 hits: `system.asm:56`, `inner_interpreter.asm:136` | matches AC #6 / AC #10(b) |
| 1.6 HASH_BUCKETS grep | `grep -n 'HASH_BUCKETS' src/*.asm` | 2 hits: `constants.asm:21` (def), `dictionary.asm:167` (use) | matches AC #5(d) |

No hits found in 1.4 outside AC #3's enumerated list — no scope-amendment per AC #14 needed.

#### Task 2 — `src/wordlists.asm` design picks

| Sub-pick | Decision | Rationale |
|---|---|---|
| AC #5(d) `HASH_BUCKETS` | **(i) retire** | Single source of truth (`feedback_design_upfront.md`); only one consumer. `WORDLIST_BUCKETS` is the canonical name. |
| AC #10(e) struct emission | **(i) emit in `src/wordlists.asm`** | Cleanest source organisation per `architecture.md:702`. |
| AC #2 `hash_name` interface | **(a) keep as-is** | Pure function; minimal diff; 5-byte addressing sequence unchanged at call sites. |
| AC #2.7 helper subroutine | **NOT defined** | Inlined arithmetic suffices for Story 12.1's single-wordlist case; helper may pay for itself in Story 12.3 search-order walk. |
| EQU naming | `WORDLIST_SIZE` / `WORDLIST_BUCKETS` / `WORDLIST_NEXT` / `WORDLIST_BUCKET0` | Read clearly when there are 5+ wordlists (per `feedback_design_upfront.md`). |

LUA loop bound uses `sj.calc("WORDLIST_BUCKETS")` instead of literal `63` so the EQU is the single source of truth.

#### Task 3 — INCLUDE ordering (AC #10(e) critical)

Initial placement put `INCLUDE "wordlists.asm"` immediately after `INCLUDE "bootstrap.asm"` per Task 3.2's literal instruction. **This broke `make test`** (assembly-thread regression suite) because TEST_MODE-only DEFCODEs (`TESTIMM`, `TEST-BRIDGE`) emit AFTER bootstrap inside the `IFDEF TEST_MODE` block. The bucket array was emitted before those DEFCODEs ran, so FIND of `TESTIMM` returned the wrong entry, producing `!` (fail emit) instead of `&` (pass emit) at offset 0x47 of test_io output.

**Fix (in-pass)**: relocated `INCLUDE "wordlists.asm"` to AFTER the `IFDEF TEST_MODE` block, immediately before the runtime data area at the old `hash_table:` site. Post-fix `make test` PASSes; `make test-repl` 810/0 unchanged. The story spec's Task 3.2 wording is wrong — see Task 12 in-pass log. **The architectural gate is "after ALL DEFCODE/DEFWORD invocations"**, which post-fix placement satisfies.

#### Task 4 — `src/hash.asm` interface decision

Pick (a) — kept `hash_name` interface as-is `(name, length) → bucket index in A`. Zero edits to `src/hash.asm`. Parameterisation done at the 5 call sites (Tasks 5–8).

#### Task 5 — `src/dictionary.asm` rename

- FIND bucket-head load (line 47): `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0`. ✓
- WORDS bucket-array walk (line 168 post-edit, was 166): `LD HL, hash_table` → `LD HL, forth_wordlist + WORDLIST_BUCKET0`. ✓
- WORDS bucket-count (line 169 post-edit): `LD A, HASH_BUCKETS` → `LD A, WORDLIST_BUCKETS`. ✓
- Build clean (0 errors / 0 warnings); REPL test count unchanged at this checkpoint.

#### Task 6 — `src/compiler.asm` rename

- `bh_bucket_addr` field comment (line 84): "Address in hash_table" → "Address in FORTH-WORDLIST bucket array".
- build_header bucket-head update (line 219): `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0`. ✓
- COMP-ERROR rollback (line 438): `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0`. ✓
- Build clean; spot-check via test 803 (MARKER round-trip) and existing colon-error tests covered by REPL suite.

#### Task 7 — `src/system.asm` MARKER + `src/inner_interpreter.asm` DOMARKER

- `system.asm:55` (now :57): `LD HL, hash_table` → `LD HL, forth_wordlist + WORDLIST_BUCKET0`. ✓
- `system.asm:56` (now :58): `LD BC, 128` **unchanged** (AC #6 byte-count gate). ✓
- `inner_interpreter.asm:135` (now :136): `LD DE, hash_table` → `LD DE, forth_wordlist + WORDLIST_BUCKET0`. ✓
- `inner_interpreter.asm:136` (now :137): `LD BC, 128` **unchanged** (AC #6 byte-count gate). ✓
- Docstrings updated to clarify body still snapshots only the 64×2-byte bucket array (not the next-link cell) per AC #6.
- MARKER round-trip exercised by new test 803.

#### Task 8 — `src/assembler.asm` rename

- CODE-mode error rollback (line 427): `LD BC, hash_table` → `LD BC, forth_wordlist + WORDLIST_BUCKET0`. ✓
- asm_unlink_labels per-slot rollback (line 844): `LD DE, hash_table` → `LD DE, forth_wordlist + WORDLIST_BUCKET0`. ✓
- Comment at line 2345: "zero hash_table[0]" → "zero forth_wordlist's bucket 0". ✓
- The asm-`#` runtime-dispatch hack (`project_asm_hash_dispatch_hack.md`) is unaffected — it lives in FORTH-WORDLIST and is registered by DEFCODE like any other primitive.
- CODE-mode rollback exercised by REPL tests 769–800 (Story 11.5.6 -271/-272 series); all PASS.

#### Task 9 — Tests + Makefile wire-in

- New file `tests/wordlist_tests.fth` (Forth-source documentation; 5 numbered test sections T1–T5).
- Makefile entries 802–806 added immediately after existing test 801 in the `test-repl:` target. Test numbering continues the sequence (per Story 11.5.7 baseline; 802..806 skips none).
- Test 803 (MARKER round-trip) initially failed because `' TWBAR CATCH .` cannot wrap `'` (which throws -13 at REPL parse-time, before CATCH would run). **In-pass redesign**: drove the post-MARKER assertion via the uncaught-recovery path — `TWBAR` parses, raises -13, REPL prints "TWBAR ?" + "error -13: undefined word", and the follow-on `1 2 + .` proves clean recovery. This still verifies that MARKER unlinked TWBAR from FORTH-WORDLIST's bucket array. (See Task 12 in-pass log.)
- Test 806 (FIND of MARKER) initially used `S" MARKER" DROP 1- FIND` — wrong, S" returns a content address not a counted-string address. **Fixed in-pass** to `BL WORD MARKER FIND SWAP DROP .` which puts a proper counted string at HERE; flag = -1 confirms non-IMMEDIATE. (See Task 12 in-pass log.)
- Post-edit total: **815 PASS / 0 FAIL** (= 810 baseline + 5 new). Delta +5 PASS, +0 FAIL.

#### Task 10 — Re-grep results (post-edit honesty)

```
$ grep -nE '\bhash_table\b' src/*.asm src/tests/*.asm
src/wordlists.asm:18:; `hash_table` symbol is retired in this story; every call site now
```

**1 hit.** Per AC #2 expectation: "either zero hits, or only the `EQU` alias line in `src/wordlists.asm`". The single hit is a doc-comment in `src/wordlists.asm`'s file header, explaining the retirement decision — neither a callable destination nor an EQU alias, but discretionary documentation. Per AC #14 it's an acceptable in-pass discretionary fix; recorded as Finding F1 (LOW) in Task 11.

```
$ grep -n 'HASH_BUCKETS' src/*.asm
src/constants.asm:21:; HASH_BUCKETS retired in Story 12.1 (AC #5(d)(i)) — single source of truth
src/wordlists.asm:23:WORDLIST_BUCKETS    EQU     64      ; architecture.md:328 — E12-D1; sole source of truth (HASH_BUCKETS retired Story 12.1 per AC #5(d)(i))
```

**0 live `HASH_BUCKETS` references.** Both hits are documentation explaining retirement. The `EQU` line in `src/constants.asm` is gone; `WORDLIST_BUCKETS` is the sole source of truth.

```
$ grep -nE 'BC,\s*128' src/{system,inner_interpreter}.asm
src/inner_interpreter.asm:137:        LD      BC, 128
src/system.asm:58:        LD      BC, 128
```

**Exactly 2 hits, same pair as pre-edit.** AC #6 / AC #10(b) byte-count preservation gate PASS. Line numbers shifted +1 / +2 due to expanded docstrings; the `LD BC, 128` instructions themselves are unchanged.

```
$ grep -n 'forth_wordlist' src/*.asm
src/wordlists.asm:35:forth_wordlist:                          [label definition]
src/dictionary.asm:47, :168                                    [FIND, WORDS]
src/compiler.asm:219, :438                                     [build_header, COMP-ERROR]
src/system.asm:57                                              [MARKER]
src/inner_interpreter.asm:136                                  [DOMARKER]
src/assembler.asm:427, :844, :2345                             [CODE-rollback, asm_unlink_labels, comment]
+ comment-only mentions in dictionary.asm:43 and compiler.asm:215
```

All hits use the canonical `forth_wordlist` symbol (lowercase). No typos like `FORTH_WORDLIST`, `forth_wordlist_buckets`, etc. AC #10(c) consumer-audit PASS.

#### Task 11 — Adversarial self-review findings

| ID | Severity | Category | Description | Resolution |
|---|---|---|---|---|
| F1 | LOW | (a) `hash_table` orphan reference | Post-edit grep returns 1 hit in `src/wordlists.asm:18` — a doc comment in the file-header explaining retirement. Per AC #2 expected set is "zero hits OR EQU alias line"; this is a 3rd category (descriptive comment in new file). | **Accepted (LOW).** Comment has documentation value; not a callable destination. Per AC #14 in-pass discretionary fix. |
| F2 | LOW | (e) struct-emission ordering | Story spec Task 3.2 wording — "immediately after `INCLUDE \"bootstrap.asm\"`" — is **wrong** for the TEST_MODE build, where `TESTIMM` and `TEST-BRIDGE` DEFCODEs emit after bootstrap inside the `IFDEF TEST_MODE` block. Initial-attempt placement triggered `make test` failure at `test_dictionary.asm` test 5 (FIND of IMMEDIATE word emitted `!` instead of `&`). | **Fixed in-pass.** Relocated `INCLUDE "wordlists.asm"` to after the `IFDEF TEST_MODE` block. AC #10(e) gate "after ALL DEFCODE/DEFWORD invocations" is satisfied. Story spec wording flagged for retrospective polish; the architectural gate (AC #10(e)) is the source of truth. |
| F3 | LOW | (b) MARKER byte-count drift | Verified `grep -nE 'BC,\s*128' src/{system,inner_interpreter}.asm` returns exactly the pre-edit pair (2 hits at expected lines). No new 128 introduced; no removed 128. | **PASS** (no finding). |
| F4 | LOW | (d) Next-link initialisation | Verified in binary: forth_wordlist sjasmplus address = 0x43BD; .COM offset = 0x42BD; first 2 bytes = `00 00` (DW 0); next 2 bytes = `5C 08` (live bucket[0]). | **PASS** (no finding). |
| F5 | LOW | (f) Citation discipline | `src/wordlists.asm` carries 5 architecture.md citations: layout doc (`:326-330`), `WORDLIST_SIZE` EQU (`:328`), `WORDLIST_BUCKETS` EQU (`:328`), `WORDLIST_NEXT` EQU (`:326-330`), `WORDLIST_BUCKET0` EQU (`:326-330`). No standards-derived Forth words land in Story 12.1; no ANS citations needed. | **PASS** (no finding). |

**Summary:** 2 LOW findings (F1, F2). HIGH/MEDIUM count = 0; gate is not blocked. F1 accepted (documentation value); F2 fixed in-pass. Mirrors `feedback_adversarial_review.md` discipline (zero findings would be suspect; mechanical-rename stories warrant ≥1–2 LOW per AC #10).

#### Task 12 — In-pass-fix log

| # | Fix | Rationale |
|---|---|---|
| 1 | Relocated `INCLUDE "wordlists.asm"` from immediately-after-bootstrap to after the `IFDEF TEST_MODE` block. | TEST_MODE adds DEFCODEs after bootstrap; struct must emit after ALL DEFCODE invocations (AC #10(e) gate). Story-spec literal wording for Task 3.2 was wrong; the AC gate is correct. |
| 2 | Test 803 redesign: dropped `' TWBAR CATCH .` formulation; replaced with bare `TWBAR` and asserted on the uncaught-recovery output. | `'` raises -13 at REPL parse-time before CATCH wraps it; the design was structurally flawed. The replacement still verifies MARKER unlinked TWBAR from FORTH-WORDLIST's bucket array, plus REPL recovery via follow-on `1 2 + . → 3`. |
| 3 | Test 806 redesign: `S" MARKER" DROP 1- FIND` → `BL WORD MARKER FIND`. | S" returns a content-address (no preceding count byte); FIND requires a counted-string address. `BL WORD MARKER` parses "MARKER" as a counted string at HERE. |

No HALT condition triggered. No structural-load-bearing finding requiring project-lead escalation per AC #14.

#### Task 13 — Binary delta

| Probe | Value | Gate | Verdict |
|---|---|---|---|
| Pre-edit `wc -c build/antforth.com` | 17,541 bytes | per Story 11.5.7 Task 1.1 | matches expected |
| Post-edit `wc -c build/antforth.com` | **17,543 bytes** | — | — |
| Delta | **+2 bytes** | AC #13: +0 to +20 envelope | **PASS** |

Delta breakdown: the +2 bytes are the `DW 0` next-wordlist-link cell at offset 0 of the `forth_wordlist` struct. The 9 live-`LD` renames are byte-neutral (16-bit immediates: `hash_table` and `forth_wordlist + WORDLIST_BUCKET0` resolve to different 16-bit addresses, but each `LD r, immediate` instruction encodes to the same 3 bytes). Mechanical rename = neutral; structural addition = exactly +2 (the DW 0).

#### Task 14 — Sprint-status flips

- 14.1 At dev-pass start: flipped `12-1-…: ready-for-dev` → `in-progress` ✓
- 14.2 At dev-pass close: will flip `12-1-…: in-progress` → `review` (Step 9 of dev-story workflow).
- 14.3 `review → done` flip is owned by `code-review`. ✓
- 14.4 `epic-12: backlog → in-progress` flip is owned by `create-story`; verified `sprint-status.yaml:181` reads `epic-12: in-progress` post-create-story. ✓

### File List

**New files:**
- `src/wordlists.asm` — per-wordlist struct EQUs + canonical `forth_wordlist` struct emission (with LUA bucket-array expansion).
- `tests/wordlist_tests.fth` — REPL-piped Forth tests (T1–T5) for FORTH-WORDLIST regression smoke.

**Modified files:**
- `src/antforth.asm` — added `INCLUDE "wordlists.asm"` after IFDEF TEST_MODE block; deleted the legacy `hash_table:` emission and its LUA bucket-array loop; updated banner comment to reference FORTH-WORDLIST.
- `src/constants.asm` — retired `HASH_BUCKETS EQU 64`; replaced with retirement note.
- `src/dictionary.asm` — FIND + WORDS rename to `forth_wordlist + WORDLIST_BUCKET0`; `LD A, HASH_BUCKETS` → `LD A, WORDLIST_BUCKETS`; comment updates.
- `src/compiler.asm` — build_header + COMP-ERROR bucket-head rename; `bh_bucket_addr` field comment updated.
- `src/system.asm` — MARKER snapshot rename; docstring updated to clarify body snapshots only the 64×2-byte bucket array (not the next-link cell).
- `src/inner_interpreter.asm` — DOMARKER restore rename; docstring updated.
- `src/assembler.asm` — CODE-mode rollback + asm_unlink_labels rename; comment at line 2345 updated.
- `Makefile` — added 5 new REPL test entries (802–806) for FORTH-WORDLIST regression smoke.

**Code-review pass modifications (2026-04-29):**
- `src/wordlists.asm` — added `ASSERT WORDLIST_BUCKETS = 64` plus a comment listing the three drift-prone literal-`63` sites (R1).
- `src/macros.asm` — drift-warning comment on the LUA `for i = 0, 63 do` and `& 63` literals; explains why they cannot use the EQU directly (sjasmplus pass-ordering: this file is included before `wordlists.asm`) and points to the assertion (R1).
- `src/hash.asm` — drift-warning comment on `AND 63` (R1).
- `tests/wordlist_tests.fth` — `\ expect:` comments rewritten to mirror the Makefile's actual assertion strings per test (R2); the dangerous `: TWGHOST [']  TWBAR ;` snippet replaced with `\`-prefixed line comments (R3).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 12.1 row flipped `ready-for-dev → in-progress` (will flip to `review` at Step 9).
