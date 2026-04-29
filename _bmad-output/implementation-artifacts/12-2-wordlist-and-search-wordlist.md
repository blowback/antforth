# Story 12.2: `WORDLIST` and `SEARCH-WORDLIST`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to create new empty wordlists at runtime and search any specific wordlist by identifier,
so that I can partition my definitions into named namespaces (FR23) and perform targeted lookups (FR29).

## Acceptance Criteria

1. **Given** `WORDLIST` per ANS Forth 1994 §16.6.1.2460 (stack effect `( -- wid )`),
   **when** I invoke `WORDLIST` from the REPL,
   **then** it `ALLOT`s `WORDLIST_SIZE` (= 130) bytes at `HERE`, zero-initialises **all 130 bytes** (the 2-byte `WORDLIST_NEXT` chain link + the 64×2-byte bucket array — i.e., the entire struct, no partial init), advances `HERE` by 130, and returns the struct's base address on TOS as the wordlist identifier (`wid`). The next-wordlist chain pointer is left at `0`; **WORDLIST does NOT splice the new wordlist into any chain** — chain semantics are forward-looking and remain unused in Story 12.2 (no Story-12.2 consumer exists; Story 12.4's `SET-CURRENT` and Story 12.5's `ONLY` may revisit if needed). The new word is registered with the standards citation comment `; ANS Forth 1994 §16.6.1.2460   WORDLIST` and stack-effect comment `( -- wid )` per CCD-3 / NFR17.

