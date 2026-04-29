# Story 12.4: Compilation wordlist control — `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to control which wordlist new definitions are added to,
so that I can partition my definitions by subsystem without polluting the default `FORTH-WORDLIST` (FR25, FR26).

## Acceptance Criteria

1. **Given** a new USER variable that tracks the current compilation wordlist (the wid into which `:` / `CODE` / `CREATE` / `VARIABLE` / `CONSTANT` / `MARKER` insert their dictionary header),
   **when** the kernel boots,
   **then** the variable is set to `forth_wordlist` (the canonical wid). The new field is appended to the existing `STRUCT UserArea` in `src/structures.asm` AFTER the Story-12.3 fields (`search_order_depth`, `search_order`) — strict additive change to preserve every existing offset (mirrors Story 12.3 AC #1 / AC #18(e) discipline). Recommended layout addition (dev agent picks final name but documents in Completion Notes Task 2):
   - `current_wordlist    DW   0`        ; CURRENT-WORDLIST USER var (Story 12.4 — wid for next dictionary insert)

   Naming pick: `current_wordlist` matches the ANS-style short-form ("current"); the field is referenced as `(IY+UserArea.current_wordlist)`. Cold-start init in `src/antforth.asm` writes `forth_wordlist` low/high bytes into the field as a new step (recommended placement: as part of step "8d. SEARCH-ORDER init" or as new step "8e. CURRENT-WORDLIST init"). Pick recorded in Completion Notes Task 2.

2. **Given** `GET-CURRENT` per ANS Forth 1994 §16.6.1.1643 (stack effect `( -- wid )`),
   **when** invoked,
   **then** it pushes the current compilation wordlist's wid onto TOS — i.e., the value of `(IY+UserArea.current_wordlist)`. New word registered in `src/wordlists.asm` with citation comment `; ANS Forth 1994 §16.6.1.1643   GET-CURRENT` and stack-effect comment `( -- wid )` per CCD-3 / NFR17. Implementation pattern mirrors `w_FORTH_WORDLIST_cf` (push BC; load wid into BC; NEXT) — ~6 bytes.

3. **Given** `SET-CURRENT` per ANS Forth 1994 §16.6.1.2193 (stack effect `( wid -- )`),
   **when** invoked with a wid on TOS,
   **then** it stores the wid into `(IY+UserArea.current_wordlist)` and pops a new TOS. Subsequent definitions (`:`, `CODE`, `CREATE`, `VARIABLE`, `CONSTANT`, `MARKER`) place their headers into THAT wordlist's bucket array. New word registered in `src/wordlists.asm` with citation comment `; ANS Forth 1994 §16.6.1.2193   SET-CURRENT` and stack-effect comment `( wid -- )` per CCD-3 / NFR17. Underflow-guard via `check_underflow` (1-cell guard) per Story 11.5.2's idiom — wid is on TOS; popping new TOS requires a second cell below it. Pick recorded in Completion Notes Task 3 (recommendation: `check_underflow` covers both cells via the standard 32-byte SP_BASE margin).

4. **Given** `DEFINITIONS` per ANS Forth 1994 §16.6.1.1180 (stack effect `( -- )`),
   **when** invoked,
   **then** it is equivalent to `GET-ORDER DROP DROP ... SET-CURRENT` reduced to its essence: copy `search_order[0]` (the top-of-search-order wid) into `(IY+UserArea.current_wordlist)`. **No stack effect.** New word registered in `src/wordlists.asm` with citation comment `; ANS Forth 1994 §16.6.1.1180   DEFINITIONS` and stack-effect comment `( -- )` per CCD-3 / NFR17. Implementation: ~8 bytes — `LD A, (IY+UserArea.search_order); LD (IY+UserArea.current_wordlist), A; LD A, (IY+UserArea.search_order+1); LD (IY+UserArea.current_wordlist+1), A; NEXT`. **Edge case**: if `SEARCH-ORDER-DEPTH = 0`, slot 0 holds garbage (or zero from cold-start defensive init per Story 12.3 AC #11). Dev agent picks ONE of: **(a)** unconditionally read slot 0 (matches ANS spec text — depth 0 + DEFINITIONS yields a wid-of-zero, which would later cause subsequent definitions to crash on bucket-head dereference); **(b)** guard with `IF depth > 0 THEN copy slot 0 ELSE no-op`; **(c)** raise `-49 THROW` if depth = 0. **Recommendation: (a)** — match the standard verbatim; the user that called `0 SET-ORDER DEFINITIONS` is asking for trouble and gets it. Recorded in Completion Notes Task 4. Cross-reference Story 12.3 AC #18(c) (depth=0 footgun on FIND).

5. **Given** the runtime header-build path `build_header` in `src/compiler.asm:107-277`,
   **when** Story 12.4 lands,
   **then** the bucket-address compute at `src/compiler.asm:215-221` is parameterised on `(IY+UserArea.current_wordlist)` instead of the literal `forth_wordlist + WORDLIST_BUCKET0`:
   - **Before:** `LD BC, forth_wordlist + WORDLIST_BUCKET0; ADD HL, BC; ...`
   - **After:** load the wid from `(IY+UserArea.current_wordlist)` into HL/BC; `ADD HL, BC` to combine with the bucket-index×2 already in HL; then `ADD HL, WORDLIST_BUCKET0` (or fold the +2 into the existing `INC HL/INC HL` pattern for parity with `search_wid_for_name`'s `WORDLIST_BUCKET0` pattern at `src/dictionary.asm:120-126`). Save the wid into a new scratch DW `bh_wid` (mirroring `bh_bucket_addr`, `bh_old_bucket_head`, etc.) so error-recovery paths can restore against the SAME wid the insertion targeted (see AC #6 / AC #7 below). Build pattern recorded in Completion Notes Task 5.

   **Critical regression gate**: with `current_wordlist == forth_wordlist` (the default), the post-edit byte sequence emitted by `build_header` MUST produce a dictionary header that lands in the same bucket of `forth_wordlist` as before — i.e., `: TWFOO ;` post-edit hits the same hash bucket as pre-edit. Verify via test 802 (`: TWFOO 42 ; TWFOO .` → `42 `) plus a fresh repeat of WORDS to confirm the new word lands in the FORTH-WORDLIST bucket array (not somewhere else).

6. **Given** the colon-error-recovery path `w_COMP_ERROR_cf` in `src/compiler.asm:421-473`,
   **when** Story 12.4 lands,
   **then** the bucket-address restore at `src/compiler.asm:434-443` is parameterised on the SAVED wid from `bh_wid` (captured at build_header time, copied into a new `colon_saved_wid` scratch DW alongside `colon_saved_here`/`colon_saved_bucket`/`colon_saved_head` at `:93-96`). The restore reads `colon_saved_wid` and computes `&saved_wid.buckets[bucket]`, then writes `colon_saved_head` back into that bucket head — exactly mirroring the pre-edit semantics for the FORTH-WORDLIST case (`current_wordlist == forth_wordlist`) and correctly handling the case where the user-defined word was inserted into a non-FORTH-WORDLIST. The colon prologue at `:380-383` saves `colon_saved_wid` from `bh_wid` immediately after the existing `colon_saved_here` / `colon_saved_bucket` / `colon_saved_head` saves.

7. **Given** the assembler-CODE-error-recovery path in `src/assembler.asm:410-441` (the `asm_recover` / `asm_unwind` analogue) and the label-unlink path `asm_unlink_labels` at `:822-854`,
   **when** Story 12.4 lands,
   **then** both paths are parameterised on a saved wid:
   - **`src/assembler.asm:427`** (CODE-word bucket restore): replace `LD BC, forth_wordlist + WORDLIST_BUCKET0` with a load from a new scratch DW `asm_saved_wid` (mirrors `asm_saved_bucket`/`asm_saved_head`). The CODE prologue saves `asm_saved_wid` from `bh_wid` immediately after the existing `asm_saved_*` saves (search for `asm_saved_bucket` writes near `:1240` / `:2287` per the build_header CALLs).
   - **`src/assembler.asm:844`** (LABEL bucket-restore inside `asm_unlink_labels`): replace `LD DE, forth_wordlist + WORDLIST_BUCKET0` with a load from `asm_saved_wid` (a single per-CODE-block wid is sufficient — all LABELs created during one CODE block live in the same wordlist as the CODE word itself; mid-CODE `SET-CURRENT` is not supported, see Dev Notes "Mid-CODE SET-CURRENT discipline" below).

   Recommended pick (cheapest): single per-CODE-block `asm_saved_wid:` DW. Alternative (heavier): extend each label slot in `asm_label_dict` from {resolved, target, bucket, old_head} to {resolved, target, bucket, old_head, wid}, growing each slot by 2 bytes. Slot count is small (< 32 in normal use) so the heavier pick is workable, but the cheaper pick suffices for ANS conformance and matches the design assumption that `SET-CURRENT` is a definition-time directive, not a per-LABEL directive. Pick recorded in Completion Notes Task 6.

8. **Given** the `MARKER` snapshot path in `src/system.asm:25-88` (specifically lines 53-58: `LD HL, forth_wordlist + WORDLIST_BUCKET0; LD BC, 128; LDIR`) and the `MARKER` restore path `DOMARKER` in `src/inner_interpreter.asm:115-146` (specifically lines 131-138),
   **when** Story 12.4 lands,
   **then** the dev agent picks ONE of:
   - **(a) Leave MARKER FORTH-WORDLIST-only.** MARKER's *header* still lands in `current_wordlist` per AC #5, but the snapshot/restore body remains scoped to FORTH-WORDLIST's bucket array. Limitation: a MARKER defined while `current_wordlist == FORTH-WORDLIST` will only roll back FORTH-WORDLIST entries; user-defined words placed into other wordlists between MARKER-create and MARKER-execute are NOT rolled back. Document the limitation in `src/system.asm` MARKER docstring; revisit when Epic 13 or later adds reason to extend MARKER. **Cheap and consistent with Story 12.3 AC #10 pick (a) for WORDS** — defer broad-wordlist semantics to a later story.
   - **(b) Snapshot/restore the wordlist that was current AT MARKER-CREATE TIME.** MARKER-create reads `(IY+UserArea.current_wordlist)`, copies that wordlist's bucket array (128 bytes) into the body, ALSO captures the wid itself (2 bytes) so DOMARKER restores into the right wordlist. Body grows from `[saved_here(2)][saved_buckets(128)]` = 130 bytes to `[saved_here(2)][saved_wid(2)][saved_buckets(128)]` = 132 bytes. **Backward-compat caveat**: a MARKER created with the old binary (130-byte body) executed in the new binary (expecting 132-byte body) misreads. Acceptable because MARKERs are not persisted across kernel rebuilds.
   - **(c) Snapshot every wordlist in the chain.** Far heavier — requires walking the wordlist next-link chain (currently empty: `forth_wordlist`'s next-link is 0 per Story 12.1). Wait until WORDLIST chains are populated to do this. Out of scope for Story 12.4.

   **Recommendation: (a)** — match Story 12.3 AC #10's discipline (defer broader semantics to a later story; keep this story's diff focused on the user-facing words). Document the limitation crisply in MARKER's docstring AND in `docs/throw-codes.md` or a dedicated Story-12.4 MARKER-scope note. Recorded in Completion Notes Task 7.

9. **Given** the `WORDS` walk in `src/dictionary.asm:203-288` (currently scoped to `forth_wordlist + WORDLIST_BUCKET0`, per Story 12.3 AC #10 pick (a)),
   **when** Story 12.4 lands,
   **then** the dev agent picks ONE of:
   - **(a) Leave WORDS scoped to FORTH-WORDLIST.** Same pick as Story 12.3 — defer until WORDLIST-chain semantics need to be exposed; ANS does not standardise WORDS scope. Limitation: words placed into non-FORTH-WORDLIST wordlists are invisible to WORDS. Document in WORDS docstring (already partially documented per Story 12.3 — extend the comment to mention SET-CURRENT now exists).
   - **(b) Walk the current compilation wordlist** (read `current_wordlist`). Cheap; mirrors GET-CURRENT semantics; surfaces user-defined wordlists' contents when paired with `<wid> SET-CURRENT WORDS`.
   - **(c) Walk the search-order top wordlist** (slot 0). Mirrors Story 12.3 AC #10 pick (c); less common.
   - **(d) Walk every wid in the search order.** Heaviest; mirrors Gforth's WORDS semantics.

   **Recommendation: (a)** — keep WORDS scoped to FORTH-WORDLIST. Rationale: (i) ANS does not standardise; (ii) Story 12.4's scope is the three user-facing compilation-wordlist words + the `build_header` parameterisation, not WORDS-extension semantics; (iii) `<wid> SET-CURRENT` followed by a manual bucket-array dump is expressible by a user; (iv) revisit when MicroBeast hardware wordlists land (Phase 3). Recorded in Completion Notes Task 8. **Optional in-pass refinement**: extend the WORDS docstring at `src/dictionary.asm:195-202` to mention SET-CURRENT now exists (the existing comment says "revisit when Story 12.4's DEFINITIONS / SET-CURRENT lands and definitions can land in non-FORTH-WORDLIST wordlists" — landing this story closes the forward-pointer; reword to a closure-note).

10. **Given** the cold-start sequence in `src/antforth.asm:18-122` (specifically the new "8d. SEARCH-ORDER init" at `:83-107` introduced by Story 12.3),
    **when** Story 12.4 lands,
    **then** a new init line writes `(IY+UserArea.current_wordlist)` = `forth_wordlist` (low byte then high byte — mirroring the SEARCH-ORDER init pattern at `:93-95`). Recommended placement: immediately AFTER the SEARCH-ORDER init's slot-1..15 zero-fill loop (`:104-107`) and BEFORE the "9. FORTH-WORDLIST is pre-populated" comment at `:109` — i.e., insert as step "8e. CURRENT-WORDLIST init" with a 4-line block:

    ```
            ; 8e. CURRENT-WORDLIST init — default compilation wordlist = FORTH-WORDLIST.
            ;     ANS Forth 1994 §16.6.1.2193 SET-CURRENT default-state convention.
            LD      HL, forth_wordlist
            LD      (IY+UserArea.current_wordlist),   L
            LD      (IY+UserArea.current_wordlist+1), H
    ```

    Pick recorded in Completion Notes Task 2. The new init is ~10 bytes; trivial cost.

11. **Given** the `src/wordlists.asm` extension layout established by Stories 12.1 / 12.2 / 12.3,
    **when** the three new DEFCODE blocks (`w_GET_CURRENT`, `w_SET_CURRENT`, `w_DEFINITIONS`) are added,
    **then** they are emitted **BEFORE the `forth_wordlist:` struct emission** (line 260) — same emission-order discipline as Stories 12.2 / 12.3 (per `src/wordlists.asm:33-39, 110-114`). Each new word's name is registered into `_hash_buckets[]` at DEFCODE macro time (`src/macros.asm:75-86`). Recommended insertion point: AFTER the `w_SET_ORDER_cf` block + `do_search_order_overflow` raise site (after line 248) and BEFORE the `srch_saved_ip:` scratch (line 250) — i.e., the new DEFCODEs land between SET-ORDER's body and the shared scratch. (Or: place after `srch_saved_ip:` if grouping scratch with its consumers makes more sense — dev agent picks; recorded in Completion Notes Task 9. Recommendation: AFTER `do_search_order_overflow:` and BEFORE `srch_saved_ip:` — keeps the THROW raise sites adjacent to the words that use them.)

    Verify post-edit: `grep -n 'forth_wordlist:' src/wordlists.asm` returns one line, and that line is BELOW all SEVEN DEFCODE blocks in the file (`w_WORDLIST`, `w_SEARCH_WORDLIST`, `w_FORTH_WORDLIST`, `w_GET_ORDER`, `w_SET_ORDER`, `w_GET_CURRENT`, `w_SET_CURRENT`, `w_DEFINITIONS`).

12. **Given** Story 12.3's binary baseline (**18,041 bytes** post-Story-12.3 per `_bmad-output/implementation-artifacts/12-3-…md` Task 11.1),
    **when** Story 12.4 lands,
    **then** the binary delta is recorded with `wc -c build/antforth.com` and falls within an envelope of **+50 to +120 bytes**. Component breakdown (rough budget):
    - `w_GET_CURRENT`: ~6 bytes (push BC; LD BC, (IY+current_wordlist); NEXT — or load via two `LD r,(IY+...)` for the 2-byte field)
    - `w_SET_CURRENT`: ~10 bytes (check_underflow; store BC into (IY+current_wordlist); pop new TOS; NEXT)
    - `w_DEFINITIONS`: ~12 bytes (load slot 0 into HL via two `LD r,(IY+search_order/...)`; store into (IY+current_wordlist); NEXT)
    - `build_header` parameterisation: ~+8 bytes net (load wid from IY-relative instead of immediate `LD BC, forth_wordlist + WORDLIST_BUCKET0`; one `LD r,(IY+...)` pair replaces a `LD BC, immediate`; the offset adjustment for WORDLIST_BUCKET0 is also +2 bytes)
    - `bh_wid` scratch DW: +2 bytes
    - `colon_saved_wid` scratch DW: +2 bytes
    - `asm_saved_wid` scratch DW: +2 bytes
    - `w_COMP_ERROR_cf` parameterisation: ~+8 bytes (similar to build_header)
    - assembler.asm:427 + :844 parameterisation: ~+12 bytes (two sites; similar shape)
    - colon prologue + CODE prologue saves: +8 bytes (two new `LD HL, (bh_wid); LD (saved_wid), HL` patterns)
    - Cold-start init for `current_wordlist`: ~10 bytes
    - UserArea struct grows by 2 bytes (current_wordlist DW)
    - **Net total: ≈ +85 bytes**, with **+50..+120 envelope** covering pick variations.

    Anything beyond +120 bytes is justified explicitly. A smaller-than-expected delta is also flagged. Recorded plainly per `feedback_plain_qa_language.md` (state value, gate, conclusion).

13. **Given** the regression net (`make test-repl` 831 PASS / 0 FAIL post-Story-12.3 per `_bmad-output/implementation-artifacts/12-3-…md` Task 7.4),
    **when** Story 12.4 lands,
    **then** `make test-repl` shows **831 + N PASS / 0 FAIL** where N = the count of new tests added in Task 11. Pre-existing 831 tests must all continue to pass (NFR9 zero-regression gate per `feedback_standards_compliance.md`); **most critically** all definition-creating tests (`:`, `CREATE`, `VARIABLE`, `CONSTANT`, `MARKER`, `CODE`) must continue to pass — proving the `build_header` parameterisation is regression-clean for the `current_wordlist == forth_wordlist` default case. Any regression is debugged at root cause, not papered over. `make test` (assembly thread) must remain clean.

14. **Given** the test-coverage discipline per `feedback_repl_tests_preferred.md`,
    **when** Story 12.4 adds tests,
    **then** they are REPL-piped Forth scripts in `tests/wordlist_tests.fth` (extending the file Stories 12.1/12.2/12.3 grew), wired into `Makefile`'s `test-repl` target with test numbers continuing from 822. **No new assembly test threads.** Coverage scope (12 + new tests; dev agent picks final count and IDs in Task 11):

    - **T-GC1 — initial GET-CURRENT state** (AC #1 / #2 boot gate): `GET-CURRENT FORTH-WORDLIST = .` → expect `-1 ` (current = FORTH-WORDLIST at boot). Test 823.
    - **T-SC1 — SET-CURRENT round-trip** (AC #3): `WORDLIST   DUP SET-CURRENT   GET-CURRENT = .` → expect `-1 ` (the wid pushed by WORDLIST is now the current wordlist). Test 824. Reset via `FORTH-WORDLIST SET-CURRENT` afterwards.
    - **T-SC2 — definitions land in current wordlist** (AC #5): `WORDLIST CONSTANT WL1   WL1 SET-CURRENT   : SC2FOO 77 ;   FORTH-WORDLIST SET-CURRENT   S" SC2FOO" FORTH-WORDLIST SEARCH-WORDLIST .` → expect `0 ` (SC2FOO is NOT in FORTH-WORDLIST). Then `S" SC2FOO" WL1 SEARCH-WORDLIST DROP DROP DUP .` → expect `-1 ` (SC2FOO IS in WL1; xt found and `=` against itself yields `-1`). Tests 825, 826.
    - **T-SC3 — SET-CURRENT does NOT change search order** (AC #3 / AC #4 distinction): `WORDLIST CONSTANT WL2   WL2 SET-CURRENT   : SC3BAR 33 ;   FORTH-WORDLIST SET-CURRENT   SC3BAR .` → expect output containing `SC3BAR ?` and `error -13: undefined word` (SC3BAR is in WL2 but search order only has FORTH-WORDLIST so FIND misses). Then `WL2 1 SET-ORDER   SC3BAR .` → expect `33 ` (now WL2 is in the search order, FIND hits, executes). Tests 827, 828. Reset via `FORTH-WORDLIST 1 SET-ORDER` + `FORTH-WORDLIST SET-CURRENT` afterwards.
    - **T-DEF1 — DEFINITIONS sets current to slot 0** (AC #4): `WORDLIST CONSTANT WL3   WL3 1 SET-ORDER   DEFINITIONS   GET-CURRENT WL3 = .` → expect `-1 `. Reset afterwards. Test 829.
    - **T-DEF2 — DEFINITIONS sequence: change order, change current to top, define** (AC #4 / AC #5 cooperative): `WORDLIST CONSTANT WL4   FORTH-WORDLIST WL4 2 SET-ORDER   DEFINITIONS   : DEF2BAZ 88 ;   FORTH-WORDLIST 1 SET-ORDER   FORTH-WORDLIST SET-CURRENT   S" DEF2BAZ" FORTH-WORDLIST SEARCH-WORDLIST .` → expect `0 ` (DEF2BAZ landed in WL4 because DEFINITIONS made WL4 the current at definition time; FORTH-WORDLIST does not have it). Test 830.
    - **T-CREATE-CONSTANT-VARIABLE-MARKER — CREATE-class words honour SET-CURRENT** (AC #5 broader coverage): for each of `CREATE`, `CONSTANT`, `VARIABLE`, `MARKER`, define a sample into a custom WL5, switch back, prove it's not in FORTH-WORDLIST and IS in WL5. Or condense to a single composite: `WORDLIST CONSTANT WL5   WL5 SET-CURRENT   CREATE CR5A   42 CONSTANT CO5B   VARIABLE VA5C   MARKER MK5D   FORTH-WORDLIST SET-CURRENT   S" CR5A" FORTH-WORDLIST SEARCH-WORDLIST .   S" CO5B" FORTH-WORDLIST SEARCH-WORDLIST .   S" VA5C" FORTH-WORDLIST SEARCH-WORDLIST .   S" MK5D" FORTH-WORDLIST SEARCH-WORDLIST .` → expect four `0 ` (none are in FORTH-WORDLIST). Then four `S" <name>" WL5 SEARCH-WORDLIST DROP DROP DUP .` → expect four `-1 ` (each is in WL5). Tests 831, 832, 833, 834 (or condense to fewer).
    - **T-COMP-ERROR — error-recovery rolls back the right wordlist** (AC #6): `WORDLIST CONSTANT WL6   WL6 SET-CURRENT   : CE6FOO BOGUSWORD ;   FORTH-WORDLIST SET-CURRENT` → REPL output should contain `BOGUSWORD ?` and `error -13: undefined word`; recovery via `1 2 + .` should print `3 ` (REPL alive). Then `S" CE6FOO" WL6 SEARCH-WORDLIST .` → expect `0 ` (the partial CE6FOO header was rolled back from WL6, not from FORTH-WORDLIST). Test 835.
    - **T-DEF-DEPTH0 — DEFINITIONS with depth=0** (AC #4 edge case (a)): `0 SET-ORDER DEFINITIONS GET-CURRENT 0 = .` → expect `-1 ` (current is now wid=0; defining anything subsequently would crash). Then immediately reset via `FORTH-WORDLIST 1 SET-ORDER   FORTH-WORDLIST SET-CURRENT` and verify recovery via `: TWREC 9 ; TWREC .` → expect `9 `. Test 836. (This test confirms the AC #4 pick (a) "match the standard, no guard" — verify the wid-of-zero case is reachable but recoverable.)

    Concrete test-ID assignment (continuing from 822):
    - **Test 823 — T-GC1**: GET-CURRENT initial = FORTH-WORDLIST.
    - **Test 824 — T-SC1**: SET-CURRENT/GET-CURRENT round-trip.
    - **Test 825 — T-SC2a**: `:` lands in WL1 (negative — not in FORTH-WORDLIST).
    - **Test 826 — T-SC2b**: `:` lands in WL1 (positive — in WL1).
    - **Test 827 — T-SC3a**: SET-CURRENT does not change search order (negative — FIND miss when search order stale).
    - **Test 828 — T-SC3b**: SET-CURRENT does not change search order (positive — FIND hit after SET-ORDER).
    - **Test 829 — T-DEF1**: DEFINITIONS sets current to slot 0.
    - **Test 830 — T-DEF2**: DEFINITIONS-driven partition with depth=2 search order.
    - **Test 831 — T-CCV-CREATE**: CREATE in custom wordlist (negative).
    - **Test 832 — T-CCV-CONSTANT**: CONSTANT in custom wordlist (negative).
    - **Test 833 — T-CCV-VARIABLE**: VARIABLE in custom wordlist (negative).
    - **Test 834 — T-CCV-MARKER**: MARKER in custom wordlist (negative).
    - **Test 835 — T-COMP-ERROR**: COMP-ERROR rollback targets correct wordlist.
    - **Test 836 — T-DEF-DEPTH0**: DEFINITIONS with depth=0 (edge case — wid=0 reachable, REPL recovers).

    Optional condensations: T-CCV-* may be merged into a single composite test (one Makefile entry; ~4 expected substrings). Final pick recorded in Completion Notes Task 11. Target N = 14; dev agent may choose 12 or 14 based on T-CCV-* condensation pick.

15. **Given** the ANS stack-effect and behaviour contract for `GET-CURRENT` / `SET-CURRENT` / `DEFINITIONS`,
    **when** the implementation is verified against DPANS94,
    **then** the dev agent reads §16.6.1.1643 (GET-CURRENT), §16.6.1.2193 (SET-CURRENT), §16.6.1.1180 (DEFINITIONS) **before writing code** and confirms:
    - `GET-CURRENT ( -- wid )` — pushes the compilation wordlist's wid; no other state change.
    - `SET-CURRENT ( wid -- )` — replaces the compilation wordlist with `wid`; subsequent definitions are added to the wordlist identified by `wid`.
    - `DEFINITIONS ( -- )` — set the compilation wordlist to be the same as the first wordlist in the search order (slot 0). No stack effect; no error specified for empty search order (depth=0 → wid=0 → undefined behaviour on next definition; matches AC #4 pick (a)).

    Per `feedback_systematic_reference_check.md` — read the spec, do not paraphrase from memory. Documented in Completion Notes Task 14.

16. **Given** the `feedback_adversarial_review.md` discipline ("reviews MUST find things; absence of findings is suspect"),
    **when** Story 12.4's review runs,
    **then** **at least 1-2 LOW/MEDIUM findings are expected**. Likely candidates the review must probe:
    - **(a) `build_header` IY-relative load correctness.** The pre-edit `LD BC, forth_wordlist + WORDLIST_BUCKET0` is a 16-bit immediate; the post-edit reads `(IY+UserArea.current_wordlist)` (lo and hi bytes) and adds `WORDLIST_BUCKET0`. The lo/hi byte order matters; the `ADD HL, BC` interaction with the bucket-index×2 already in HL also matters. Probe: hand-trace the bucket-address computation for a known-bucket name (e.g., `: TWFOO ;`); confirm the post-edit sequence yields the SAME final HL value as pre-edit when `current_wordlist == forth_wordlist`. **HIGH if found** (any defect here breaks every definition).
    - **(b) `bh_wid` scratch-DW lifecycle.** `bh_wid` is captured at build_header time. If a compile error happens BEFORE build_header completes (e.g., zero-length name → `.bh_no_name` at `:157-159`), `bh_wid` may hold a stale value from a previous build_header invocation. Probe: trace `.bh_no_name` — `bh_wid` is not used in the zero-length-name path (the `.bh_no_name` SCFs and RETs without entering the bucket-restore path); but verify `colon_saved_wid` / `asm_saved_wid` are not consumed in error paths that don't use them either.
    - **(c) `w_COMP_ERROR_cf` rollback against the saved wid.** If the user does `WL1 SET-CURRENT : FOO BOGUSWORD ;` and BOGUSWORD triggers COMP-ERROR, the rollback must restore WL1's bucket head — not FORTH-WORDLIST's. Probe: test 835 (T-COMP-ERROR); also probe that `current_wordlist` itself is NOT changed by COMP-ERROR (a partial-definition cleanup should not silently switch the user's compilation wordlist back to FORTH-WORDLIST — keep `current_wordlist` as user-set).
    - **(d) `asm_unlink_labels` against single saved wid.** All LABELs created during one CODE block belong to the same wordlist (the one current at CODE time). Probe: define a CODE block in a custom wordlist, add 2-3 LABELs; force a CODE-error (BOGUSWORD inside CODE); verify the LABEL bucket-restores all target the custom wordlist, not FORTH-WORDLIST. **MEDIUM if found** (assembler error-recovery is a less-common path).
    - **(e) `MARKER` snapshot scope.** Per AC #8 pick (a), MARKER snapshots only FORTH-WORDLIST. A test should verify: `WORDLIST CONSTANT WLM   WLM SET-CURRENT   MARKER MMK   : INWLM 5 ;   MMK   S" INWLM" WLM SEARCH-WORDLIST .` → expect `0 ` if pick (a) holds (MARKER restored FORTH-WORDLIST only — but wait, the MARKER itself was created in WLM, so MARKER's restore-target is WLM's saved buckets … but pick (a) says snapshot is FORTH-WORDLIST's bucket array regardless of current_wordlist at MARKER-create time). **Pick (a) is functionally a documented limitation, not a defect.** The test's purpose is to PROVE the limitation is scoped — i.e., MMK (which lives in WLM) DOES roll back FORTH-WORDLIST regardless. This is the "limitation visible to the user" that the docstring documents. **LOW if found** (pre-disclosed; doc-fix only).
    - **(f) Citation discipline.** Per CCD-3 / NFR17, all three new words carry their ANS §16.6.1.{1643,2193,1180} citations. Probe: `grep -nE 'ANS Forth.*16\.6\.1\.(1643|2193|1180)' src/wordlists.asm` returns 3 hits.
    - **(g) UserArea offset stability.** AC #1 mandates the new field is appended at the END of the struct (after Story-12.3's `search_order_depth` / `search_order`). Verify post-edit: `(IY+UserArea.state)`, `(IY+UserArea.base)`, `(IY+UserArea.here)`, `(IY+UserArea.search_order_depth)`, `(IY+UserArea.search_order)`, etc. — none of these IY-relative offsets should change. Any existing-field offset change is a regression of architectural-impact severity.
    - **(h) Cold-start init order.** New init code in `src/antforth.asm` must run AFTER IY = user_area is set up (`:40`) and AFTER the SEARCH-ORDER init at `:83-107` (per Story 12.3) and BEFORE the test-mode / cold_thread NEXT (`:112-122`). The new "8e. CURRENT-WORDLIST init" lands between the SEARCH-ORDER zero-fill loop end (`:107`) and the "9. FORTH-WORDLIST is pre-populated" comment at `:109`.
    - **(i) Forth-wordlist case is regression-clean.** With `current_wordlist == forth_wordlist` (default), every existing 831 REPL test must pass — proving the `build_header` parameterisation is bit-exactly compatible with the pre-edit hard-coded path. Probe: full `make test-repl` post-edit; if any of tests 802, 803, 804, 805 (FORTH-WORDLIST-default tests from Story 12.1) fail, root-cause immediately — the parameterisation has a defect.

    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale. Recorded in Completion Notes Task 9.

17. **Given** the `feedback_systematic_reference_check.md` discipline ("'Complete X' story specs must cross-reference the authoritative manual, not enumerate from memory"),
    **when** the dev agent surveys the new words against ANS Forth 1994 §16.6.1.1643 (GET-CURRENT), §16.6.1.2193 (SET-CURRENT), §16.6.1.1180 (DEFINITIONS),
    **then** the implementation is cross-referenced against the actual standard text — not against memory or against the epic spec alone. Stack effects and the DEFINITIONS-targets-slot-0 contract are confirmed against the spec. Documented in Completion Notes Task 14.

18. **Given** the `feedback_follow_process.md` discipline ("Don't ask permission for obvious next steps; just execute the workflow"),
    **when** the dev agent encounters edge cases (the AC #1 USER-variable name pick; the AC #4 DEFINITIONS-with-depth-0 pick; the AC #7 single-vs-per-slot wid pick; the AC #8 MARKER-snapshot-scope pick; the AC #9 WORDS pick; the AC #11 DEFCODE insertion-point pick),
    **then** the dev agent picks the recommended option in the relevant AC and proceeds. All in-pass picks are recorded in Completion Notes per the Tasks below. Escalation to the project lead is reserved for the structural-load-bearing case (AC #19).

19. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 12.3 AC #21),
    **when** small in-pass refinements are warranted (a comment polish; a missed citation; a one-line stack-effect adjustment; a fix to a UserArea-offset-related regression caught by AC #16(g)),
    **then** they are landed inside this story — no spawning further sub-stories. The exception: if the `build_header` parameterisation surfaces a pre-existing `build_header` defect (e.g., a corner case where the bucket-index computation miscomputes on a name length that hits a sjasmplus-pass-ordering edge), HALT and flag it as a finding for the project lead before scrubbing — the change becomes a separate decision, not in-pass cleanup. Documented in Completion Notes Task 8.

20. **Given** Story 12.4 follows Stories 12.1 / 12.2 / 12.3 in Epic 12 (which is `in-progress` per `sprint-status.yaml:181`),
    **when** Story 12.4 lands,
    **then** the sprint-status row `12-4-compilation-wordlist-control: backlog` flips to `ready-for-dev` at create-story (this story's creation), through `in-progress` (dev-pass start) and `review` (dev-pass close), to `done` (code-review close). No epic-status flip is needed (`epic-12: in-progress` already). Recorded in Completion Notes Task 12.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline + ANS spec read-through (AC: #12, #13, #15, #17)**
  - [x] 1.1 `wc -c build/antforth.com` — baseline 18,041 bytes (matches Story 12.3 Task 11.1).
  - [x] 1.2 `make test-repl` baseline = 831 PASS / 0 FAIL.
  - [x] 1.3 `make test` (assembly thread) — clean.
  - [x] 1.4 ANS specs cross-referenced (see Task 14 below).
  - [x] 1.5 UserArea reference grep recorded; post-edit deltas in Task 9.

- [x] **Task 2 — UserArea struct extension + cold-start init (AC: #1, #10)**
  - [x] 2.1 `src/structures.asm:32` — `current_wordlist DW 0` appended at END of STRUCT UserArea (after Story-12.3's `search_order DS 32`). Strict additive change.
  - [x] 2.2 `src/antforth.asm:109-113` — "8e. CURRENT-WORDLIST init" inserted between SEARCH-ORDER zero-fill (`:107`) and FORTH-WORDLIST pre-populated comment. 5-line block (comment + LD HL,nn + 2 × LD(IY+ofs),r). Default = `forth_wordlist`.
  - [x] 2.3 Build clean. `wc -c build/antforth.com` = 18,052 → +11 bytes (+2 struct, +9 init).
  - [x] 2.4 UserArea offset stability: existing field references unchanged.

- [x] **Task 3 — `w_GET_CURRENT` and `w_SET_CURRENT` DEFCODE blocks (AC: #2, #3, #11)**
  - [x] 3.1 `src/wordlists.asm:255-264` — `w_GET_CURRENT` DEFCODE: `PUSH BC; LD C,(IY+UserArea.current_wordlist); LD B,(IY+UserArea.current_wordlist+1); NEXT`. Citation: `; ANS Forth 1994 §16.6.1.1643   GET-CURRENT    ( -- wid )`.
  - [x] 3.2 `src/wordlists.asm:266-275` — `w_SET_CURRENT` DEFCODE: `CALL check_underflow; LD (IY+UserArea.current_wordlist),C; LD (IY+UserArea.current_wordlist+1),B; POP BC; NEXT`. Citation: `; ANS Forth 1994 §16.6.1.2193   SET-CURRENT    ( wid -- )`.
  - [x] 3.3 Build clean. Manual REPL probe `WORDLIST CONSTANT WL1 WL1 SET-CURRENT GET-CURRENT WL1 = .` → `-1 ok` (round-trip works).

- [x] **Task 4 — `w_DEFINITIONS` DEFCODE block (AC: #4, #11)**
  - [x] 4.1 `src/wordlists.asm:281-291` — `w_DEFINITIONS` DEFCODE: 4-line body using `LD A,(IY+ofs)`/`LD (IY+ofs),A` for the 2-byte slot copy. Citation: `; ANS Forth 1994 §16.6.1.1180   DEFINITIONS    ( -- )`.
  - [x] 4.2 AC #4 pick (a) documented in DEFCODE comment: "depth=0 yields wid=0; subsequent definitions UB per ANS — user error gate". **In-pass refinement**: actual depth=0 behaviour reads slot 0 unconditionally — slot 0 is NOT zeroed by SET-ORDER 0 (Story 12.3 zero-fill covers slots 1..15 only), so the cached value persists. At boot slot 0 = `forth_wordlist`. Test 836 probes this exact behaviour.
  - [x] 4.3 Build clean.

- [x] **Task 5 — `build_header` parameterisation (AC: #5)**
  - [x] 5.1 `src/compiler.asm:217-228` — bucket-address compute now reads wid from `(IY+UserArea.current_wordlist)`. Pattern: `LD C,(IY+ofs); LD B,(IY+ofs+1); LD (bh_wid),BC; INC BC; INC BC; ADD HL,BC` (cheaper than reload-from-bh_wid scheme; saves one `LD BC,(addr)` round-trip).
  - [x] 5.2 `src/compiler.asm:90` — `bh_wid: DW 0` scratch added to bh_* block. Captured in build_header at the bucket-address compute moment (single read; avoids redundant IY-relative loads in callers).
  - [x] 5.3 Default-case regression: test 802 (`: TWFOO 42 ; TWFOO .`) prints `42` post-edit. Build clean.

- [x] **Task 6 — `w_COMP_ERROR_cf` parameterisation (AC: #6)**
  - [x] 6.1 `src/compiler.asm:97` — `colon_saved_wid: DW 0` scratch added after `colon_saved_head`.
  - [x] 6.2 `src/compiler.asm:386-387` — colon prologue saves `bh_wid` → `colon_saved_wid` immediately after `colon_smudge_addr` save.
  - [x] 6.3 `src/compiler.asm:444-450` — `w_COMP_ERROR_cf` rollback now uses `LD BC,(colon_saved_wid); INC BC; INC BC` to compute bucket-array address.
  - [x] 6.4 Test 835 (T-COMP-ERROR) verifies rollback targets the saved wid (CE6FOO partial header rolled back from WL6, NOT FORTH-WORDLIST).

- [x] **Task 7 — `assembler.asm` parameterisation (AC: #7)**
  - [x] 7.1 `src/assembler.asm:84-87` — `asm_saved_wid: DW 0` scratch added in `asm_saved_*` block.
  - [x] 7.2 `src/assembler.asm:1255-1256` — CODE prologue saves `bh_wid` → `asm_saved_wid` after existing `asm_smudge_addr` save. The `:2287` site (LABEL build_header call) does NOT need a save — labels share the per-CODE-block wid captured at CODE entry.
  - [x] 7.3 `src/assembler.asm:430-433` — `asm_cleanup` (CODE-word bucket restore) uses `LD BC,(asm_saved_wid); INC BC; INC BC`.
  - [x] 7.4 `src/assembler.asm:847-849` — `asm_unlink_labels` LABEL bucket-restore uses `LD DE,(asm_saved_wid); INC DE; INC DE`. AC #7 pick honoured: single per-CODE-block wid (NOT per-slot).
  - [x] 7.5 Assembly-thread regression `make test` clean.

- [x] **Task 8 — Optional WORDS docstring update + MARKER docstring update (AC: #8(a), #9(a))**
  - [x] 8.1 `src/dictionary.asm:195-204` — WORDS docstring updated to closure-note (Story 12.4 landed; WORDS scoped to FORTH-WORDLIST per AC #9 pick (a); workaround documented; revisit when Phase-3 hardware wordlists land).
  - [x] 8.2 `src/system.asm:23-26` — MARKER docstring extended with Story 12.4 limitation note (snapshot scope = FORTH-WORDLIST only regardless of CURRENT-WORDLIST per AC #8 pick (a)).
  - [x] 8.3 `docs/throw-codes.md` — no edits (no new THROW codes introduced).

- [x] **Task 9 — Adversarial self-review (AC: #16)**
  - [x] 9.1 Hand-trace `build_header` post-edit byte sequence for `: TWFOO ;`: post-edit reads `current_wordlist` (default = `forth_wordlist`) into BC, captures into `bh_wid`, INC BC twice (= +WORDLIST_BUCKET0), ADD HL,BC. Final HL = pre-edit HL bit-exactly when `current_wordlist == forth_wordlist`. **Verified by test 802** (`: TWFOO 42 ; TWFOO .` → `42 `) and the entire 831-test baseline regression.
  - [x] 9.2 `bh_wid` lifecycle: `.bh_no_name` path SCFs and RETs without reading `bh_wid` — clean. Colon prologue runs only on build_header success; `colon_saved_wid` save happens BEFORE any error-throw window opens. CODE prologue similarly — `asm_saved_wid` written only on build_header success. **No stale-read paths exist.**
  - [x] 9.3 Probe via `WORDLIST CONSTANT WLA WLA SET-CURRENT CODE BOGUS … END-CODE` (deliberate bogus inside CODE) confirmed CODE error recovery doesn't crash and REPL recovers via `1 2 + .` = `3`. CODE-into-custom-wordlist verifies build_header parameterisation flows through assembler path.
  - [x] 9.4 MARKER snapshot scope = FORTH-WORDLIST-only (test 834 probes the limitation): MARKER's *header* lands in custom wordlist (AC #5), but the snapshot/restore body operates on FORTH-WORDLIST regardless. **Pre-disclosed limitation per AC #8 pick (a); documented in MARKER docstring.**
  - [x] 9.5 Citation grep: `grep -nE 'ANS Forth.*16\.6\.1\.(1643|2193|1180)' src/wordlists.asm` returns 3 hits (lines 257, 268, 281). PASS.
  - [x] 9.6 UserArea offset stability: post-edit grep shows new `current_wordlist` references in 5 files (compiler/assembler/wordlists/antforth/structures); existing field references unchanged in semantics. PASS.
  - [x] 9.7 Cross-stack regression: `make test-repl` = **845 PASS / 0 FAIL** (831 baseline + 14 new); `make test` (assembly thread) clean.
  - [x] 9.8 Findings triage in Task 13 below.

- [x] **Task 10 — Tests + Makefile wire-in (AC: #14)**
  - [x] 10.1 `tests/wordlist_tests.fth` — Section 8 appended with 14 tests (T-GC1, T-SC1, T-SC2a, T-SC2b, T-SC3a, T-SC3b, T-DEF1, T-DEF2, T-CCV-CREATE, T-CCV-CONSTANT, T-CCV-VARIABLE, T-CCV-MARKER, T-COMP-ERROR, T-DEF-DEPTH0).
  - [x] 10.2 `Makefile` — 14 entries 823..836 wired with `grep -q` anchored on REPL `ok` prompts (per Story 12.2 CR-L2 carryover).
  - [x] 10.3 `make test-repl` post-edit = 845 PASS / 0 FAIL.
  - [x] 10.4 No baseline regression (831 baseline tests all PASS).

- [x] **Task 11 — Binary delta + sprint-status flips + plain-language verdict (AC: #12, #20)**
  - [x] 11.1 `wc -c build/antforth.com` post-edit = **18,184 bytes** → +143 bytes vs 18,041 baseline.
  - [x] 11.2 +143 is **23 bytes over the +120 envelope**. Cause: the spec's component breakdown (~+85 expected) understated DEFCODE macro overhead — each new DEFCODE costs ~14 bytes of dictionary header (hash_link + count_flags + 11-char name) on top of its body. Three DEFCODEs × 14 ≈ 42 bytes baseline that the rough budget rolled into "body". Per-component actuals: GET-CURRENT ≈ 24 bytes, SET-CURRENT ≈ 27 bytes, DEFINITIONS ≈ 29 bytes (sum 80; spec said 6+10+12 = 28). The rest of the spec breakdown is broadly correct. Net delta is well within the next budget round (Phase-2 binary headroom ≈ 44 KB free) — no refactor warranted. Justified per AC #12 envelope-overshoot escape clause.
  - [x] 11.3 Sprint-status: `12-4-compilation-wordlist-control` flipped `ready-for-dev → in-progress → review` in `_bmad-output/implementation-artifacts/sprint-status.yaml`.
  - [x] 11.4 Plain QA verdict: 845 PASS / 0 FAIL on REPL suite; 0 errors on assembly suite; binary +143 bytes (over budget by 23, justified). Story complete.

- [x] **Task 12 — In-pass-fix discipline + escalation gate (AC: #18, #19)**
  - [x] 12.1 Picks table in Completion Notes below.
  - [x] 12.2 No build_header pre-existing defect surfaced — escalation gate not triggered.
  - [x] 12.3 No sub-story spawning. All in-pass refinements landed inside Story 12.4.

- [x] **Task 13 — Per-AC verdict table (AC: #16, #20)**
  - [x] 13.1 Verdict table in Completion Notes below.
  - [x] 13.2 Findings triage table in Completion Notes below.

- [x] **Task 14 — ANS spec cross-reference (AC: #15, #17)**
  - [x] 14.1 §16.6.1.1643 GET-CURRENT (`( -- wid )`): impl matches — push compilation wordlist wid; no other state change.
  - [x] 14.2 §16.6.1.2193 SET-CURRENT (`( wid -- )`): impl matches — set compilation wordlist; no error specified.
  - [x] 14.3 §16.6.1.1180 DEFINITIONS (`( -- )`): impl matches — set compilation wordlist = first wordlist in search order. AC #4 pick (a): unconditional read of slot 0; depth=0 yields whatever is cached in slot 0 (NOT zero-flushed by SET-ORDER 0). Test 836 probes this exact behaviour.

## Dev Notes

### Story summary

This is the **fourth story in Epic 12** — the compilation wordlist control lands here, building on Story 12.1's per-wordlist struct, Story 12.2's `WORDLIST` / `SEARCH-WORDLIST`, and Story 12.3's search-order infrastructure. Story 12.4 wires three new things:

1. **The `current_wordlist` USER variable** (AC #1 — the data backing the compilation wordlist; lives in `UserArea` immediately after Story-12.3's search-order fields).
2. **The user-facing words `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`** (AC #2-4 — read/write the compilation wordlist; DEFINITIONS targets slot 0 of the search order).
3. **The `build_header` parameterisation** — `:`, `CODE`, `CREATE`, `VARIABLE`, `CONSTANT`, `MARKER` all funnel through `build_header`, which now uses `current_wordlist` instead of the hard-coded `forth_wordlist + WORDLIST_BUCKET0`. The compile-error rollback paths (`w_COMP_ERROR_cf`, assembler CODE-error recovery, `asm_unlink_labels`) are correspondingly parameterised on a saved wid (`bh_wid` → `colon_saved_wid` / `asm_saved_wid`).

**Implementation surface is moderate**: ~6 lines for GET-CURRENT, ~10 lines for SET-CURRENT, ~12 lines for DEFINITIONS, ~+8 bytes for the `build_header` parameterisation, ~+8 bytes for `w_COMP_ERROR_cf`, ~+12 bytes for two assembler error-recovery sites, plus the UserArea struct extension (1 field) and the cold-start init (~10 bytes), plus three new scratch DWs (`bh_wid`, `colon_saved_wid`, `asm_saved_wid`). Total estimated **+85 bytes** with **+50..+120 envelope**.

**The critical correctness gate** is AC #13 (NFR9 zero-regression): after parameterising `build_header`, every existing 831 REPL tests must still pass — proving that the `current_wordlist == forth_wordlist` default case is bit-exactly compatible with the pre-edit hard-coded path.

The regression net is the existing 831-test REPL suite plus 14 new compilation-wordlist tests (per AC #14).

### Architecture decisions driving this story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§326-330 E12-D1: Per-wordlist hash table layout.** Story 12.4 consumes the existing struct via `current_wordlist` (a wid). **No struct-shape changes.**
- **§332-336 E12-D2: Search-order storage.** Story 12.4 reads `search_order[0]` for `DEFINITIONS`; no changes to the search-order struct.
- **§338-342 E12-D3: Wordlist identifier representation.** `wid` = raw address. `current_wordlist` is also a 16-bit pointer — same representation.
- **§802-804 Integration patterns.** "Dictionary lookup is parameterised on a wordlist-struct address (Epic 12); callers pass the struct, `dictionary.asm` does the hash and linked-list walk." Story 12.4's `build_header` parameterisation is the natural extension on the WRITE side: every header insertion now consults `current_wordlist` for the bucket-array address.
- **§47 FR23-FR29, FR31 (Epic 12).** Story 12.4 delivers FR25 (`GET-CURRENT` / `SET-CURRENT`) and FR26 (`DEFINITIONS`).

### `bh_wid` lifecycle and error-recovery discipline

The `build_header` subroutine inserts a dictionary header into the bucket array of the wordlist identified by `current_wordlist`. The wid used for insertion is captured into a new scratch DW `bh_wid` so that error-recovery paths can target the SAME wordlist:

- **Colon (`:`) error recovery** — saves `bh_wid` into `colon_saved_wid` in the colon prologue (after the existing `colon_saved_here` / `colon_saved_bucket` / `colon_saved_head` saves). `w_COMP_ERROR_cf` reads `colon_saved_wid` to compute the bucket-array address for the rollback.
- **CODE error recovery** — saves `bh_wid` into `asm_saved_wid` in the CODE prologue. The assembler's `asm_recover` (or equivalent) at `src/assembler.asm:410-441` reads `asm_saved_wid` to compute the bucket-array address for the rollback.
- **LABEL unlink (asm_unlink_labels)** — reads `asm_saved_wid` (single per-CODE-block wid). All LABELs created during one CODE block live in the same wordlist as the CODE word itself; mid-CODE `SET-CURRENT` is not supported (see "Mid-CODE SET-CURRENT discipline" below).
- **MARKER** — uses `build_header` for the header insertion; the snapshot/restore is FORTH-WORDLIST-only per AC #8 pick (a) (documented limitation; not driven by `bh_wid`).

`bh_wid` is a one-off save-point per build_header call; it does NOT persist across multiple build_header invocations — but the `colon_saved_*` and `asm_saved_*` scratch DWs DO persist for the lifetime of one definition (colon, CODE, etc.) so the error-recovery path reads them, not `bh_wid` directly.

**Lifecycle invariant**: `bh_wid` is set in `build_header`'s success path; the `.bh_no_name` early-exit at `src/compiler.asm:157-159` does NOT set `bh_wid` (it SCFs and RETs before the bucket compute). Callers that branch on the build_header carry-flag (`JR C, .colon_no_name` etc.) skip the `colon_saved_wid` save entirely — so reading a stale `bh_wid` from a prior build_header invocation is impossible in the error path (the error path raises -16 THROW directly without touching the recovery scratch).

### Mid-CODE SET-CURRENT discipline

`SET-CURRENT` is a definition-time directive: `<wid> SET-CURRENT` in the REPL changes the compilation wordlist for subsequent `:` / `CODE` / `CREATE` / etc. Inside a `CODE ... END-CODE` block, the assembler is in a different mode (`asm_mode != 0`), and `SET-CURRENT` is not interpreted as a "switch wordlist for the in-progress CODE word's labels" — it would be interpreted as a normal Forth word in the assembler's interpret context.

**Story 12.4's stance**: the in-progress CODE word's wid (= `current_wordlist` at CODE time) is captured into `asm_saved_wid` by the CODE prologue, and `asm_unlink_labels` reads `asm_saved_wid` for ALL labels in the block. If a user calls `SET-CURRENT` mid-CODE-block, the LABELs created BEFORE the SET-CURRENT call belong to the original wid (correctly tracked); LABELs created AFTER the SET-CURRENT call land in the new wid's bucket array (per AC #5 build_header parameterisation) — but `asm_unlink_labels` will try to unlink them from the original wid's bucket array, causing dictionary corruption.

This is a **footgun**, not a defect — the assembler's design assumes `SET-CURRENT` is not invoked mid-CODE. **Recommendation**: do not document mid-CODE SET-CURRENT in the public docs; if a user encounters it (very unlikely in normal use), the AC #19 escalation gate fires. Per AC #7 pick (single per-CODE-block wid), this is the cheapest implementation that handles the design-intent case.

If a user case for mid-CODE SET-CURRENT emerges in Phase 3 (MicroBeast hardware wordlists?), revisit by extending each LABEL slot in `asm_label_dict` to capture its wid alongside the bucket index — AC #7's heavier alternative.

### `src/wordlists.asm` extension layout

Story 12.1 / 12.2 / 12.3 / 12.4 all append to the same file, in order:

- (Story 12.1) File header documentation
- (Story 12.1) Layout EQUs
- (Story 12.2) `w_WORDLIST` DEFCODE block
- (Story 12.2) `w_SEARCH_WORDLIST` DEFCODE block
- (Story 12.2) `sw_saved_ip` scratch DW
- (Story 12.3) `w_FORTH_WORDLIST` DEFCODE block
- (Story 12.3) `w_GET_ORDER` DEFCODE block
- (Story 12.3) `w_SET_ORDER` DEFCODE block + `do_search_order_overflow` raise site
- **(Story 12.4) NEW: `w_GET_CURRENT` DEFCODE block**
- **(Story 12.4) NEW: `w_SET_CURRENT` DEFCODE block**
- **(Story 12.4) NEW: `w_DEFINITIONS` DEFCODE block**
- (Story 12.3) `srch_saved_ip:` scratch DW (shared across GET-ORDER / SET-ORDER)
- (Story 12.1) `forth_wordlist:` struct emission (with LUA `_hash_buckets[]` expansion at `ALLPASS`)

The emission-order discipline (DEFCODEs BEFORE the struct emission) carries through. Per Story 12.1 Finding F2 + subsequent verifications: as long as new DEFCODEs precede the `forth_wordlist:` LABEL inside the file, the `_hash_buckets[]` table is fully populated when the struct's bucket-array is emitted. Story 12.4 adds three more entries to the FORTH-WORDLIST bucket array (assuming GET-CURRENT / SET-CURRENT / DEFINITIONS are defined into FORTH-WORDLIST at build time, which they are — `_hash_buckets[]` is the build-time bucket array, populated by every DEFCODE / DEFWORD invocation).

### Test discipline for Story 12.4

Per `feedback_repl_tests_preferred.md`: Story 12.4 adds REPL-piped Forth tests to `tests/wordlist_tests.fth`. **No new assembly tests.**

Per `feedback_plain_qa_language.md`: assertions are stated plainly with measured value + gate + conclusion. Per `feedback_adversarial_review.md`: Story 12.4's review has clear probe categories per AC #16; expect ≥ 1-2 LOW/MEDIUM findings.

Per Story 12.2 Code-Review CR-L2 follow-up: `grep -q` patterns in the Makefile should anchor on the REPL `ok` prompt (e.g., `'1  ok'`) rather than loose fragments.

### `build_header` parameterisation considerations

The pre-edit byte sequence at `src/compiler.asm:215-221`:

```
        LD      L, A                            ; A = bucket index
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      BC, forth_wordlist + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &FORTH-WORDLIST.buckets[bucket]
        LD      (bh_bucket_addr), HL
```

The post-edit byte sequence (one viable shape):

```
        LD      L, A                            ; A = bucket index
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      C, (IY+UserArea.current_wordlist)
        LD      B, (IY+UserArea.current_wordlist+1)
        LD      (bh_wid), BC                    ; capture wid for error recovery
        INC     BC
        INC     BC                              ; BC = wid + WORDLIST_BUCKET0 (+= 2)
        ADD     HL, BC                          ; HL = &<current_wordlist>.buckets[bucket]
        LD      (bh_bucket_addr), HL
```

**Byte cost**: pre-edit 9 bytes for the `LD BC, immediate; ADD HL, BC; LD (bh_bucket_addr), HL` sequence (3 + 1 + 3); post-edit 12 bytes for `LD r,(IY+ofs)` × 2 (3+3) + `LD (bh_wid), BC` (3) + `INC BC; INC BC` (1+1) + `ADD HL, BC` (1) + `LD (bh_bucket_addr), HL` (3) = 15 bytes. Net delta: +6 bytes per build_header parameterisation site.

**Alternative**: load wid directly without `bh_wid` save, then reload from IY-relative for `colon_saved_wid` / `asm_saved_wid`. Saves 3 bytes inside `build_header`; costs 6 bytes at each save-point (colon prologue + CODE prologue) — net same. Recommendation: capture `bh_wid` once in `build_header` and reload from there.

### `w_COMP_ERROR_cf` parameterisation considerations

The pre-edit byte sequence at `src/compiler.asm:434-443`:

```
        ; --- 5.2: Restore hash bucket head ---
        LD      A, (colon_saved_bucket)
        LD      L, A
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      BC, forth_wordlist + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &FORTH-WORDLIST.buckets[bucket]
        LD      BC, (colon_saved_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B
```

The post-edit byte sequence:

```
        ; --- 5.2: Restore hash bucket head (saved wid from colon prologue) ---
        LD      A, (colon_saved_bucket)
        LD      L, A
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      BC, (colon_saved_wid)
        INC     BC
        INC     BC                              ; BC = wid + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &<saved_wid>.buckets[bucket]
        LD      BC, (colon_saved_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B
```

**Byte cost**: pre-edit `LD BC, immediate` (3 bytes) → post-edit `LD BC, (colon_saved_wid); INC BC; INC BC` (3 + 1 + 1 = 5 bytes). Net delta: +2 bytes.

The `assembler.asm:427` and `:844` parameterisations follow the same pattern (replace `LD BC, immediate` or `LD DE, immediate` with `LD BC,(asm_saved_wid); INC BC; INC BC` — net +2 bytes per site).

### Project Structure Notes

- **Edits / additions for this story:**
  - **Modified:** `src/structures.asm` — append `current_wordlist DW 0` to the END of `STRUCT UserArea` (after Story-12.3's `search_order DS 32`). Strict additive change; preserves all existing offsets per AC #1 / AC #16(g).
  - **Modified:** `src/antforth.asm` — insert "8e. CURRENT-WORDLIST init" between `:107` and `:109` (after Story-12.3's SEARCH-ORDER zero-fill loop, before the FORTH-WORDLIST pre-populated comment).
  - **Modified:** `src/wordlists.asm` — append three new DEFCODE blocks (`w_GET_CURRENT`, `w_SET_CURRENT`, `w_DEFINITIONS`) at the picked location per AC #11 (recommended: after `do_search_order_overflow:` and before `srch_saved_ip:`).
  - **Modified:** `src/compiler.asm` — (a) add `bh_wid: DW 0` to the `bh_*` scratch block; (b) add `colon_saved_wid: DW 0` to the colon-recovery scratch block; (c) parameterise `build_header` bucket-address compute on `current_wordlist`; (d) add `colon_saved_wid` save in the colon prologue; (e) parameterise `w_COMP_ERROR_cf` rollback on `colon_saved_wid`.
  - **Modified:** `src/assembler.asm` — (a) add `asm_saved_wid: DW 0` to the `asm_saved_*` scratch block; (b) save `bh_wid` into `asm_saved_wid` in the CODE prologue (around `:1240` and `:2287`); (c) parameterise `:427` (CODE-word bucket restore) on `asm_saved_wid`; (d) parameterise `:844` (LABEL bucket-restore) on `asm_saved_wid`.
  - **Optionally modified:** `src/dictionary.asm:195-202` — update WORDS docstring's forward-pointer comment to a closure-note (Story 12.4 has landed; WORDS scope kept at FORTH-WORDLIST per AC #9 pick (a)).
  - **Optionally modified:** `src/system.asm:18-22` (MARKER docstring) — add Story-12.4 limitation note per AC #8 pick (a).
  - **Modified:** `tests/wordlist_tests.fth` — append Section 8 (Story 12.4) with 14 (or condensed 12) tests per AC #14.
  - **Modified:** `Makefile` — add 14 (or 12) new REPL test entries (823-836).
  - **No new files; no new EQUs in `src/wordlists.asm`** (the layout EQUs were introduced in Story 12.1).
  - **Sprint-status flips:** `12-4-…: ready-for-dev → in-progress → review → done` (story lifecycle); `epic-12` stays `in-progress`.
- **Alignment with unified project structure:** Matches `architecture.md:702` (Epic 12 additions in `src/wordlists.asm`); matches `architecture.md:722` (`tests/wordlist_tests.fth`). The UserArea extension preserves existing offsets per AC #1 / AC #16(g); no detected conflicts.
- **No source-tree restructure.**

### Previous-Story Intelligence — Story 12.3 (immediate predecessor)

Key inherited learnings relevant to Story 12.4:

1. **UserArea extension discipline.** Story 12.3 appended two fields at the END of the STRUCT (after `pic_buf`). Story 12.4 follows the same discipline — append `current_wordlist` AFTER Story-12.3's `search_order`. AC #16(g) gate verifies via reference grep.

2. **DEFCODE ordering before `forth_wordlist:` LABEL.** Story 12.3 placed three new DEFCODEs before the `forth_wordlist:` struct emission to satisfy the `_hash_buckets[]` LUA-pass-ordering requirement. Story 12.4 follows the same discipline — three more DEFCODEs go BEFORE the struct. AC #11 gate.

3. **Cold-start init ordering.** Story 12.3 inserted "8d. SEARCH-ORDER init" in `src/antforth.asm` between the CATCH-TOP block and the FORTH-WORDLIST comment. Story 12.4 inserts "8e. CURRENT-WORDLIST init" immediately after Story-12.3's init block. AC #10 gate.

4. **Verdict tables in Completion Notes.** Mirror Story 12.3's per-AC verdict table (AC | Gate | Evidence | Verdict columns) and per-finding triage table (Severity | Category | Description | Resolution).

5. **Per-task evidence with explicit grep / wc commands.** "Ran command X, got output Y, here's the implication" — no hand-waving. Per `feedback_plain_qa_language.md`.

6. **Adversarial-review-finding triage table.** Story 12.3 Task 9 format replicated in Story 12.4 Task 9.

7. **Standards-compliance discipline** (`feedback_standards_compliance.md`): the 831-test baseline is non-negotiable. If a regression surfaces, debug at root cause; don't paper over. Specifically — the `build_header` parameterisation is the most regression-sensitive change in this story; AC #16(i) is the gate.

8. **Plain QA language** (`feedback_plain_qa_language.md`): plain "PASS" / "FAIL" / measured numbers — no florid audit phrasing.

9. **Adversarial review** (`feedback_adversarial_review.md`): zero findings would be suspect. Story 12.4 has clear probe categories per AC #16; expect ≥ 1-2 LOW/MEDIUM. The most likely finding categories: (a) `build_header` IY-relative load correctness; (b) `bh_wid` lifecycle in error paths; (c) MARKER scope limitation visibility.

10. **Follow the process** (`feedback_follow_process.md`): execute the recommended picks; don't ask permission for the six design picks (USER-var name, DEFINITIONS-with-depth-0, single-vs-per-slot wid, MARKER scope, WORDS scope, DEFCODE insertion point). The AC #18 list.

11. **REPL tests preferred** (`feedback_repl_tests_preferred.md`): Story 12.4 adds REPL-piped Forth tests in `tests/wordlist_tests.fth` — no new assembly tests.

12. **Design upfront** (`feedback_design_upfront.md`): the `current_wordlist` USER variable is sized at the canonical 16-bit wid representation (no growth needed for full Epic 12 scope). The `bh_wid` / `colon_saved_wid` / `asm_saved_wid` scratches are independent of the maximum number of wordlists. AC #1 / AC #5.

13. **Systematic reference check** (`feedback_systematic_reference_check.md`): cross-reference DPANS94 §16.6.1.1643 / §16.6.1.2193 / §16.6.1.1180 — **read the spec**, don't paraphrase from memory. The DEFINITIONS-targets-slot-0 contract is the spec text directly; verify by reading.

14. **TOS-in-register & DEPTH discipline** (`project_tos_in_register.md`): GET-CURRENT pushes 1 cell (DEPTH grows by 1); SET-CURRENT consumes 1 cell (DEPTH shrinks by 1); DEFINITIONS is a no-op on stack. `check_underflow` / `check_overflow` per Story 11.5.2 are the gate words.

15. **Standards citation discipline** (NFR17 / CCD-3): all three new words carry `; ANS Forth 1994 §16.6.1.{1643,2193,1180}` citations.

16. **No new THROW codes.** Story 12.4 introduces three new words but no new THROW codes — the existing -16 (zero-length name), -13 (undefined word), -14 (interpreting compile-only) cover all error paths. No `src/exception.asm` table edits; no `docs/throw-codes.md` edits.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md`: none of GET-CURRENT, SET-CURRENT, DEFINITIONS need EXX-bounded handler structure — they all run primary-set throughout. The `build_header` parameterisation runs in the primary set (build_header is called from EXX-saved colon prologue but build_header itself runs primary; the EXX-save / EXX-restore is at the colon (`w_COLON_cf`) level, not inside build_header). The `w_COMP_ERROR_cf` parameterisation is also primary-set (per `src/compiler.asm:469-471` comment block).

### Sjasmplus build-time considerations

The new DEFCODE blocks land inside `src/wordlists.asm` BEFORE the `forth_wordlist:` label. Per Story 12.1's pass-ordering analysis: DEFCODE macro expansion (per `src/macros.asm:75-86`) updates `_hash_buckets[]` at macro time; the `forth_wordlist:` LUA `ALLPASS` block at `src/wordlists.asm:262-267` runs at end-of-pass, reading `_hash_buckets[]`. Therefore as long as the new DEFCODEs precede the `forth_wordlist:` label inside the file, the bucket array correctly includes them.

The UserArea struct extension in `src/structures.asm` adds one field at the END of the STRUCT — sjasmplus's STRUCT directive computes offsets sequentially, so existing fields' offsets are preserved (AC #16(g) gate).

The `(IY+UserArea.current_wordlist)` IY-relative load and store: sjasmplus computes the offset at assembly time. The offset is `<sum of all preceding field sizes>` — currently `state(2) + base(2) + here(2) + latest(2) + tib_addr(2) + tib_len(2) + tib_in(2) + source_id(2) + hld(2) + catch_top(2) + pic_buf(PIC_BUF_SIZE) + search_order_depth(2) + search_order(32) = 20 + PIC_BUF_SIZE + 34 = 54 + PIC_BUF_SIZE`. Verify the offset fits the IY-displacement byte signed range (-128..+127). If not, refactor field order or use `IX`-relative as a fallback (unlikely needed; PIC_BUF_SIZE is small).

### Standards-citation discipline (NFR17 / CCD-3)

Story 12.4 introduces three ANS-derived citations:
- `GET-CURRENT` → `; ANS Forth 1994 §16.6.1.1643   GET-CURRENT`
- `SET-CURRENT` → `; ANS Forth 1994 §16.6.1.2193   SET-CURRENT`
- `DEFINITIONS` → `; ANS Forth 1994 §16.6.1.1180   DEFINITIONS`

All appear on the line preceding the relevant DEFCODE. No new THROW citations needed (no new -49-style codes in this story).

### References

- `_bmad-output/planning-artifacts/epics.md:1235-1265` — Story 12.4 authoritative spec (post-Story-11.5.5 redraft)
- `_bmad-output/planning-artifacts/epics.md:1133-1302` — Epic 12 charter + all 6 stories (redrafted)
- `_bmad-output/planning-artifacts/architecture.md:326-330` — E12-D1 (per-wordlist hash table layout)
- `_bmad-output/planning-artifacts/architecture.md:332-336` — E12-D2 (search-order storage — Story 12.4 reads slot 0 for DEFINITIONS)
- `_bmad-output/planning-artifacts/architecture.md:338-342` — E12-D3 (wid = struct address)
- `_bmad-output/planning-artifacts/architecture.md:702` — `src/wordlists.asm` Epic 12 file
- `_bmad-output/planning-artifacts/architecture.md:722` — `tests/wordlist_tests.fth` Epic 12 test file
- `_bmad-output/planning-artifacts/architecture.md:802-804` — Integration patterns (dictionary lookup parameterised on wordlist-struct address; build_header on the WRITE side)
- `_bmad-output/planning-artifacts/prd.md:411-412` — FR25 (`GET-CURRENT` / `SET-CURRENT`) and FR26 (`DEFINITIONS`)
- `_bmad-output/implementation-artifacts/12-1-…md` — Story 12.1 (struct, EQUs, `forth_wordlist:`)
- `_bmad-output/implementation-artifacts/12-2-…md` — Story 12.2 (WORDLIST, SEARCH-WORDLIST, shared helper)
- `_bmad-output/implementation-artifacts/12-3-…md` — Story 12.3 (FORTH-WORDLIST, GET-ORDER, SET-ORDER, FIND search-order walk); 18,041-byte / 831-PASS baseline
- `_bmad-output/implementation-artifacts/sprint-status.yaml:181-188` — Epic 12 row set
- `src/wordlists.asm:1-267` — Stories 12.1 + 12.2 + 12.3 contents (Story 12.4 appends three new DEFCODE blocks before line 260)
- `src/structures.asm:18-32` — UserArea STRUCT (Story 12.4 appends one field at the end)
- `src/antforth.asm:18-122` — cold_start (Story 12.4 inserts "8e. CURRENT-WORDLIST init" after `:107`)
- `src/compiler.asm:85-89` — `bh_*` scratch block (Story 12.4 appends `bh_wid: DW 0`)
- `src/compiler.asm:91-96` — colon-recovery scratch block (Story 12.4 appends `colon_saved_wid: DW 0`)
- `src/compiler.asm:107-277` — `build_header` (Story 12.4 parameterises bucket-address compute at `:215-221`)
- `src/compiler.asm:380-383` — colon prologue (Story 12.4 adds `colon_saved_wid` save)
- `src/compiler.asm:421-473` — `w_COMP_ERROR_cf` (Story 12.4 parameterises rollback at `:434-443`)
- `src/assembler.asm:410-441` — CODE-word error recovery (Story 12.4 parameterises `:427`)
- `src/assembler.asm:822-854` — `asm_unlink_labels` (Story 12.4 parameterises `:844`)
- `src/assembler.asm:1240` and `:2287` — CODE prologue's `build_header` calls (Story 12.4 adds `asm_saved_wid` save)
- `src/dictionary.asm:195-202` — WORDS docstring (Story 12.4 may update forward-pointer comment per AC #9 pick (a))
- `src/system.asm:18-22, 53-58` — MARKER docstring + snapshot path (Story 12.4 may update docstring per AC #8 pick (a); snapshot/restore body unchanged)
- `src/inner_interpreter.asm:115-146` — DOMARKER restore path (unchanged in Story 12.4 per AC #8 pick (a))
- `tests/wordlist_tests.fth:1-182` — Stories 12.1 + 12.2 + 12.3 tests (Story 12.4 appends Section 8)
- `Makefile` — REPL tests 802-822 (Stories 12.1 + 12.2 + 12.3) — Story 12.4 wires 823-836 in the same pattern
- DPANS94 §16.6.1.1643 — `GET-CURRENT` standard text
- DPANS94 §16.6.1.2193 — `SET-CURRENT` standard text
- DPANS94 §16.6.1.1180 — `DEFINITIONS` standard text
- Project memories:
  - `feedback_adversarial_review.md` — reviews MUST find things (AC #16)
  - `feedback_standards_compliance.md` — investigate root cause; never paper over (AC #13)
  - `feedback_systematic_reference_check.md` — read the ANS spec (Task 1.4 / Task 14)
  - `feedback_follow_process.md` — execute recommended picks (AC #18)
  - `feedback_design_upfront.md` — current_wordlist sized for full Epic 12 scope (AC #1)
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth tests, not assembly threads (AC #14)
  - `feedback_plain_qa_language.md` — measured value + gate + conclusion (AC #12 / Task 11)
  - `feedback_stabilisation_interlude.md` — n/a (no THROW codes added in Story 12.4)
  - `project_tos_in_register.md` — BC-as-TOS discipline; DEPTH math (GET-CURRENT / SET-CURRENT)
  - `project_phase2_scope.md` — Epic 12 = Search-Order Wordset (post-redraft); Story 12.4 delivers FR25 / FR26
  - `project_assembler_keep_assembly.md` — `src/assembler.asm` stays as-is structurally; Story 12.4 only parameterises two bucket-address sites
  - `project_asm_hash_dispatch_hack.md` — Story-10.7 asm-`#` hack permanent; unaffected by Story 12.4 (no edits to the hack)
  - `feedback_defword_cf_label.md` — n/a (Story 12.4 introduces only DEFCODE words, no DEFWORD)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- Two test-line splits required during Task 10 wire-in: tests 829, 832, 833, 834 each had REPL input lines exceeding 128-byte TIB, causing parser to truncate mid-word ("SET-C" + "URRENT"). Fix: split each into two `printf` `%s\r\n` arguments.
- Test 836 (T-DEF-DEPTH0) initial spec assumed `0 SET-ORDER DEFINITIONS GET-CURRENT 0 = .` would yield wid=0. Actual behaviour: `SET-ORDER 0` updates depth field only — slot 0 retains its pre-existing value (FORTH-WORDLIST from cold-start init step 8d, since Story 12.3 zero-fill only covers slots 1..15). Test reworded to assert `T836 FORTH-WORDLIST = .` → `-1` (matches AC #4 pick (a) "read slot 0 unconditionally" semantics). Spec assumption corrected in-pass.

### Completion Notes List

#### Picks recorded (AC #18 list)

| AC  | Pick | Decision | Rationale |
|-----|------|----------|-----------|
| #1  | USER-var name | `current_wordlist` | Recommended ANS-style short-form; appended at end of UserArea STRUCT preserving all prior offsets. |
| #4  | DEFINITIONS depth=0 behaviour | (a) Read slot 0 unconditionally | Matches ANS spec text. Discovery: slot 0 is NOT zeroed by SET-ORDER 0; slot 0 retains cached value from prior SET-ORDER call (or boot init). Documented in DEFCODE comment + test 836. |
| #7  | LABEL bucket-restore wid scope | Single per-CODE-block `asm_saved_wid` | Cheapest implementation; matches design intent (mid-CODE SET-CURRENT not supported). All LABELs in one CODE block share the wid captured at CODE entry. |
| #8  | MARKER snapshot scope | (a) FORTH-WORDLIST-only | Matches Story 12.3 AC #10 discipline — defer broad-wordlist semantics. Limitation documented in MARKER docstring (`src/system.asm:23-26`). |
| #9  | WORDS scope | (a) FORTH-WORDLIST-only | ANS does not standardise WORDS scope; closure-note added to docstring (`src/dictionary.asm:195-204`). |
| #11 | DEFCODE insertion point | After `do_search_order_overflow:`, before `srch_saved_ip:` | Keeps THROW raise sites adjacent to consumers; preserves `forth_wordlist:` emission discipline (DEFCODEs all precede the struct emission for `_hash_buckets[]` ordering). |
| (build_header byte sequence) | Single capture → reload pattern | Capture wid into `bh_wid` once in build_header; callers (`colon prologue`, `CODE prologue`) reload from `bh_wid` into their per-definition saves | Avoids redundant IY-relative loads at each call site. |

#### Per-AC verdict table

| AC | Gate | Evidence | Verdict |
|----|------|----------|---------|
| #1  | UserArea additive: `current_wordlist DW 0` appended last; existing offsets preserved | `src/structures.asm:32` field added at end; existing 831 baseline tests PASS (proves IY-relative offsets unchanged) | PASS |
| #2  | GET-CURRENT pushes `(IY+UserArea.current_wordlist)` | `src/wordlists.asm:255-264`; test 823 (T-GC1) PASS | PASS |
| #3  | SET-CURRENT stores wid into IY-rel field; underflow-guarded | `src/wordlists.asm:266-275`; tests 824 (T-SC1), 825/826 (T-SC2a/b), 827/828 (T-SC3a/b) PASS | PASS |
| #4  | DEFINITIONS copies slot 0 → current_wordlist; depth=0 reads unguarded | `src/wordlists.asm:281-291`; tests 829 (T-DEF1), 830 (T-DEF2), 836 (T-DEF-DEPTH0) PASS | PASS |
| #5  | build_header parameterised on `current_wordlist`; default-case bit-exact | `src/compiler.asm:217-228`; test 802 PASS (default case unchanged); tests 831-834 (CREATE/CONSTANT/VARIABLE/MARKER) PASS | PASS |
| #6  | COMP-ERROR rolls back saved wid (not FORTH-WORDLIST) | `src/compiler.asm:444-450` (rollback) + `:386-387` (prologue save) + `:97` (scratch); test 835 (T-COMP-ERROR) PASS | PASS |
| #7  | Assembler error recovery + `asm_unlink_labels` parameterised on `asm_saved_wid` | `src/assembler.asm:84-87` (scratch), `:430-433` (cleanup), `:847-849` (unlink), `:1255-1256` (CODE prologue save); `make test` (asm thread) clean | PASS |
| #8  | MARKER scope = FORTH-WORDLIST per pick (a); limitation documented | `src/system.asm:23-26` docstring updated; test 834 confirms MARKER header lands in custom wordlist (snapshot body is FORTH-WORDLIST-only by design) | PASS |
| #9  | WORDS scope = FORTH-WORDLIST per pick (a); closure-note added | `src/dictionary.asm:195-204` docstring updated | PASS |
| #10 | Cold-start init writes `forth_wordlist` to current_wordlist | `src/antforth.asm:109-113`, step 8e between SEARCH-ORDER zero-fill and FORTH-WORDLIST comment | PASS |
| #11 | Three new DEFCODEs precede `forth_wordlist:` label | `grep -n 'forth_wordlist:' src/wordlists.asm` returns 1 hit at line 327; all 8 DEFCODEs (WORDLIST, SEARCH-WORDLIST, FORTH-WORDLIST, GET-ORDER, SET-ORDER, GET-CURRENT, SET-CURRENT, DEFINITIONS) emit before the struct | PASS |
| #12 | Binary delta in +50..+120 envelope | **18,184 − 18,041 = +143 bytes**; +23 over envelope. Justification: rough spec budget did not account for DEFCODE header overhead (3 × ~14 bytes for hash_link + count_flags + 11-char names). Per-component breakdown matches actuals when DEFCODE headers are added. | NEEDS-JUSTIFICATION (justified above; story headroom comfortable) |
| #13 | Zero regression: 831 baseline tests all PASS | `make test-repl` = 845 PASS / 0 FAIL (831 + 14); `make test` clean | PASS |
| #14 | 14 REPL tests added in `tests/wordlist_tests.fth` Section 8; wired in Makefile 823..836 | All 14 new tests PASS | PASS |
| #15 | DPANS94 §16.6.1.{1643,2193,1180} read before coding | Citations present in `src/wordlists.asm:257,268,281`; impl matches stack effects per Task 14 cross-reference | PASS |
| #16 | Adversarial review yields ≥ 1-2 LOW/MEDIUM findings | 3 LOW findings recorded (table below) | PASS |
| #17 | ANS spec cross-reference performed | Task 14 entries; impl matches spec for all three words | PASS |
| #18 | Recommended picks taken; no permission asked for routine choices | All 6 picks taken without escalation | PASS |
| #19 | No build_header pre-existing defect; no sub-stories spawned | Bit-exact regression of default case proved by 831 baseline PASS | PASS |
| #20 | Sprint-status flipped through ready-for-dev → in-progress → review | `_bmad-output/implementation-artifacts/sprint-status.yaml:185` shows `review` | PASS |

#### Adversarial finding triage table

| Severity | Category | Description | Resolution |
|----------|----------|-------------|------------|
| LOW | Spec budget gap | Rough +85 byte estimate in AC #12 understated DEFCODE header overhead; actual delta is +143 bytes (+23 over envelope) | Documented in Task 11.2 with per-component reconciliation; story headroom comfortable; no refactor warranted. |
| LOW | Spec assumption mismatch | AC #4 + Test T-DEF-DEPTH0 assumed `SET-ORDER 0 + DEFINITIONS` would yield wid=0 | In reality SET-ORDER 0 only updates the depth field; slot 0 retains its pre-existing value. Test 836 reworded to assert `T836 FORTH-WORDLIST = .` → `-1` (matches actual ANS pick (a) behaviour: "read slot 0 unconditionally"). |
| LOW | Test infrastructure quirk | TIB length limit (128 bytes) silently truncates long REPL test lines mid-word | Tests 829, 832, 833, 834 split into two `printf` `%s\r\n` arguments (Makefile-side fix, no kernel change). |

#### Standards compliance + post-Story baselines

- DPANS94 §16.6.1.1643 GET-CURRENT: `( -- wid )` — read into `(IY+UserArea.current_wordlist)`. ✅
- DPANS94 §16.6.1.2193 SET-CURRENT: `( wid -- )` — write into `(IY+UserArea.current_wordlist)`. ✅
- DPANS94 §16.6.1.1180 DEFINITIONS: `( -- )` — copy slot 0 → `current_wordlist`. ✅
- NFR9 zero-regression gate: 831 baseline tests all PASS. ✅
- NFR17 / CCD-3 citation discipline: 3 hits in `src/wordlists.asm`. ✅
- AC #16 adversarial review: 3 LOW findings; no HIGH/MEDIUM blockers.

#### Sprint-status flips (AC #20)

- `12-4-compilation-wordlist-control: ready-for-dev → in-progress → review` ✅
- `epic-12: in-progress` (no flip — epic still has 12.5 + 12.6 to land)

### File List

**Modified:**
- `src/structures.asm` — appended `current_wordlist DW 0` to UserArea STRUCT
- `src/antforth.asm` — inserted "8e. CURRENT-WORDLIST init" in cold_start
- `src/wordlists.asm` — added `w_GET_CURRENT`, `w_SET_CURRENT`, `w_DEFINITIONS` DEFCODE blocks (Story 12.4 section before `forth_wordlist:` label); review L1: DEFINITIONS docstring rewritten to describe actual depth=0 behaviour
- `src/compiler.asm` — added `bh_wid` and `colon_saved_wid` scratch DWs; parameterised build_header bucket-address compute on `current_wordlist`; added wid save in colon prologue; parameterised `w_COMP_ERROR_cf` rollback on `colon_saved_wid`; review L3: bh_wid lifecycle invariant called out in build_header comment block
- `src/assembler.asm` — added `asm_saved_wid` scratch DW; parameterised `asm_cleanup` (CODE-word bucket restore) and `asm_unlink_labels` (LABEL bucket-restore) on `asm_saved_wid`; added wid save in CODE prologue
- `src/dictionary.asm` — WORDS docstring updated to closure-note (Story 12.4 landed; AC #9 pick (a) — WORDS stays FORTH-WORDLIST-scoped)
- `src/system.asm` — MARKER docstring extended with Story 12.4 limitation note (snapshot scope = FORTH-WORDLIST per AC #8 pick (a)); review H1 fix: MARKER snapshot fixup gated on `bh_wid == forth_wordlist` to prevent FORTH-WORDLIST corruption when MARKER is created with foreign current_wordlist
- `tests/wordlist_tests.fth` — appended Section 8 (Story 12.4) with 14 REPL tests (T-GC1 through T-DEF-DEPTH0); review M1: added test 837 (T-MARKER-XWID-EXEC) — deterministic regression probe for H1
- `Makefile` — added 15 REPL test entries 823..837 wired into `test-repl` target
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — flipped Story 12.4 row through in-progress → review → done
- `_bmad-output/implementation-artifacts/12-4-compilation-wordlist-control.md` — Status flipped to `done`; all 14 tasks marked complete; Completion Notes + Senior Developer Review populated

**No new files. No deletions.**

### Change Log

- 2026-04-29 — Story 12.4 implemented in single dev pass:
  - 3 new ANS words (GET-CURRENT, SET-CURRENT, DEFINITIONS) registered in FORTH-WORDLIST.
  - `build_header` and 3 error-recovery sites (`w_COMP_ERROR_cf`, `asm_cleanup`, `asm_unlink_labels`) parameterised on per-definition saved wid.
  - UserArea extended with `current_wordlist` USER var; cold-start init step 8e initialises to FORTH-WORDLIST.
  - 14 REPL tests added (823..836) covering boot state, round-trip, partition discipline, search-order independence, DEFINITIONS slot-0 read, all 4 CREATE-class words, COMP-ERROR rollback targeting, and depth-0 edge case.
  - Binary delta: +143 bytes (over +120 envelope by 23; justified — DEFCODE header overhead understated in spec budget).
  - Regression: 845 PASS / 0 FAIL (831 baseline + 14 new); assembly thread clean.
  - 3 LOW adversarial findings; no HIGH/MEDIUM blockers.

- 2026-04-29 — Code-review pass (1 HIGH, 1 MEDIUM, 3 LOW found; all HIGH/MEDIUM fixed):
  - **H1 (HIGH) FIXED** — `src/system.asm:53-78` MARKER snapshot fixup. Pre-12.4 the
    fixup unconditionally rewrote `body_hash_start[bh_bucket_index]` with
    `bh_old_bucket_head`, which was correct only because build_header always operated
    on FORTH-WORDLIST. Post-12.4 with `current_wordlist != forth_wordlist`,
    `bh_old_bucket_head` is the FOREIGN wid's old bucket head — applying the fixup
    corrupted FORTH-WORDLIST's snapshot, and DOMARKER would propagate the corruption
    on execute. Fix: gate the fixup on `bh_wid == forth_wordlist`; skip otherwise (the
    snapshot already reflects FORTH-WORDLIST's true bucket array at MARKER-create time).
  - **M1 (MEDIUM) FIXED** — Test gap that allowed H1 to slip through. Added Test 837
    (T-MARKER-XWID-EXEC) — deterministic probe: `hash("MX") = 5`; pre-MX-create
    `FORTH-WORDLIST + 12 @` captured; MARKER MX created in foreign WL; MX executed via
    a depth-2 search-order; post-exec `FORTH-WORDLIST + 12 @ =` must equal pre-value.
    Verified: regresses cleanly when H1 fix is reverted (returns `0`).
  - **L1 (LOW) FIXED** — `src/wordlists.asm:281-289` DEFINITIONS docstring rewritten
    to describe the actual depth=0 behaviour (slot 0 retains its cached value; SET-ORDER
    0 doesn't zero it). Prior comment said "depth=0 yields wid=0" which contradicted
    Tasks 4.2 / Debug Log empirical findings.
  - **L2 (LOW) ACCEPTED** — +143 byte binary delta vs +120 envelope retained as
    NEEDS-JUSTIFICATION. DEFCODE-header-overhead budgeting note carried forward.
  - **L3 (LOW) DOCUMENTED** — `src/compiler.asm:217-228` build_header comment block
    extended with the explicit lifecycle invariant for `bh_wid` (callers MUST test
    CF before reading bh_wid; .bh_no_name does not write bh_wid).
  - Post-fix metrics: **846 PASS / 0 FAIL** (831 baseline + 14 Story-12.4 + 1 review-add);
    assembly thread clean; binary 18,198 bytes (= +157 vs Story-12.3 baseline; the H1
    fix added +14 bytes; envelope discussion moved to L2).
  - Status flipped to `done`.

### Senior Developer Review (AI)

**Reviewer:** Ant
**Date:** 2026-04-29
**Outcome:** Approve (after H1/M1/L1/L3 in-pass fixes landed)

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| H1 | HIGH | FIXED | MARKER fixup corrupts FORTH-WORDLIST snapshot when current_wordlist != FORTH-WORDLIST. (`src/system.asm` MARKER body) |
| M1 | MEDIUM | FIXED | No execute-side test for foreign-wid MARKER; Test 837 added (deterministic regression probe). |
| L1 | LOW | FIXED | DEFINITIONS docstring contradicted depth=0 reality. |
| L2 | LOW | ACCEPTED | +143-byte binary delta over +120 envelope; justified by DEFCODE-header-overhead. |
| L3 | LOW | DOCUMENTED | bh_wid lifecycle invariant called out in build_header comment block. |

**Final gates:**
- AC #1..#11, #13..#20: PASS (verdict table preserved above).
- AC #12: NEEDS-JUSTIFICATION (L2). Accepted with the budget reconciliation note.
- AC #16 (adversarial review): PASS — 1 HIGH + 1 MEDIUM + 3 LOW found; all HIGH/MEDIUM fixed in-pass.
- Regression net: 846 PASS / 0 FAIL (REPL); 0 errors (assembly thread).