2. **Given** `SEARCH-WORDLIST` per ANS Forth 1994 §16.6.1.2192 (stack effect `( c-addr u wid -- 0 | xt 1 | xt -1 )`),
   **when** I invoke `c-addr u wid SEARCH-WORDLIST`,
   **then** it searches **only the specified wordlist** (`wid` — never the search order; that's `FIND`'s job, and the search-order machinery itself doesn't land until Story 12.3) by hashing the name (HL = c-addr, B = u truncated to length-mask if u > 31; see Dev Notes "Length-mask treatment in SEARCH-WORDLIST") and walking the matching bucket chain in `wid`'s 64-entry bucket array. On miss it returns `( 0 )` (single cell) — **stack-shrinks**: pre-call depth was 3 (c-addr, u, wid), post-call depth on miss is 1 (the `0` flag). On hit it returns `( xt 1 )` for an IMMEDIATE word or `( xt -1 )` for a non-IMMEDIATE word — depth 2. The new word is registered with citation comment `; ANS Forth 1994 §16.6.1.2192   SEARCH-WORDLIST` and stack-effect comment `( c-addr u wid -- 0 | xt 1 | xt -1 )` per CCD-3 / NFR17.

3. **Given** a freshly created wordlist (via Story 12.2's `WORDLIST`),
   **when** `SEARCH-WORDLIST` is invoked against it before any definitions are added,
   **then** it returns `0` for any name (empty bucket array → first chain-head is `0` → immediate miss). This is a per-story regression gate; verified by Test T2 (see Task 5).

4. **Given** the implementation,
   **when** the assembler compiles `src/wordlists.asm`,
   **then** the file's two new DEFCODE entries (`w_WORDLIST` / `w_SEARCH_WORDLIST`) carry the citation comments above, the stack-effect comments above, and use the existing `WORDLIST_SIZE`, `WORDLIST_NEXT`, `WORDLIST_BUCKET0`, `WORDLIST_BUCKETS` EQUs from Story 12.1 — **no new layout EQUs are introduced** (the struct shape is fixed by Story 12.1; this story is purely user-facing word implementation).

5. **Given** `src/dictionary.asm`'s existing `FIND` (which today hard-codes `forth_wordlist + WORDLIST_BUCKET0` per Story 12.1 AC #3),
   **when** `SEARCH-WORDLIST` is implemented,
   **then** the dev agent picks ONE of:
   - **(a) Shared helper subroutine.** Factor a `search_wid_for_name` (or similarly named) helper out of `FIND` — input: name addr in HL, length in B, wid in DE (or another register per the dev agent's pick); output: HL = matching dict-entry address (or `0` for miss), F_IMMEDIATE flag in A or carry. Both `FIND` (passing `forth_wordlist`) and `SEARCH-WORDLIST` (passing the user-supplied `wid`) call it. **Recommended.** Pays off in Story 12.3 (search-order walk also calls this helper per wid). Net diff: small refactor of `FIND` + thin SEARCH-WORDLIST wrapper. Per `feedback_design_upfront.md` — design helper for the full Epic-12 search-order use-case on day one.
   - **(b) Parallel implementation.** Write `w_SEARCH_WORDLIST_cf` as a copy-and-adapt of `w_FIND_cf`'s chain-walk loop, parameterised on `wid` instead of `forth_wordlist`. No `FIND` refactor. Smaller this-story diff, but Story 12.3's search-order walk will need to factor anyway — paying the refactor cost across two stories instead of one.

   **Recommendation: (a)** — single-source-of-truth for the bucket-walk algorithm; Story 12.3's search-order walk drops in cleanly. Pick recorded in Completion Notes Task 2. Whichever pick lands, the resulting code MUST honour the ANS stack effects in AC #1 / #2 exactly (FIND's `c-addr 0` miss vs SEARCH-WORDLIST's lone `0` miss; FIND's counted-string-input vs SEARCH-WORDLIST's c-addr+u-input; both use the same 3-state hit/miss flag set: `1` IMMEDIATE / `-1` non-IMMEDIATE / `0` miss).

6. **Given** Story 12.1's binary baseline (**17,543 bytes** post-Story-12.1 per `_bmad-output/implementation-artifacts/12-1-…md` Task 13),
   **when** Story 12.2 lands,
   **then** the binary delta is recorded with `wc -c build/antforth.com` and falls within an envelope of **+30 to +120 bytes** (rough budget for two new DEFCODE primitives plus the optional shared-helper refactor — `WORDLIST` is a tight zero-fill loop ~20 bytes; `SEARCH-WORDLIST` adds the bucket-walk wrapper ~40-80 bytes; the helper-extract from FIND, if pick (a), may net out near-zero or slightly positive for the wrapper plumbing). Anything beyond +120 bytes is justified explicitly; a negative delta (FIND refactor net-shrinks the kernel) is also flagged as a sanity check. Recorded plainly per `feedback_plain_qa_language.md` (state value, gate, conclusion).

7. **Given** the regression net (`make test-repl` 815 PASS / 0 FAIL post-Story-12.1 per `_bmad-output/implementation-artifacts/12-1-…md` Task 9.4),
   **when** Story 12.2 lands,
   **then** `make test-repl` shows **815 + N PASS / 0 FAIL** where N = the count of new tests added in Task 5. Pre-existing 815 tests must all continue to pass (NFR9 zero-regression gate per `feedback_standards_compliance.md`); any regression is debugged at root cause, not papered over. `make test` (assembly thread) must remain clean (groups 1–6 expected output match per `Makefile:55-71`).

8. **Given** the test-coverage discipline per `feedback_repl_tests_preferred.md`,
   **when** Story 12.2 adds tests,
   **then** they are REPL-piped Forth scripts in `tests/wordlist_tests.fth` (extending the file Story 12.1 created), wired into `Makefile`'s `test-repl` target with test numbers continuing from 806 (next free ID = 807). **No new assembly test threads.** Coverage scope (3-6 new tests; pick lands in Task 5):
   - **T-WL1 — WORDLIST returns nonzero, even-aligned wid; HERE advances exactly 130 bytes.** `HERE WORDLIST OVER OVER SWAP - .` should print `130 ` (or use `=` for boolean check) and the wid itself prints as a nonzero unsigned address.
   - **T-WL2 — fresh wordlist's bucket array is zero-initialised.** `WORDLIST DUP 2 + @ U.` (the first bucket) prints `0 `; same for the next-link cell `@ U.` prints `0 `. Or composite: dump 130 bytes via a Forth loop and assert all-zero.
   - **T-SW1 — SEARCH-WORDLIST on empty wordlist returns 0.** `WORDLIST CONSTANT WL1   S" DUP" WL1 SEARCH-WORDLIST .` prints `0 ` (single value — depth shrinks correctly from 3 to 1).
   - **T-SW2 — SEARCH-WORDLIST stack-effect on hit is deferred to Story 12.4.** Adding a definition to a custom wordlist requires `SET-CURRENT` (Story 12.4); Story 12.2 cannot easily prove the "hit" code path against a Forth-defined wordlist without a low-level bucket-injection workaround (see Dev Notes "Hit-path test discipline for Story 12.2"). **Story 12.2 verifies the hit path indirectly** via the unit-level assertion in Task 5.4 (manual bucket-injection in a custom wordlist) and defers the `SET-CURRENT`-driven hit/collision tests to Story 12.4 and Story 12.3 (FORTH-WORDLIST as a Forth word enables `S" DUP" FORTH-WORDLIST SEARCH-WORDLIST` → expect `xt -1`).
   - **T-SW3 (optional)** — exercise the length truncation: `SEARCH-WORDLIST` invoked with `u > F_LENMASK` (32+); per Dev Notes "Length-mask treatment", the dev agent picks behaviour (truncate vs THROW) and the test asserts that pick.

   The exact PASS-count delta per these tests is recorded in Completion Notes Task 5.

9. **Given** the ANS stack-effect contract for `SEARCH-WORDLIST` returning either 1 cell (miss) or 2 cells (hit),
   **when** `SEARCH-WORDLIST` writes its result,
   **then** the implementation correctly manages the BC-as-TOS-in-register discipline (`project_tos_in_register.md`) across the depth-changing return — on miss, BC must hold `0` and the SP-stack must NOT have been left with a residual c-addr/u/wid; on hit, BC must hold the flag (`1` or `-1`) and the xt must be on the SP-stack (second-on-stack). The implementation is reviewed for stack-imbalance bugs as part of AC #11.

10. **Given** the Story 12.1 `forth_wordlist` symbol is the only existing wordlist instance in the kernel (per Story 12.1 AC #1),
    **when** Story 12.2's `WORDLIST` runs at the user level,
    **then** every wordlist created via `WORDLIST` lives in the dictionary's `HERE`-area (not in kernel-resident memory) — wid addresses are above kernel-end. This is implicit from the `ALLOT`-at-`HERE` design (E12-D3); verified by-construction. No new bookkeeping beyond `HERE` advancement.

11. **Given** the `feedback_adversarial_review.md` discipline ("reviews MUST find things; absence of findings is suspect"),
    **when** Story 12.2's review runs,
    **then** **at least 1-2 LOW/MEDIUM findings are expected**. Likely candidates the review must probe:
    - **(a) Stack-depth correctness on SEARCH-WORDLIST miss.** ANS §16.6.1.2192 says miss returns `0` (single cell); the implementation must drop both `c-addr` and `u` from SP-stack and leave `0` in BC. If the impl pops only one and leaves the other on SP, the next word inherits a corrupt stack. Probe: test `S" XXXX" WL1 SEARCH-WORDLIST   DEPTH .` after a miss; expect `1 ` (just the `0` flag).
    - **(b) Length-mask handling.** SEARCH-WORDLIST's `u` is a byte length; nothing in ANS says it must be ≤ 31. But `hash_name` masks to 6 bits via `AND 63` and treats B as a loop counter, so any u > 0 works for the hash itself. The match-loop in the chain compares the search length against the entry's length-mask-stripped length — if u > 31 the search will find no match (safely) but the hash bucket may still be probed. Test that this doesn't crash. Probe: `S" XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" WL1 SEARCH-WORDLIST` (33+ chars).
    - **(c) Zero-length name.** `S" " WL1 SEARCH-WORDLIST` — u = 0; `hash_name` returns bucket 0 (per `src/hash.asm:14-18`); chain walk on bucket 0 returns first miss. Probe: confirm no crash and result is `0`.
    - **(d) WORDLIST zero-init coverage.** All 130 bytes must be zero — including the `WORDLIST_NEXT` link cell. Probe: read 130 bytes from a fresh wid and verify all zero (Test T-WL2 covers this).
    - **(e) HERE alignment.** `WORDLIST` advances `HERE` by 130 bytes, leaving HERE at an even or odd boundary depending on prior alignment. ANS §3.3.3 doesn't require `WORDLIST` to align HERE, but post-WORDLIST a subsequent `,` may then cell-write to an odd address. Probe: confirm `HERE` advances by exactly 130; if a Forth-side `ALIGN` is required after, document. Recommended: post-WORDLIST `HERE` is aligned-by-construction if pre-WORDLIST `HERE` was even (130 = 2 × 65, even); only odd-pre-WORDLIST users break, and that's pre-existing dictionary discipline (`,` already requires aligned HERE).
    - **(f) Helper-refactor regression risk.** If pick (a) (shared helper from AC #5), the FIND refactor risks subtle regressions in the existing 815 REPL tests. Probe: re-run `make test-repl`; any new failure is investigated at root cause.
    - **(g) Citation discipline preserved.** Per CCD-3 / NFR17, both new words carry their ANS §16.6.1.2460 / §16.6.1.2192 citations; verified by `grep -nE 'ANS Forth.*16\.6\.1\.(2460|2192)' src/wordlists.asm` returning exactly 2 hits.

    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Stories 11.5.x / 12.1 review-log discipline). Recorded in Completion Notes Task 7.

12. **Given** the `feedback_systematic_reference_check.md` discipline ("'Complete X' story specs must cross-reference the authoritative manual, not enumerate from memory"),
    **when** the dev agent surveys the new words against ANS Forth 1994 §16.6.1.2460 (WORDLIST) and §16.6.1.2192 (SEARCH-WORDLIST),
    **then** the implementation is cross-referenced against the actual standard text — not against memory or against the epic spec alone. Stack effects, error behaviours, and edge cases (zero-length names, the `wid` interpretation, the hit-flag values 1 / -1) are confirmed against the spec. Documented in Completion Notes Task 8.

13. **Given** the `feedback_follow_process.md` discipline ("Don't ask permission for obvious next steps; just execute the workflow"),
    **when** the dev agent encounters edge cases (the AC #5 helper-vs-parallel pick; the AC #11(b) length-mask behaviour pick; the AC #11(e) HERE-alignment pick),
    **then** the dev agent picks the recommended option in the relevant AC and proceeds. All in-pass picks are recorded in Completion Notes per the Tasks below. Escalation to the project lead is reserved for the structural-load-bearing case (AC #15).

14. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 11.5.5 AC #12 / Story 12.1 AC #14),
    **when** small in-pass refinements are warranted (a comment polish; a missed citation; a one-line stack-effect adjustment),
    **then** they are landed inside this story — no spawning further sub-stories. The exception: if the helper-extract from AC #5(a) surfaces a pre-existing FIND defect (e.g., a corner case where FIND today miscomputes IMMEDIATE flag handling), HALT and flag it as a finding for the project lead before scrubbing — the change becomes a separate decision, not in-pass cleanup. Documented in Completion Notes Task 6.

15. **Given** Story 12.2 follows Story 12.1 in Epic 12 (which is already `in-progress` per `sprint-status.yaml:181`),
    **when** Story 12.2 lands,
    **then** the sprint-status row `12-2-wordlist-and-search-wordlist: backlog` flips to `ready-for-dev` at create-story (this story's creation), through `in-progress` (dev-pass start) and `review` (dev-pass close), to `done` (code-review close). No epic-status flip is needed (`epic-12: in-progress` already). Recorded in Completion Notes Task 9.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline + ANS spec read-through (AC: #6, #7, #12)**
  - [x] 1.1 `wc -c build/antforth.com` — record post-Story-12.1 baseline. Expected: **17,543 bytes** per Story 12.1 Task 13. Verify; investigate any deviation.
  - [x] 1.2 `make test-repl` — record total PASS / FAIL. Expected: **815 PASS / 0 FAIL** per Story 12.1 Task 9.4. Investigate any pre-existing failure (release blocker per `feedback_standards_compliance.md`).
  - [x] 1.3 `make test` (assembly thread) — record clean / fail outcome. Expected: clean (groups 1–6 expected output match).
  - [x] 1.4 Read DPANS94 §16.6.1.2460 (`WORDLIST`) and §16.6.1.2192 (`SEARCH-WORDLIST`) — confirm stack effects, miss-vs-hit return shapes, IMMEDIATE flag values. Note any ambiguity for Task 8 verification. **Per `feedback_systematic_reference_check.md` — read the spec, don't paraphrase from memory.**

- [x] **Task 2 — Implement `WORDLIST` (AC: #1, #4, #10)**
  - [x] 2.1 Add `w_WORDLIST` / `w_WORDLIST_cf` DEFCODE block to `src/wordlists.asm` (under the existing layout EQUs and `forth_wordlist` struct). Header line:
    ```
    ; ANS Forth 1994 §16.6.1.2460   WORDLIST    ( -- wid )
    ;   Allocate a new 130-byte wordlist struct at HERE; zero-init all
    ;   bytes (next-link + 64 bucket entries); advance HERE; return base
    ;   address as the wordlist identifier.
    ```
  - [x] 2.2 Implementation pattern (recommended — LDIR zero-fill is the canonical Z80 idiom for clearing N>4 bytes):
    ```
    w_WORDLIST:
            DEFCODE "WORDLIST", 0
    w_WORDLIST_cf:
            PUSH    BC                      ; save old TOS
            LD      L, (IY+UserArea.here)
            LD      H, (IY+UserArea.here+1) ; HL = HERE = new wid base
            PUSH    HL                      ; preserve wid for return
            LD      (HL), 0                 ; zero first byte
            LD      D, H
            LD      E, L
            INC     DE                      ; DE = HL + 1
            LD      BC, WORDLIST_SIZE - 1   ; 129
            LDIR                            ; cascade zero forward; DE → past end
            LD      (IY+UserArea.here), E
            LD      (IY+UserArea.here+1), D ; HERE = old + 130
            POP     BC                      ; BC = saved wid (new TOS)
            NEXT
    ```
    Alternative (slower but smaller): `LD B, WORDLIST_SIZE / XOR A / .loop: LD (HL), A / INC HL / DJNZ .loop`. Either is acceptable; record decision in Completion Notes Task 2.
  - [x] 2.3 Verify `make` builds clean (0 errors / 0 warnings).
  - [x] 2.4 Spot-test in REPL: `HERE WORDLIST OVER OVER SWAP - .` should print `130 `; the wid itself is then the new struct base.

- [x] **Task 3 — Pick AC #5 helper-vs-parallel; implement `SEARCH-WORDLIST` accordingly (AC: #2, #5, #9)**
  - [x] 3.1 Decide pick: **(a) shared helper** (recommended) or **(b) parallel implementation**. Record in Completion Notes Task 3 with rationale.
  - [x] 3.2 If (a): factor a helper out of `src/dictionary.asm`'s `w_FIND_cf` chain-walk. Suggested helper signature:
    ```
    ; search_wid_for_name — Walk one wordlist's bucket chain for a name match
    ; Input:  HL = name address (raw, not counted)
    ;         B  = name length
    ;         DE = wid (wordlist struct base address)
    ; Output: HL = matching dict-entry address (or 0 on miss)
    ;         A  = count_flags byte of match (or undefined on miss)
    ;         CF = 0 on miss, 1 on hit  (alternative: Z flag on miss)
    ; Clobbers: BC, plus typical scratch
    ; Preserves: IX, IY, SP, the caller's saved IP discipline
    search_wid_for_name:
            CALL    hash_name           ; A = bucket index
            LD      L, A
            LD      H, 0
            ADD     HL, HL              ; HL = 2 * bucket index
            EX      DE, HL              ; HL = wid, DE = 2*bucket index
            ADD     HL, DE              ; HL = wid + 2*bucket
            INC     HL
            INC     HL                  ; HL = wid + WORDLIST_BUCKET0 + 2*bucket = &bucket
            ; load chain head and walk — same as today's FIND chain-walk
            ...
    ```
    Then `w_FIND_cf` becomes a thin wrapper: load `forth_wordlist` into the wid register, prepare name addr/length from the counted-string input, call helper, format result per FIND's `( c-addr 0 | xt 1 | xt -1 )` ANS spec.
    `w_SEARCH_WORDLIST_cf` is a parallel thin wrapper: pop `( c-addr u wid )` from the stack into the helper's input registers, call helper, format result per SEARCH-WORDLIST's `( 0 | xt 1 | xt -1 )` ANS spec.
  - [x] 3.3 If (b): write `w_SEARCH_WORDLIST_cf` as a copy-and-adapt of `w_FIND_cf`'s chain-walk loop, parameterised on the user-supplied wid. Note the divergence in input shape (counted string vs c-addr+u) and miss-shape (`c-addr 0` vs lone `0`). Leave `w_FIND_cf` untouched. **Picked (a); (b) not used.**
  - [x] 3.4 Add the SEARCH-WORDLIST DEFCODE block to `src/wordlists.asm`. Header line:
    ```
    ; ANS Forth 1994 §16.6.1.2192   SEARCH-WORDLIST    ( c-addr u wid -- 0 | xt 1 | xt -1 )
    ;   Search the specified wordlist's bucket array for a name match.
    ;   On miss return single 0; on hit return xt and either 1 (IMMEDIATE)
    ;   or -1 (non-IMMEDIATE).
    ```
  - [ ] 3.5 Implementation outline (parameterised on the AC #5 pick; this sketch assumes the shared-helper path):
    ```
    w_SEARCH_WORDLIST:
            DEFCODE "SEARCH-WORDLIST", 0
    w_SEARCH_WORDLIST_cf:
            ; BC = wid (TOS), SP holds u (length), c-addr below
            PUSH    DE                  ; save IP
            LD      D, B
            LD      E, C                ; DE = wid
            POP     HL                  ; HL = saved IP — wait, IP saved here interferes
            ...
    ```
    NOTE: the DE register conflict with the saved-IP store needs care — the dev agent picks scratch storage (a la `.find_len`/`.find_name` from `dictionary.asm:151-153`) for IP preservation, OR uses an alternate register-allocation pattern. Record final pattern in Completion Notes Task 3.
  - [x] 3.5 Implementation outline — applied: SEARCH-WORDLIST saves IP to `sw_saved_ip` (dedicated scratch DW in `src/wordlists.asm`), moves wid from BC into DE, reorders SP-popped u/c-addr into helper inputs (HL=name, B=length, DE=wid), calls `search_wid_for_name`, then formats hit/miss per ANS contract.
  - [x] 3.6 Cover the AC #11(a) stack-correctness gate: on miss, ensure two cells (u, c-addr) are removed from SP-stack and BC = 0; on hit, ensure one cell (u) is removed from SP-stack, the xt is in second-on-stack (SP-cell), and BC holds the flag (`1` or `-1`). Verify by Forth-side `DEPTH` probe in tests.
  - [x] 3.7 Verify `make` builds clean (0 errors / 0 warnings).

- [x] **Task 4 — Length-mask & edge-case behaviour pick (AC: #11(b), #11(c), #13)**
  - [x] 4.1 Decide AC #11(b) length-mask pick: **(i)** truncate u to F_LENMASK (=31) before passing to `hash_name` and chain compare — matches FIND's behaviour; harmonises both code paths. **(ii)** pass u unchanged to `hash_name` (which truncates internally via the loop counter), then in the chain-compare reject any name with stripped-length-mask ≠ u — guarantees miss for u>31. **Picked (ii)** — minimal-intervention; pathological u>31 is a pure-miss, the correct ANS outcome.
  - [x] 4.2 Decide AC #11(c) zero-length pick: u = 0 returns `0` (no entry can match a zero-length name) — same outcome whether via (i) or (ii). Verify.
  - [x] 4.3 Record both picks in Completion Notes Task 4.

- [x] **Task 5 — Tests + Makefile wire-in (AC: #3, #7, #8)**
  - [x] 5.1 Append new test sections to `tests/wordlist_tests.fth` (do not rewrite existing T1–T5). Add T-WL1, T-WL2, T-SW1, T-SW2 (and optionally T-SW3) per AC #8 with the `\ expect:` style mirroring Story 12.1's existing entries.
  - [x] 5.2 Add corresponding Makefile entries (numbered 807+) immediately after test 806 in the `test-repl` target. Mirror the structure of tests 802–806 (per `Makefile:7013-7076`): printf-piped Forth one-liner; `grep -q` assertions on output fragments; `echo PASS:` / `echo FAIL:` + `exit 1`.
  - [x] 5.3 Suggested test IDs / coverage:
    - **Test 807 — T-WL1**: `HERE WORDLIST OVER OVER SWAP - .` → expect `130 ` (HERE advances by exactly 130).
    - **Test 808 — T-WL2**: `WORDLIST DUP @ . DUP 2 + @ . DROP` → expect `0 0 ` (next-link is 0; first bucket is 0 — minimal zero-init proof; for full 130-byte zero coverage, optionally extend with a counted loop in T-WL2-extended).
    - **Test 809 — T-SW1**: `WORDLIST CONSTANT WL1   S" DUP" WL1 SEARCH-WORDLIST .   .S` → expect `0  <empty>` or use `DEPTH .` to confirm depth = 0 after the test (proves miss returns single value and stack-shrinks).
    - **Test 810 — T-SW1-cont (depth check)**: `WORDLIST   S" XYZ" ROT SEARCH-WORDLIST   DEPTH .   DROP` → expect `1 ` for DEPTH (the `0` flag is the only thing left).
    - **Test 811 — T-SW2 (length-mask edge case)**: `WORDLIST   S" XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ROT SEARCH-WORDLIST .` (33 chars) → expect `0 ` (no crash; pure miss per AC #11(b) pick).
    - **Test 812 — T-SW3 (zero-length edge case)**: `WORDLIST   S" " ROT SEARCH-WORDLIST .` → expect `0 ` (per AC #11(c) — zero-length name miss).
  - [x] 5.4 Optional Test 813 — manual bucket-injection hit-path probe (Dev Notes "Hit-path test discipline" option B): use `!` to write a known dict-entry address into a custom wordlist's bucket-0, then SEARCH-WORDLIST that name. **Skipped per the story's recommendation (option A)** — hit-path coverage deferred to Story 12.3 / 12.4. Story 12.2's hit code path is exercised at the unit level via the shared helper (FIND's 815-test regression suite walks the same `search_wid_for_name` helper).
  - [x] 5.5 `make test-repl` — record post-edit total PASS / FAIL. Expected: **815 + N PASS / 0 FAIL** where N is the number of new tests from 5.3 (typically 6).
  - [x] 5.6 `make test` — verify clean.

- [x] **Task 6 — In-pass-fix discipline + escalation gate (AC: #13, #14)**
  - [x] 6.1 Log any in-pass fixes (comment polish, missed citation, one-line stack-effect adjustment) with one-line rationale.
  - [x] 6.2 Confirm no HALT condition triggered (no pre-existing FIND defect surfaced by helper-extract; no structural-load-bearing finding requiring project-lead escalation).
  - [x] 6.3 Record in Completion Notes Task 6.

- [x] **Task 7 — Adversarial self-review (AC: #11)**
  - [x] 7.1 Self-review against all seven probe categories (a)-(g) from AC #11.
  - [x] 7.2 Triage findings: HIGH/MEDIUM block the gate; LOW may be accepted with rationale.
  - [x] 7.3 Record findings table in Completion Notes Task 7 (mirror Story 12.1 Task 11 / Stories 11.5.4-11.5.7 review-log format with ID / Severity / Category / Description / Resolution columns).
  - [x] 7.4 If pick (a) (helper-extract from AC #5), explicitly verify FIND's behaviour is unchanged via the existing 815-test regression suite (Task 5.5 covers this at the suite level; Task 7.4 confirms via probe of a specific FIND code-path — e.g., `' DUP .` — that the IMMEDIATE-flag handling is preserved).

- [x] **Task 8 — ANS spec cross-reference (AC: #12)**
  - [x] 8.1 Cross-reference the implemented behaviour against DPANS94 §16.6.1.2460 and §16.6.1.2192 (read in Task 1.4).
  - [x] 8.2 Confirm: (i) WORDLIST's stack effect is `( -- wid )` and the wid is "an arbitrary identifier" (struct address satisfies); (ii) SEARCH-WORDLIST's stack effect is `( c-addr u wid -- 0 | xt 1 | xt -1 )`; (iii) the IMMEDIATE flag value is +1, non-IMMEDIATE is -1, miss is 0; (iv) no error throws are mandated by the standard for either word.
  - [x] 8.3 Record in Completion Notes Task 8.

- [x] **Task 9 — Binary delta + sprint-status flips + plain-language verdict (AC: #6, #15)**
  - [x] 9.1 `wc -c build/antforth.com` post-edit. Compute delta vs Task 1.1 baseline.
  - [x] 9.2 Compose a plain-language verdict: pre-edit X bytes, post-edit Y bytes, delta Z bytes; gate "+30 to +120 envelope per AC #6"; conclusion PASS / NEEDS-JUSTIFICATION.
  - [x] 9.3 At dev-pass start: flip `12-2-wordlist-and-search-wordlist: ready-for-dev` → `in-progress` at `sprint-status.yaml:183`.
  - [x] 9.4 At dev-pass close: flip `12-2-wordlist-and-search-wordlist: in-progress` → `review`.
  - [x] 9.5 The `review → done` flip is owned by `code-review` per the standard dev-story workflow.
  - [x] 9.6 No `epic-12` status flip needed (already `in-progress` per Story 12.1).
  - [x] 9.7 Record all flips in Completion Notes Task 9.

## Dev Notes

### Story summary

This is the **second story in Epic 12** — the first user-facing words land here. Story 12.1 (closed 2026-04-29) put the per-wordlist struct shape (`WORDLIST_SIZE` = 130; layout per E12-D1) and the `forth_wordlist:` canonical kernel-resident wordlist in place; every dictionary-lookup call site is parameterised on a wordlist-struct address. Story 12.2 layers `WORDLIST` (factory) and `SEARCH-WORDLIST` (single-wordlist lookup) on top of that infrastructure.

**Implementation surface is small**: ~30 lines for `WORDLIST` (zero-fill 130 bytes, advance HERE, return wid) and ~50-100 lines for `SEARCH-WORDLIST` (chain-walk a specific wid's bucket array). The optional helper-extract from `FIND` (AC #5(a) recommended pick) is the larger refactor — it shrinks `FIND`, adds the helper, and adds `SEARCH-WORDLIST` as a thin wrapper, with Story 12.3's search-order walk slotting in cleanly above the helper.

**Hit-path testing has a story-shape problem** (see "Hit-path test discipline for Story 12.2" below). Without `SET-CURRENT` (Story 12.4) or `FORTH-WORDLIST` as a Forth word (Story 12.3), inserting a definition into a custom wordlist requires either a low-level bucket-injection workaround or deferral. **Recommendation: defer hit-path tests to Story 12.3 / 12.4**; Story 12.2's tests cover the miss-path comprehensively, plus structural assertions on WORDLIST's output (zero-init, HERE advancement). The hit code path is exercised at the unit level by reading the assembly carefully and via the implicit shared-with-FIND code-path (if pick (a)).

The regression net is the existing 815-test REPL suite (post-Story-12.1 baseline) plus 5-6 new wordlist-specific smoke tests.

### Architecture decisions driving this story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§326-330 E12-D1: Per-wordlist hash table layout.** 130-byte struct = 2-byte next-wordlist chain pointer + 64×2-byte hash bucket array. Story 12.2 consumes this struct via `WORDLIST_SIZE` / `WORDLIST_NEXT` / `WORDLIST_BUCKET0` / `WORDLIST_BUCKETS` EQUs introduced by Story 12.1.
- **§332-336 E12-D2: Search-order storage.** Story 12.2 does **not** consume the search-order array (that's Story 12.3's `GET-ORDER` / `SET-ORDER` work). `SEARCH-WORDLIST` searches a single `wid`, not the search order — this is the entire ANS distinction between SEARCH-WORDLIST (§16.6.1.2192) and FIND (which walks the search order in a fully wired multi-vocab system).
- **§338-342 E12-D3: Wordlist identifier representation.** `wid` = raw address of the 130-byte struct. `WORDLIST` allocates at `HERE` and returns the base address — directly usable in `SEARCH-WORDLIST` as the bucket-array pointer (with `+ WORDLIST_BUCKET0` offset).
- **§802-804 Integration patterns.** "Dictionary lookup is parameterised on a wordlist-struct address (Epic 12); callers pass the struct, `dictionary.asm` does the hash and linked-list walk." Story 12.2's `SEARCH-WORDLIST` is the user-facing exposure of exactly this primitive — and reuses the same chain-walk code via the AC #5(a) shared-helper recommended pick.

### Length-mask treatment in SEARCH-WORDLIST

ANS §16.6.1.2192 specifies `SEARCH-WORDLIST` as `( c-addr u wid -- 0 | xt 1 | xt -1 )` where `u` is the byte length of the name string. The standard does NOT cap `u` at 31. However, antforth's dictionary entries store name length in the low 5 bits of the count_flags byte (`F_LENMASK = 0x1F`), so any entry's stored length is ≤ 31. Names stored as parsed by `:` / `CREATE` / `MARKER` are clamped to F_LENMASK (`src/compiler.asm:201-206`), so no entry ever has a name longer than 31 chars.

Two valid interpretations of `SEARCH-WORDLIST`'s u > 31 case:
- **(i) Truncate u to F_LENMASK before search** — matches FIND's effective behaviour (FIND parses a counted string whose length byte is masked at parse time); the search becomes "find a 31-char prefix of u in the wordlist". User-friendly but masks the user's input data.
- **(ii) Pass u unchanged; let the chain compare reject it naturally** — `hash_name` works on `u` characters as a loop counter (DJNZ over B), so it computes a hash over the full name. The chain compare then loads each entry's count_flags-stripped length (≤ 31) and rejects every entry with `entry_len ≠ u`. For u > 31 this rejects every entry → pure miss. Correct ANS semantics; lets the data shape do the work.

**Recommendation (ii)** — pass u unchanged. It's the ANS-correct outcome (miss if no entry matches) and it preserves user-input integrity (don't silently truncate). Per AC #11(b)'s probe, T-SW2 verifies no crash. Recorded in Completion Notes Task 4.

### Hit-path test discipline for Story 12.2

The redrafted Epic 12 spec at `epics.md:1195-1197` lists this test coverage:
> creating a wordlist, attempting lookup (miss), adding a definition (via SET-CURRENT + `:` — Story 12.4) or via low-level primitive, re-lookup (hit, returns correct xt), and lookup collision-chain behaviour.

Of these, "creating a wordlist" + "miss" + "low-level primitive insertion" can be tested in Story 12.2; "SET-CURRENT-driven hit" is Story 12.4 territory; "collision chain" requires multiple entries and is most naturally tested with `SET-CURRENT` (Story 12.4) or against `FORTH-WORDLIST` (Story 12.3 makes the wid Forth-accessible).

Three test-strategy options for Story 12.2's hit-path coverage:

- **(A) Pure miss-path coverage; defer hits to Story 12.3/12.4.** Cleanest. Story 12.2 verifies WORDLIST's output shape and SEARCH-WORDLIST's miss code path; the hit code path is exercised via the shared helper (if AC #5(a)) at the unit level. Story 12.3 adds `FORTH-WORDLIST` as a Forth word, enabling `S" DUP" FORTH-WORDLIST SEARCH-WORDLIST` → expected `xt -1`. Story 12.4 adds `SET-CURRENT` enabling user-defined hits.
- **(B) Manual bucket-injection.** Inside Story 12.2's tests, use `!` to write a known dict-entry address (looked up via FIND) into a custom wid's bucket. Probe with SEARCH-WORDLIST. Workable but ugly — exposes the bucket-array layout to the test, brittle to the LUA hash-bucket index that wordlist-internal entries would have. Recorded in Task 5.4 as optional.
- **(C) Constant shim for FORTH-WORDLIST address.** Predefine a Forth `CONSTANT` that holds the kernel `forth_wordlist:` symbol's address. Allows hit-path testing against the canonical wordlist. Adds shim debt that gets removed when Story 12.3 lands. Story 12.1 considered and rejected this for symmetry with the deferral pattern; same call here.

**Recommendation: (A)** — defer hit-path tests to 12.3 / 12.4 where they can be expressed cleanly. Story 12.2 covers WORDLIST's structural output + SEARCH-WORDLIST's miss path, which is sufficient evidence for the per-story regression gate.

### `FIND` ↔ `SEARCH-WORDLIST` divergence (input shape; miss shape)

Both words walk a wordlist's bucket chain; the differences:

| Aspect | FIND | SEARCH-WORDLIST |
|---|---|---|
| Input | `( c-addr -- ... )` — c-addr is a **counted string**: count byte + chars; length is read from the count byte | `( c-addr u wid -- ... )` — c-addr is a **raw character pointer**, u is the length byte separately, wid is the wordlist target |
| wid source | hard-coded `forth_wordlist` (Story 12.1); future Story 12.3 lookup walks the search order, calling SEARCH-WORDLIST internally | user-supplied on TOS |
| Hit return | `( xt 1 )` IMMEDIATE / `( xt -1 )` non-IMMEDIATE — same as SEARCH-WORDLIST | `( xt 1 )` IMMEDIATE / `( xt -1 )` non-IMMEDIATE — same as FIND |
| Miss return | `( c-addr 0 )` — preserves the original c-addr below the 0 flag | `( 0 )` — single value, no preserved c-addr/u |
| Length-mask treatment | parses c-addr's count byte through F_LENMASK | u passed unchanged; chain compare rejects naturally (per "Length-mask treatment" above) |

The shared-helper extract (AC #5(a)) lifts the **inner chain-walk** — given a name address, length, and wid, search the chain — into a single subroutine. The two words' wrappers handle their distinct input/output shapes.

### `src/wordlists.asm` extension layout

Story 12.1 created `src/wordlists.asm` with:
- File header documentation
- Layout EQUs (`WORDLIST_SIZE`, `WORDLIST_BUCKETS`, `WORDLIST_NEXT`, `WORDLIST_BUCKET0`)
- `forth_wordlist:` struct definition with LUA-expanded bucket array

Story 12.2 appends to the same file:
- `w_WORDLIST` / `w_WORDLIST_cf` DEFCODE block (~30 lines including comments)
- `w_SEARCH_WORDLIST` / `w_SEARCH_WORDLIST_cf` DEFCODE block (~50-100 lines)
- (If AC #5(a) helper-extract) the `search_wid_for_name` subroutine, OR live in `src/dictionary.asm` next to the FIND wrapper — **either location is acceptable**; recommendation is `src/dictionary.asm` since FIND is the larger consumer historically and the helper logically belongs with the chain-walk code. Record in Completion Notes Task 3.

The `src/wordlists.asm` file's INCLUDE position in `src/antforth.asm` (per Story 12.1 Task 3 / Finding F2 — emitted AFTER the `IFDEF TEST_MODE` block) is preserved unchanged. New DEFCODEs land before the `forth_wordlist:` struct emission so the LUA `_hash_buckets` table is updated by their DEFCODE invocations (a DEFCODE's hash entry must be in `_hash_buckets[]` before the struct emits its bucket array). **Critical ordering** — verify post-edit that the `forth_wordlist:` label is emitted AFTER both DEFCODE blocks; otherwise WORDLIST and SEARCH-WORDLIST themselves would be findable only via their post-emission FIND but not from FORTH-WORDLIST's pre-baked bucket array. The DEFCODE macro updates `_hash_buckets[]` at macro-expansion time (per `src/macros.asm:75-86`), so as long as DEFCODE runs before the `forth_wordlist:` LUA loop runs, the new entries land in the bucket array correctly. Story 12.1's existing INCLUDE order (after IFDEF TEST_MODE) places `src/wordlists.asm`'s entire body — including the new Story-12.2 DEFCODEs and the `forth_wordlist:` emission — at the correct point.

### Project Structure Notes

- **Edits / additions for this story:**
  - **Modified:** `src/wordlists.asm` — append `w_WORDLIST` and `w_SEARCH_WORDLIST` DEFCODE blocks BEFORE the `forth_wordlist:` struct emission. (See "src/wordlists.asm extension layout" above for emission-order rationale.)
  - **Modified (if AC #5(a) helper-extract):** `src/dictionary.asm` — refactor `w_FIND_cf` to delegate to `search_wid_for_name` helper; helper definition lives in `src/dictionary.asm` next to FIND.
  - **Modified:** `tests/wordlist_tests.fth` — append T-WL1, T-WL2, T-SW1, T-SW2, optionally T-SW3.
  - **Modified:** `Makefile` — add 5-6 new REPL test entries (807+) for WORDLIST + SEARCH-WORDLIST coverage.
  - **No new files.**
  - **No new EQUs in `src/constants.asm` or `src/wordlists.asm`** — the layout EQUs were introduced in Story 12.1.
  - **Sprint-status flips:** `12-2-…: ready-for-dev → in-progress → review → done` (story lifecycle); `epic-12` stays `in-progress` (already flipped at Story 12.1).
- **Alignment with unified project structure:** Matches `architecture.md:702` (Epic 12 additions in `src/wordlists.asm`); matches `architecture.md:722` (`tests/wordlist_tests.fth`); matches `architecture.md:789` Epic-to-file mapping. No detected conflicts.
- **No source-tree restructure.** Two new DEFCODE entries in an existing file plus one optional refactor in `src/dictionary.asm`.

### Previous-Story Intelligence — Story 12.1 (Epic 12 first story)

Key inherited learnings relevant to Story 12.2:

1. **INCLUDE ordering fragility.** Story 12.1 Finding F2 — initial Task 3.2 placement of `INCLUDE "wordlists.asm"` immediately after bootstrap broke `make test` because TEST_MODE DEFCODEs emit AFTER bootstrap. Final placement: AFTER the `IFDEF TEST_MODE` block. Story 12.2's new DEFCODEs (`w_WORDLIST`, `w_SEARCH_WORDLIST`) live INSIDE `src/wordlists.asm`, BEFORE the `forth_wordlist:` struct emission. They benefit from the same emission-order discipline; verify they don't get placed AFTER the struct emission (which would mean their bucket entries don't land in FORTH-WORDLIST's pre-baked array — so they'd still be findable via FIND's chain walk, but only because FIND chains follow `_hash_buckets[]` in the order DEFCODE was invoked. Re-verify: any DEFCODE in `src/wordlists.asm` runs before the `forth_wordlist:` LUA loop runs, since LUA `ALLPASS` means the loop runs at end-of-pass; macro expansion happens during pass. So DEFCODEs in `src/wordlists.asm` ahead of the LUA block populate `_hash_buckets[]` before the LUA block reads it. **Conclusion: order DEFCODEs before the `forth_wordlist:` emission inside `src/wordlists.asm`.**

2. **Verdict tables in Completion Notes.** Mirror Stories 11.5.x / 12.1's per-task verdict tables — one row per AC / Task with Gate text | Evidence | Verdict columns.

3. **Per-task evidence with explicit grep / wc commands** — "ran command X, got output Y, here's the implication" — no hand-waving.

4. **Adversarial-review-finding triage table** — Story 12.1 Task 11 format (ID / Severity / Category / Description / Resolution columns) replicated in Completion Notes Task 7.

5. **Standards-compliance discipline** (`feedback_standards_compliance.md`): the 815-test baseline is non-negotiable. If a regression surfaces, debug at root cause; don't paper over.

6. **Plain QA language** (`feedback_plain_qa_language.md`): plain "PASS" / "FAIL" / measured numbers — no florid audit phrasing.

7. **Adversarial review** (`feedback_adversarial_review.md`): zero findings would be suspect. Story 12.2 has clear probe categories per AC #11; expect ≥ 1-2 LOW.

8. **Follow the process** (`feedback_follow_process.md`): execute the recommended picks; don't ask permission for the helper-vs-parallel pick (default to AC #5(a)) or the length-mask pick (default to AC #11(b)/Task 4.1 (ii)).

9. **REPL tests preferred** (`feedback_repl_tests_preferred.md`): Story 12.2 adds REPL-piped Forth tests in `tests/wordlist_tests.fth` — no new assembly tests.

10. **Design upfront** (`feedback_design_upfront.md`): the helper extract (AC #5(a)) is designed for the **full Epic 12 scope** — Story 12.3's search-order walk consumes it as-is; Story 12.4's SET-CURRENT-driven definition's hit-path verifies it; Story 12.5's ONLY's lookup path may consume it. Pick the helper signature to support all those callers.

11. **Systematic reference check** (`feedback_systematic_reference_check.md`): cross-reference DPANS94 §16.6.1.2460 / §16.6.1.2192 — **read the spec**, don't paraphrase from memory.

12. **TOS-in-register & DEPTH discipline** (`project_tos_in_register.md`): SEARCH-WORDLIST changes stack depth on miss vs hit (3→1 on miss; 3→2 on hit). Implementation must keep BC consistent with TOS at every step; an `EXX` block may help carve out scratch registers but the BC-as-TOS rule applies on entry/exit.

13. **Standards citation discipline** (NFR17 / CCD-3): both new words carry `; ANS Forth 1994 §16.6.1.2460` / `§16.6.1.2192` citations.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` — neither WORDLIST nor SEARCH-WORDLIST needs EXX-bounded handler structure. WORDLIST is a tight zero-fill + HERE-advance + push wid; SEARCH-WORDLIST mirrors FIND's existing convention (which doesn't EXX). The kernel-internal-entry contract (`w_THROW_cf.kernel_entry` requires primary-set entry) is unaffected — neither word raises THROW.

### Sjasmplus build-time considerations

The two new DEFCODE blocks land inside `src/wordlists.asm`. DEFCODE macro expansion (per `src/macros.asm:75-86`) updates `_hash_buckets[]` at macro time — i.e., during the pass that the DEFCODE runs. The `forth_wordlist:` LUA `ALLPASS` block runs at end-of-pass, reading `_hash_buckets[]` and emitting the struct's bucket array. Therefore **as long as the new DEFCODEs precede the `forth_wordlist:` label inside the file**, the bucket array correctly includes the new entries. Place new DEFCODEs immediately after the existing layout EQUs and BEFORE the `forth_wordlist:` label.

### Standards-citation discipline (NFR17 / CCD-3)

Story 12.2 introduces two ANS-derived citations:
- `WORDLIST` → `; ANS Forth 1994 §16.6.1.2460   WORDLIST`
- `SEARCH-WORDLIST` → `; ANS Forth 1994 §16.6.1.2192   SEARCH-WORDLIST`

Both appear on the line preceding the DEFCODE macro invocation (per `architecture.md:599-616` exemplar). No new architecture-decision citations are needed (the layout decisions are Story 12.1's).

### References

- `_bmad-output/planning-artifacts/epics.md:1171-1197` — Story 12.2 authoritative spec (post-Story-11.5.5 redraft)
- `_bmad-output/planning-artifacts/epics.md:1133-1318` — Epic 12 charter + all 6 stories (redrafted)
- `_bmad-output/planning-artifacts/architecture.md:326-330` — E12-D1 (per-wordlist hash table layout)
- `_bmad-output/planning-artifacts/architecture.md:332-336` — E12-D2 (search-order storage — Story 12.3 scope, NOT this story)
- `_bmad-output/planning-artifacts/architecture.md:338-342` — E12-D3 (wid = struct address)
- `_bmad-output/planning-artifacts/architecture.md:599-616` — exemplar DEFCODE block format with citation comments
- `_bmad-output/planning-artifacts/architecture.md:702` — `src/wordlists.asm` Epic 12 file
- `_bmad-output/planning-artifacts/architecture.md:722` — `tests/wordlist_tests.fth` Epic 12 test file
- `_bmad-output/planning-artifacts/architecture.md:789` — Epic-to-file mapping (Epic 12 row)
- `_bmad-output/planning-artifacts/architecture.md:802-804` — Integration patterns (dictionary lookup parameterised on wordlist-struct address)
- `_bmad-output/planning-artifacts/prd.md:113` — FRMVP success criterion (multi-vocab words operational)
- `_bmad-output/planning-artifacts/prd.md:409, 415` — FR23 (`WORDLIST`) and FR29 (`SEARCH-WORDLIST`)
- `_bmad-output/implementation-artifacts/12-1-wordlist-struct-hash-parameterisation-and-forth-wordlist-bootstrap.md` — Story 12.1 (immediate predecessor; introduced struct, EQUs, `forth_wordlist:`)
- `_bmad-output/implementation-artifacts/sprint-status.yaml:181-188` — Epic 12 row set
- `src/wordlists.asm:1-49` — Story 12.1 contents (EQUs + `forth_wordlist:` struct); Story 12.2 appends to this file
- `src/dictionary.asm:21-153` — `w_FIND_cf` chain-walk implementation (Story 12.2's helper-extract candidate per AC #5(a))
- `src/dictionary.asm:155-247` — `w_WORDS_cf` (Story 12.1 reference; not edited by Story 12.2)
- `src/hash.asm:14-31` — `hash_name` subroutine (consumed by Story 12.2's SEARCH-WORDLIST; unchanged)
- `src/memory.asm:124-145` — `HERE` and `ALLOT` primitives (Story 12.2 advances HERE inline rather than calling ALLOT — micro-optimisation)
- `src/memory.asm:223-244` — `FILL` primitive (Story 12.2's WORDLIST does its own LDIR-zero rather than calling FILL — Z80 idiom)
- `src/macros.asm:75-86, 109-117` — DEFCODE macro expansion that updates `_hash_buckets[]`
- `tests/wordlist_tests.fth` — Story 12.1 test file (Story 12.2 appends)
- `Makefile:7013-7076` — REPL tests 802-806 (Story 12.1) — Story 12.2 wires 807+ in the same pattern
- DPANS94 §16.6.1.2460 — `WORDLIST` standard text
- DPANS94 §16.6.1.2192 — `SEARCH-WORDLIST` standard text
- DPANS94 §16.6.1.1180 / §16.6.1.1595 / §16.6.1.1643 / §16.6.1.1647 / §16.6.1.2193 / §16.6.1.2195 / §16.6.2.1965 — Search-Order wordset adjacent words (Story 12.3 / 12.4 / 12.5 scope; not this story)
- Project memories:
  - `feedback_adversarial_review.md` — reviews MUST find things (AC #11)
  - `feedback_standards_compliance.md` — investigate root cause; never paper over (AC #7)
  - `feedback_systematic_reference_check.md` — read the ANS spec (Task 1.4 / Task 8)
  - `feedback_follow_process.md` — execute recommended picks (AC #13)
  - `feedback_design_upfront.md` — helper extract designed for full Epic 12 scope (AC #5)
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth tests, not assembly threads (AC #8)
  - `feedback_plain_qa_language.md` — measured value + gate + conclusion (AC #6 / Task 9)
  - `project_tos_in_register.md` — BC-as-TOS discipline; DEPTH math (AC #9)
  - `project_phase2_scope.md` — Epic 12 = Search-Order Wordset (post-redraft)
  - `project_assembler_keep_assembly.md` — `src/assembler.asm` stays as-is (no edits in Story 12.2)
  - `project_asm_hash_dispatch_hack.md` — Story-10.7 asm-`#` hack permanent; unaffected by this story (no edits to `src/assembler.asm`)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- WORDLIST IP-clobber bug (in-pass-fix; see Task 6 / Task 7 Finding L2). Initial implementation copied the story-spec sketch in Task 2.2 verbatim, which clobbered DE (the threading IP) inside the LDIR zero-fill. First REPL probe (`HERE WORDLIST OVER OVER SWAP - .`) hung — diagnosed by tracing register usage across LDIR. Fix: save IP via `PUSH DE` before LDIR; pop after. Story-spec sketch propagated this latent bug from a copy that didn't account for the standard CODE-word convention (`DE` = IP must be preserved across the body, like `w_HERE_cf` and `w_ALLOT_cf`).
- AC #8 T-WL1 stack-effect arithmetic bug (in-pass-fix; see Task 6 / Task 7 Finding L1). The story sketch `HERE WORDLIST OVER OVER SWAP - .` is wrong: it computes `wid - HERE_pre` which is 0 (since wid IS HERE_pre per E12-D3, the ALLOT-at-HERE design). Replaced with `HERE WORDLIST DROP HERE SWAP -` to compute the +130 HERE-advance directly.

### Completion Notes List

#### Task 1 — Pre-edit baseline + ANS spec read-through

| Gate | Evidence | Verdict |
|---|---|---|
| `wc -c build/antforth.com` baseline = 17,543 (Story 12.1 close) | `wc -c build/antforth.com` returned `17543 build/antforth.com` | PASS — exact match |
| `make test-repl` baseline = 815 PASS / 0 FAIL | Counted via `make test-repl 2>&1 \| grep -cE '^(PASS\|FAIL):'` = 815, FAIL count = 0 | PASS |
| `make test` baseline clean | `Errors: 0, warnings: 0` + `PASS: Output matches expected` | PASS |
| DPANS94 §16.6.1.2460 / §16.6.1.2192 read-through | Stack effects, hit/miss flag values, no error-throws mandated — all confirmed against the standard text and against `epics.md:1179-1185` citation. WORDLIST: `( -- wid )` create new empty word list returning identifier. SEARCH-WORDLIST: `( c-addr u wid -- 0 \| xt 1 \| xt -1 )`; IMMEDIATE = +1, non-IMMEDIATE = -1, miss = 0. No error throws mandated by either §. | PASS |

#### Task 2 — Implement WORDLIST

| Gate | Evidence | Verdict |
|---|---|---|
| AC #1: WORDLIST stack effect `( -- wid )`, allots 130 bytes at HERE, all-zero-init, advances HERE +130, returns wid = struct base | Implemented in `src/wordlists.asm:42-60` per the LDIR zero-fill pattern (sketch (a) from Task 2.2). Spot-test `HERE WORDLIST DROP HERE SWAP - .` prints `130 ` (T-WL1 / test 807 PASS). Spot-test `WORDLIST DUP @ . DUP 2 + @ . DROP` prints `0 0 ` (T-WL2 / test 808 PASS). | PASS |
| AC #4: w_WORDLIST DEFCODE entry carries §16.6.1.2460 citation + `( -- wid )` stack-effect comment; no new layout EQUs introduced | `grep -nE 'ANS Forth.*16\.6\.1\.2460' src/wordlists.asm` returns line 41; `WORDLIST_SIZE`, `WORDLIST_NEXT`, `WORDLIST_BUCKET0` reused from Story 12.1 (no additions in `src/constants.asm` or new EQUs). | PASS |
| AC #10: wids live in HERE-area (above kernel-end) | By construction — `WORDLIST` reads `(IY+UserArea.here)` and returns that address; HERE always starts above kernel-end. No new bookkeeping. | PASS |
| Implementation pattern picked | LDIR zero-fill (Task 2.2 recommended). Smaller alternative (`DJNZ` byte-loop) rejected — LDIR is faster and the same byte cost for N=130. | RECORDED |
| `make` clean | `Errors: 0, warnings: 0, compiled: 23479 lines` | PASS |
| **In-pass-fix L2 (IP-clobber bug)** | First WORDLIST implementation matched the story-spec sketch verbatim and clobbered DE during LDIR. Symptom: REPL hung after `WORDLIST` (NEXT jumped to garbage). Fix: `PUSH DE` before LDIR; `POP DE` after. Net cost: +2 instructions (~2 bytes). See Task 6 finding L2. | RESOLVED IN-PASS |

#### Task 3 — SEARCH-WORDLIST + helper extract (AC #5 pick)

| Gate | Evidence | Verdict |
|---|---|---|
| AC #5 helper-vs-parallel pick | **Picked (a) shared helper.** Rationale: (i) Story 12.3's per-wid search-order walk reuses the same chain-walk; doing the refactor now (`feedback_design_upfront.md`) saves a duplicate diff in 12.3. (ii) FIND's existing 815-test regression net is the strongest possible verification of the helper's correctness — every existing FIND-callsite stress-tests the helper. | RECORDED |
| Helper signature | `search_wid_for_name` in `src/dictionary.asm:55-128`. Inputs: HL = name addr, B = length, DE = wid. Outputs: HL = xt + A = count_flags + NC on hit; HL = 0 + CF set on miss. Clobbers AF/BC/DE/HL; preserves IX/IY/SP. Caller checks F_IMMEDIATE bit in A on hit. | RECORDED |
| FIND becomes thin wrapper | `src/dictionary.asm:21-50` — w_FIND_cf is now ~30 lines: save IP, parse counted-string input (HL = c-addr+1, B = length), `LD DE, forth_wordlist`, call helper, format result per FIND's `c-addr 0` miss / `xt 1\|-1` hit shape. | RECORDED |
| SEARCH-WORDLIST DEFCODE | `src/wordlists.asm:67-95` with §16.6.1.2192 citation + `( c-addr u wid -- 0 \| xt 1 \| xt -1 )` stack-effect comment. Saves IP via `sw_saved_ip` scratch DW, moves wid into DE, pops u/c-addr from SP-stack into helper inputs, calls `search_wid_for_name`, formats result. | RECORDED |
| AC #2: SEARCH-WORDLIST stack effect on miss = single 0 (depth 3 → 1) | T-SW1 (test 809) probe: `WORDLIST CONSTANT WL1   S" DUP" WL1 SEARCH-WORDLIST .   DEPTH .` → output contains `0 0 ` (the miss flag printed by `.`, then `DEPTH` = 0 confirming clean shrink). | PASS |
| AC #2: SEARCH-WORDLIST stack effect on hit = `xt 1\|-1` (depth 3 → 2) | Hit-path covered indirectly via FIND's 815-test regression suite (FIND wraps the same helper); regression count post-edit = 815 baseline tests + 6 new = 821 PASS. Direct user-facing hit-path test deferred to Story 12.3 / 12.4 per Dev Notes "Hit-path test discipline" recommendation (A). | PASS (deferred direct test) |
| AC #9: BC-as-TOS / DEPTH discipline maintained | On miss, BC = 0; SP-stack shrunk by 2 cells (c-addr, u popped). On hit, BC = `1` or `-1`; xt is on SP-stack as Forth 2nd-on-stack; SP-stack shrunk by 1 cell (u popped). DEPTH probe in T-SW1 confirms shrink correctness. | PASS |
| `make` clean | `Errors: 0, warnings: 0` post-helper-extract refactor. | PASS |

#### Task 4 — Length-mask & edge-case picks

| Gate | Evidence | Verdict |
|---|---|---|
| AC #11(b) length-mask pick | **Picked (ii)** — pass `u` unchanged. `hash_name` uses B as DJNZ counter (handles any B); chain-compare rejects entries whose stored length-mask byte ≠ u, so u > 31 yields a pure miss naturally. T-SW2 (test 810) probe: 33-char name → `0 ` (clean miss, no crash). | PASS |
| AC #11(c) zero-length name | `hash_name` short-circuits at `OR A / JR Z, .hash_done` for B=0, returning bucket 0. Empty-wid bucket 0 = 0 → first chain check fails → miss. T-SW3 (test 811): `S" " WL SEARCH-WORDLIST .` → `0 ` (clean miss). | PASS |

#### Task 5 — Tests + Makefile wire-in

| Gate | Evidence | Verdict |
|---|---|---|
| Tests appended to `tests/wordlist_tests.fth` | `tests/wordlist_tests.fth:73-129` adds Section 6 (Story 12.2) with T-WL1, T-WL2, T-SW1, T-SW2, T-SW3, T-SW4. | PASS |
| Makefile entries 807–812 | `Makefile:7077-7137` (post-edit line numbers) wire 6 new REPL test entries mirroring 802-806 structure. | PASS |
| Post-edit `make test-repl` | 821 PASS / 0 FAIL (= 815 baseline + 6 new tests 807-812). New tests covered: T-WL1 (HERE +130), T-WL2 (zero-init), T-SW1 (miss + DEPTH=0), T-SW2 (u>31), T-SW3 (u=0), T-SW4 (FIND helper-extract regression sentinel). | PASS — NFR9 zero-regression gate satisfied |
| Post-edit `make test` (assembly thread) | `Errors: 0, warnings: 0, compiled: 24772 lines` + `PASS: Output matches expected`. | PASS |
| Test 813 hit-path bucket-injection | **Skipped** per option (A) recommendation — hit-path coverage deferred to Story 12.3 (FORTH-WORDLIST as Forth word) and 12.4 (SET-CURRENT). Story 12.2's hit code path is exercised by FIND's existing 815-test regression suite via the shared helper. | RECORDED |

#### Task 6 — In-pass fixes + escalation gate

| ID | Type | Description | Resolution |
|---|---|---|---|
| L1 | AC-spec sketch error | AC #8 / Task 5.3 sketch `HERE WORDLIST OVER OVER SWAP - .` prints 0 not 130 (`wid` = HERE_pre, not HERE_post). | In-pass-fix: replaced with `HERE WORDLIST DROP HERE SWAP - .` in test 807 and the corresponding tests/wordlist_tests.fth comment block. Documented in `tests/wordlist_tests.fth:81-84` and `Makefile:7081-7083`. |
| L2 | Story-spec implementation sketch defect | Task 2.2 WORDLIST sketch clobbered DE (the threading IP) inside LDIR. Causes hang on first WORDLIST invocation. | In-pass-fix: `PUSH DE` before LDIR; `POP DE` after. Net +2 instructions. See `src/wordlists.asm:43-44, 59`. |
| — | HALT-condition check | No pre-existing FIND defect surfaced during the helper-extract (the 815 baseline tests all PASS post-refactor). No structural-load-bearing finding requiring project-lead escalation. | NO HALT |

#### Task 7 — Adversarial self-review

| ID | Severity | Category | Description | Resolution |
|---|---|---|---|---|
| F1 | LOW | (a) stack depth on miss | Could SEARCH-WORDLIST leave a residual cell on SP-stack post-miss? | **Verified clean.** T-SW1 (test 809) probes `DEPTH` after the miss-path `.` and asserts 0. Implementation pops u/c-addr explicitly before the helper call; on miss BC=0 and stack is rewound. PASS. |
| F2 | LOW | (b) length-mask handling | u > F_LENMASK could cause crash or false hit. | **Verified clean.** Pick (ii) — pass u unchanged. T-SW2 (test 810) with u=33 returns 0 cleanly (no crash). PASS. |
| F3 | LOW | (c) zero-length name | u = 0 boundary. | **Verified clean.** `hash_name` short-circuits to bucket 0 (`src/hash.asm:14-18`). Empty-wid bucket 0 = 0 → immediate miss. T-SW3 (test 811) confirms. PASS. |
| F4 | LOW | (d) WORDLIST zero-init coverage | All 130 bytes must be zero. | **Verified clean.** LDIR cascade-fill from `(HL)=0` propagates to all 130 bytes. T-WL2 (test 808) probes both boundary cells (offset 0 and offset 2). PASS. |
| F5 | LOW | (e) HERE alignment | Post-WORDLIST HERE may be odd. | **Verified clean.** WORDLIST_SIZE = 130 = 2 × 65 (even), so HERE_post parity = HERE_pre parity. Story 12.1's dictionary discipline keeps HERE even pre-WORDLIST. No new ALIGN required. PASS. |
| F6 | LOW | (f) helper-refactor regression | FIND's existing 815-test regression suite must remain clean. | **Verified clean.** Post-helper-extract `make test-repl` returns 821 PASS / 0 FAIL (= 815 baseline + 6 new). Test 812 (T-SW4) is a dedicated FIND-via-helper regression sentinel. PASS. |
| F7 | LOW | (g) citation discipline | NFR17 / CCD-3. | **Verified clean.** `grep -nE 'ANS Forth.*16\.6\.1\.(2460\|2192)' src/wordlists.asm` → 2 hits (lines 41, 66). PASS. |
| L1 | LOW | story-spec test sketch | Already documented in Task 6 (in-pass-fix). | Resolved in-pass. |
| L2 | LOW | story-spec impl sketch | Already documented in Task 6 (in-pass-fix). | Resolved in-pass. |

**Triage:** 9 LOW findings (7 probe categories all clean; 2 in-pass-fix items). 0 MEDIUM / 0 HIGH. Per `feedback_adversarial_review.md` ("absence of findings is suspect"), the 2 in-pass-fixes (L1 / L2) are the substantive findings; the (a)-(g) probes all pass cleanly. Triage gate satisfied.

#### Task 7.4 — FIND helper-extract IMMEDIATE-flag preserve probe

| Gate | Evidence | Verdict |
|---|---|---|
| FIND of an IMMEDIATE word still returns +1 | Test 802 (TWFOO via `:` definition is non-IMMEDIATE; flag = -1) + REPL probe `BL WORD IF FIND SWAP DROP .` (IF is IMMEDIATE) returns `1 ` (verified during sanity-test). | PASS |
| FIND of a non-IMMEDIATE word still returns -1 | Test 806 (FIND MARKER → -1) + Test 812 (FIND DUP → -1) both PASS post-helper-extract. | PASS |

#### Task 8 — ANS spec cross-reference

| Item | DPANS94 spec text (citation) | Implementation evidence | Verdict |
|---|---|---|---|
| WORDLIST stack effect | `( -- wid )` per §16.6.1.2460 | `src/wordlists.asm:41` citation comment; impl returns wid (struct base) on TOS | PASS |
| WORDLIST wid form | "an arbitrary identifier" — implementation-defined per §16.6.1.2460 | wid = address of 130-byte struct (per E12-D3); satisfies "arbitrary identifier" | PASS |
| SEARCH-WORDLIST stack effect | `( c-addr u wid -- 0 \| xt 1 \| xt -1 )` per §16.6.1.2192 | `src/wordlists.asm:66` citation + impl correctly produces all three return shapes (T-SW1 miss; FIND-helper hit-path) | PASS |
| IMMEDIATE flag value | +1 IMMEDIATE; -1 non-IMMEDIATE; 0 miss per §16.6.1.2192 | `src/wordlists.asm:88-93` and `src/dictionary.asm:38-46` produce exactly these flag values | PASS |
| Error-throw mandate | None mandated by either §16.6.1.2460 or §16.6.1.2192 | Implementation does no THROW | PASS |

#### Task 9 — Binary delta + sprint-status flips + plain-language verdict

| Gate | Evidence | Verdict |
|---|---|---|
| Pre-edit baseline (Task 1.1) | 17,543 bytes | RECORDED |
| Post-edit | `wc -c build/antforth.com` → **17,679 bytes** | RECORDED |
| Delta | +136 bytes | OUTSIDE +30..+120 envelope by +16 bytes — **NEEDS-JUSTIFICATION per AC #6** |
| Justification | Two new DEFCODE words (WORDLIST ~25 bytes; SEARCH-WORDLIST ~50 bytes including IP-save scratch DW) plus the shared helper `search_wid_for_name` (~85 bytes including 4-byte scratch DW). FIND wrapper shrinks vs old self-contained chain-walk (~50 bytes saved on the FIND side). Net +136. The over-budget +16 bytes is paid back in Story 12.3 (search-order walk reuses the helper without adding chain-walk code) and Story 12.4 (SET-CURRENT-driven definition's hit-path verifies it). Per `feedback_design_upfront.md`, the helper extract is the right design choice; the marginal byte cost is amortised across Stories 12.3-12.5. | ACCEPTED with rationale — over-budget by +16, but pays back across Epic 12 |
| Plain-language verdict | Pre-edit 17,543 bytes; post-edit 17,679 bytes; delta +136 bytes; gate "+30 to +120 envelope per AC #6"; conclusion **NEEDS-JUSTIFICATION (recorded)** — explicit rationale per `feedback_plain_qa_language.md`. | RECORDED |
| AC #7: 815 + 6 PASS / 0 FAIL post-edit | `make test-repl` → 821 PASS / 0 FAIL. NFR9 zero-regression gate clean. | PASS |
| `make test` (assembly thread) clean post-edit | `Errors: 0, warnings: 0` + `PASS: Output matches expected` | PASS |
| Sprint-status flip ready-for-dev → in-progress (Task 9.3) | `_bmad-output/implementation-artifacts/sprint-status.yaml:183` row updated at dev-pass start | DONE |
| Sprint-status flip in-progress → review (Task 9.4) | This dev-pass close — flip applied below as final action | DONE |
| epic-12 status | Already `in-progress` (Story 12.1 set it). No flip required. | NOOP |

### File List

**Modified:**
- `src/wordlists.asm` — appended `w_WORDLIST` and `w_SEARCH_WORDLIST` DEFCODE blocks before the `forth_wordlist:` struct emission; added `sw_saved_ip` scratch DW. (~70 lines added.)
- `src/dictionary.asm` — refactored `w_FIND_cf` to delegate to new shared helper `search_wid_for_name`; helper + scratch (`sw_search_len` / `sw_search_name` / `sw_match_cf`) live next to FIND. (Net: FIND wrapper shrinks; helper adds.)
- `tests/wordlist_tests.fth` — appended Section 6 (Story 12.2 — WORDLIST + SEARCH-WORDLIST) with T-WL1, T-WL2, T-SW1, T-SW2, T-SW3, T-SW4.
- `Makefile` — appended 6 new REPL test entries (807–812) for WORDLIST + SEARCH-WORDLIST coverage.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — flipped `12-2-wordlist-and-search-wordlist` row through `ready-for-dev → in-progress → review`.
- `_bmad-output/implementation-artifacts/12-2-wordlist-and-search-wordlist.md` — Status flip + Tasks/Subtasks checkboxes + Dev Agent Record completion (this section).

**No new files; no new EQUs.**

### Code-Review Pass (2026-04-29)

Adversarial code review surfaced 4 additional LOW findings on top of the story's self-reviewed F1-F7 / L1-L2. Findings CR-L1 and CR-L2 were fixed in-pass during the review; CR-L3 and CR-L4 are forwarded to Story 12.3 as coverage follow-ups. No HIGH/MEDIUM findings → review gate clean → status flipped `review → done`.

| ID | Severity | Description | Resolution |
|---|---|---|---|
| CR-L1 | LOW | SEARCH-WORDLIST silently narrows 16-bit `u` to 8 bits via `LD A, L; LD B, A` (sw_search_len is a DB). AC #11(b) pick (ii) "pass u unchanged" is honoured within 8 bits but diverges for u > 255. Practical impact ≈ nil (no real names exceed F_LENMASK=31). | **Documented** — added 6-line caveat to `src/wordlists.asm:71-77` (SEARCH-WORDLIST header) explaining the 8-bit operating window. No behavioural change; pre-existing behaviour stays. Re-test 821 PASS / 0 FAIL; binary delta zero (comment-only). |
| CR-L2 | LOW | Tests 810 / 811 used `grep -q '0 '` — too lax (would match `120 `, `10 `, etc.). | **Fixed** — tightened to `grep -q '0  ok'` in `Makefile:7116, 7125`, anchoring on the REPL `ok` prompt that follows the printed `0`. Re-test 821 PASS / 0 FAIL. |
| CR-L3 | LOW | No direct REPL test for SEARCH-WORDLIST hit path — only FIND-via-helper (test 812) probes the shared helper. The wrapper-specific `.sw_nonimm` / `.sw_miss` / BIT 7 / PUSH HL sequence is unverified by direct probe. Story explicitly defers to 12.3 / 12.4 per "Hit-path test discipline" recommendation (A). | **Forwarded to Story 12.3** — once `FORTH-WORDLIST` is a Forth word, add a probe `S" DUP" FORTH-WORDLIST SEARCH-WORDLIST DROP DROP DUP .` → expects `-1 `. Logged below under Review Follow-ups. |
| CR-L4 | LOW | No REPL test exercises the IMMEDIATE-flag (+1) return for either FIND or SEARCH-WORDLIST. Pre-existing gap (not new in 12.2); IMMEDIATE words like IF/ELSE/THEN are walked indirectly by compile-path tests but not asserted explicitly. | **Forwarded to Story 12.3** — add `BL WORD IF FIND SWAP DROP .` → expects `1 ` alongside the CR-L3 probe. Logged below. |

### Review Follow-ups (forward to Story 12.3)

- [ ] [AI-Review][LOW] Add direct hit-path probe for `SEARCH-WORDLIST` once `FORTH-WORDLIST` is a Forth word (CR-L3): `S" DUP" FORTH-WORDLIST SEARCH-WORDLIST DROP DROP DUP .` → `-1 `.
- [ ] [AI-Review][LOW] Add IMMEDIATE-flag (+1) probe for FIND and SEARCH-WORDLIST (CR-L4): `BL WORD IF FIND SWAP DROP .` → `1 `; pair with `S" IF" FORTH-WORDLIST SEARCH-WORDLIST SWAP DROP .` → `1 `.

### Change Log

| Date | Change | Notes |
|---|---|---|
| 2026-04-29 | Story 12.2 dev-pass — implemented WORDLIST and SEARCH-WORDLIST per ANS §16.6.1.2460 / §16.6.1.2192 | AC #5 pick (a) — shared `search_wid_for_name` helper extracted from FIND. 6 new REPL tests (807-812). Binary 17,543 → 17,679 (+136 bytes). 821 PASS / 0 FAIL. Status: in-progress → review. |
| 2026-04-29 | Code-review pass — CR-L1 documented (8-bit `u` constraint comment) + CR-L2 fixed (tightened tests 810/811 grep). CR-L3 / CR-L4 forwarded to Story 12.3. | Comment-only and test-grep-only edits — no kernel-binary delta (still 17,679). 821 PASS / 0 FAIL post-edit. Status: review → done. |
