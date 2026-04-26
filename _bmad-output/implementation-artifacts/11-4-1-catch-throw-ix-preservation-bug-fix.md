# Story 11.4.1: CATCH/THROW i*x preservation bug fix

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want `CATCH` to preserve the i*x cells underneath my caught xt across the entire round-trip — both on the normal-return path and on the THROW-recovered path — so that `1 2 3 ' DROP CATCH . . . .` prints `-4 3 2 1` instead of `-4 <garbage> <garbage> <garbage>`,
so that the spirit of ANS Forth 1994 §6.1.0875 / §9.6.1.0875 (`( i*x xt -- j*x 0 | i*x n )`) is honoured for non-empty pre-CATCH stacks (the standards-compliance basis for this fix; FR21/FR22 cover only the uncaught-THROW REPL recovery path and are not load-bearing here) and Story 11.4's deferred AC #9 / #11 / #12 sub-claims (Note A + review R-H1) move from PARTIAL to PASS.

This is a **bug-fix story** sandwiched between Story 11.4 (just landed in `review`) and Story 11.5 (compiler/dictionary migration). The defect is structural in the Story 11.2 CATCH frame design and was surfaced empirically during Story 11.4's adversarial review pass: the `1 ' + CATCH . .` round-trip returns `-4 1483` instead of `-4 1` because `+`'s entry-time `CALL check_underflow_2` writes its return-address byte at `[saved-SP]` — the same memory cell where `CATCH` saved i*x's TOS just above the post-`POP BC` cursor. The cell never gets restored, so THROW's `LD SP, HL` lands on a stale return-address byte. The defect exists silently across all of Story 11.2 / 11.3 / 11.4 — it was masked from earlier tests because (a) the empty pre-CATCH stack case has no i*x cell to preserve, and (b) colon-body THROWs (`: T1 42 THROW ;`) coincidentally restore the cell via their own LIT push before `THROW` runs.

The hard ordering constraint (`sprint-status.yaml:139-152`): **must land before Story 11.7's ABORT-retarget** because Story 11.7 materially expands the kernel-internal-source-THROW caller set (every `ABORT` site funnels through `-1 THROW` post-Story-11.7), amplifying the user-visible impact. Until this story lands, every kernel-internal THROW from a `CALL`-prefixed primitive corrupts the user's i*x view on the caught path.

## Acceptance Criteria

1. **Given** the Story 11.4 Note A defect description and the empirical evidence captured in Story 11.4 Completion Notes (`1 ' + CATCH . .` → `-4 1483`), **when** the post-fix code lands, **then** the same incantation prints `-4 1  ok` — the i*x's TOS-cell `1` is restored as the second-on-stack underneath the `-4 THROW` code. Verified by a new REPL test in `tests/throw_migration_tests.fth` Section 1 mirroring this pattern (the smallest reproducer of the defect).

2. **Given** the Story 11.4 AC #9 spec form (`1 2 3 ' DROP CATCH . . . .` → `-4 3 2 1  ok`) deferred to Story 11.4.1, **when** the fix lands, **then** the test passes. The `DROP` underflows after `CATCH` consumed the xt, the kernel-internal `-4 THROW` fires, the caught-path restore lands `-4` in BC and the three i*x cells `3 2 1` underneath SP — printed in order by the four `.`s.

3. **Given** the Story 11.4 AC #11 spec form (`1 2 3 ' DROP CATCH DEPTH .` → `4  ok`) deferred to Story 11.4.1, **when** the fix lands, **then** the test passes. Post-THROW `BC = -4` (real TOS), `[SP] / [SP+2] / [SP+4]` hold `3 / 2 / 1`, `DEPTH` reports `4` (BC + 3 SP cells).

4. **Given** the Story 11.4 AC #12 spec form (`5 6 7 : T 1 0 / ; ' T CATCH DEPTH .` → `4  ok`) deferred to Story 11.4.1, **when** the fix lands, **then** the test passes. The `1 0 /` raises the kernel-internal `-10 THROW` from the `udivmod` divisor-zero guard added by Story 11.4; the caught-path restore preserves the three i*x cells `5 6 7` underneath the `-10`; `DEPTH` reports `4`.

5. **Given** the Story 11.2 / 11.3 8-byte exception-frame layout (`architecture.md:270-279`) where slot `+2` is documented as "saved IX (absolute rstack pointer at CATCH entry — for unwinding nested rstack frames)" but is in fact **dead code** — verifiable pre-edit: `grep -nE 'IX\+2|IX\+3' src/exception.asm` shows only the CATCH backfill writes (`src/exception.asm:92-93`); no read site exists in `catch_resume_cf` or `w_THROW_cf.kernel_entry` — **when** Story 11.4.1 lands, **then** the `+2` slot is **repurposed** as `saved BC` (i*x's TOS-cell value at CATCH entry, captured from BC immediately after `POP BC`). Frame size remains **8 bytes** (no growth — preserves CCD-1's "Exception frame: 8 bytes" row at `architecture.md:176`).

6. **Given** the new `+2` slot semantic (saved BC), **when** `CATCH` pushes a frame, **then** the field is written from BC immediately after `POP BC` (BC then holds i*x's TOS-cell value). The pre-edit "saved-IX backfill" sequence at `src/exception.asm:89-93` (`PUSH IX / POP HL / LD (IX+2), L / LD (IX+3), H`) is **deleted**; the new sequence stores BC's low/high bytes at `(IX+0) / (IX+1)` of the saved-BC slot during the frame-push pass. Net source-line change: roughly `-4 / +2` (2 fewer lines after replacing the backfill with a direct store).

7. **Given** the new `+0` slot semantic (saved SP captured **after** `POP BC`, not before), **when** `CATCH` pushes a frame, **then** `+0` holds `SP_safe` = the SP value one cell above the original `[old SP]` location (i.e., the post-`POP BC` SP). The pre-edit `LD HL, 0 / ADD HL, SP` at `src/exception.asm:66-67` (which captured SP **before** `POP BC` — the root of the bug) is **moved**: SP capture now happens after the `LD H,B / LD L,C / POP BC` reordering, with a `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` idiom (stash xt on system stack so HL is free for SP capture, then recover SP_safe = `current SP + 2` to undo the PUSH).

8. **Given** the new `w_THROW_cf.kernel_entry` caught-path algorithm (`src/exception.asm:236-290`), **when** the caught path executes, **then** it reads `+0` into HL (= SP_safe), pops the 8-byte frame (`LD BC, 8 / ADD IX, BC`), reads the popped-frame's old `+2` slot via `LD C, (IX-6) / LD B, (IX-5)` (now BC = saved i*x's TOS-cell), executes `LD SP, HL` (restore SP_safe), executes `PUSH BC` (restore i*x's TOS-cell to data stack — overwriting whatever return-address garbage may have been left by xt's CALLs at `[SP_safe-2]`), then loads `BC, (throw_saved_n)` (THROW code) and `NEXT`s. Final invariant: `BC = n` (real TOS), `[SP] = i*x's TOS-cell`, `[SP+2] = i*x's second-from-top` (preserved across xt by the Z80 PUSH/CALL discipline that never writes at-or-above SP), … `[SP+2*(K-1)] = i*x's deepest`, where `K` was the i*x cell count at CATCH entry.

9. **Given** the unchanged `catch_resume_cf` normal-return path (`src/exception.asm:127-151`), **when** an xt completes normally without THROW, **then** `catch_resume_cf` continues to `PUSH BC` (xt's final TOS), pop the 8-byte frame, install `BC = 0`, and NEXT — no read of `+0` or `+2` on this path. The `+2` slot's repurposing has zero behavioural impact on the normal-return path. (Pre-edit verification: `grep -nE 'IX\+2|IX\+3' src/exception.asm` shows no read of `+2/+3` in `catch_resume_cf` body — confirmed at story-drafting time on `src/exception.asm:127-151`.)

10. **Given** the existing `tests/exception_tests.fth` tests pre-edit (152 lines covering Story 11.2 normal-return, Story 11.3 caught/uncaught/nested) and `tests/throw_migration_tests.fth` (110 lines covering Story 11.4 underflow + divisor-zero), **when** Story 11.4.1 lands, **then** every existing test continues to pass (Section 1 normal-return, Section 3 nested, Section 7 caught round-trip, Section 8 nested-CATCH chain-walk, Section 9 uncaught recovery — all unchanged). The fix must not regress any prior coverage.

11. **Given** the new test surface (the four spec-form ACs above plus the smallest reproducer from AC #1), **when** Story 11.4.1 lands, **then** `tests/exception_tests.fth` Section 7 gains the AC #2-style explicit i*x-preservation tests at the colon-body-THROW path (`1 2 3 ' T1 CATCH . . . .` → `42 3 2 1  ok` — pre-fix this test passes by coincidence; post-fix it passes by design and the Section 7 comment notes the fragility removal) and `tests/throw_migration_tests.fth` Sections 1 + 2 gain the kernel-internal-THROW i*x-preservation tests (the AC #1 / #2 / #3 / #4 forms). Per `feedback_repl_tests_preferred.md` all tests are REPL-piped Forth scripts; the matching Makefile `printf | $(IZCPM)` blocks are appended starting at the highest existing PASS test number + 1 (verify with `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending).

12. **Given** the i*x-preservation discipline applies symmetrically to **nested CATCH** (the inner catch's THROW must restore the inner i*x; the outer catch's THROW (if it fires) must restore the outer i*x), **when** Story 11.4.1 lands, **then** at least one nested-CATCH-with-i*x test in `tests/exception_tests.fth` Section 8 covers this — e.g. `: T -5 THROW ; : N ['] T CATCH ; 1 2 ' N CATCH . . . . →` `0 -5 2 1  ok` (inner CATCH catches `-5`, returns `(-5)` as its CATCH result, leaving the outer CATCH's i*x = `(1, 2)` intact; outer CATCH normal-returns with `0` as success and the prior `(-5, 2, 1)` underneath). Pre-fix this test would print `0 -5 <garbage> <garbage>`; post-fix it prints the spec form.

13. **Given** the architecture decision E11-D1 (`architecture.md:270-279`) and CCD-1 (`architecture.md:166-191`), **when** the `+2` slot semantic changes, **then** **both** `architecture.md` and the source-file frame-layout comment blocks at `src/exception.asm:14-19, 41-46` are updated in lockstep:
    - `architecture.md:275-278` frame-layout block: `+2: saved IX` → `+2: saved BC` with the new "i*x's TOS-cell value at CATCH entry; restored to data stack on THROW caught path" gloss. Frame size **stays 8 bytes** — no edit to the table-row at `architecture.md:176`.
    - `architecture.md:282` CATCH steps list: "saved IX = current IX (post-frame-push)" clause replaced with "saved BC = i*x's TOS-cell value (= BC immediately after POP BC)".
    - `architecture.md:296` THROW caught-path step 3: "Restore SP and IX from the target exception frame" amended to "Restore SP from the target exception frame's saved-SP slot, then push saved-BC back to the data stack as the new second-on-stack" (the IX restore is implicit via `CATCH-TOP` chain — the `saved IX` slot was always dead).
    - `src/exception.asm:14-19` (file-header frame-layout block) and `:41-46` (CATCH-docstring frame-layout block): both updated to match the new `+2` semantic.

14. **Given** the standards-citation discipline (CCD-3 / NFR17 / NFR18, `architecture.md:206-216`), **when** Story 11.4.1 edits the CATCH and THROW code paths, **then** the new comment block at the SP-capture-after-POP-BC site carries an inline reference to **why** the order matters: "saved-SP captured **after** POP BC so that any subsequent CALL inside xt (e.g., `check_underflow`'s `CALL`) writes its return-address byte at `[SP_safe-2]`, never at `[SP_safe]` — preserving the i*x-TOS-cell saved at frame +2. Pre-Story-11.4.1 this was inverted, with [old-SP] = i*x-TOS-cell, then xt's CALLs would clobber it (Story 11.4 Note A)."

15. **Given** the `TOS-in-register & DEPTH` discipline (`project_tos_in_register.md`), **when** the new caught-path lands, **then** the post-NEXT invariant is restored to the spirit of Story 11.3's stated guarantee: "post-NEXT, BC = n is a real TOS." Verified by ACs #2 / #3 / #4 / #12. The Story 11.3 comment block at `src/exception.asm:168-175` (which correctly described the **intended** behaviour but **incorrectly assumed** [SP] still held i*x's TOS-cell after xt's CALL clobbering) is rewritten to describe the actual mechanism: SP is restored to SP_safe (post-POP-BC), saved-BC at frame +2 is pushed back onto the data stack to repopulate the slot xt's CALLs may have clobbered, then BC = n. Acknowledge the prior comment's incorrect assumption inline ("Pre-Story-11.4.1 this comment claimed [SP] preserved i*x-TOS by the CATCH POP BC discipline; that claim was wrong — see Story 11.4 Note A").

16. **Given** NFR4 (per-epic kernel-ROM-footprint budget, `architecture.md:57`) and the Story 11.4 baseline of 17373 bytes, **when** Story 11.4.1 lands, **then** the binary delta is bounded: **CATCH** loses the saved-IX backfill (`PUSH IX / POP HL / LD (IX+2), L / LD (IX+3), H` = 7 bytes); **CATCH** also loses the pre-POP-BC `LD HL, 0 / ADD HL, SP` (4 bytes); **CATCH** gains the post-POP-BC capture `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` plus the saved-BC store `LD (IX+0), C / LD (IX+1), B` (≈ 9 bytes); **THROW caught path** gains `LD C, (IX-6) / LD B, (IX-5) / PUSH BC` (7 bytes). **Estimated net delta: +0 to +8 bytes**, well inside NFR4's epic-level slack. Pre/post `wc -c build/antforth.com` recorded in Completion Notes; investigate if delta exceeds ±15 bytes (likely cause: under-counted instruction-prefix or unexpected MACRO expansion).

17. **Given** the NFR4 cycle-cost rationale at `architecture.md:287` ("Total cycle cost for uncaught CATCH … well within NFR4's ~15-cycle budget"), **when** Story 11.4.1 lands, **then** the new CATCH frame-push sequence is re-counted (estimated: original ~95 t-states for the 8-byte push; new ~100 t-states — +5 t-states from the `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` idiom, less the saved-IX `PUSH IX / POP HL / LD (IX+2), L / LD (IX+3), H` removal). Net: **roughly cycle-neutral**; the NFR4 envelope is unchanged. Recorded in Completion Notes for the post-Story-11.7 retrospective.

18. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect") and Story 11.4's review yield (8 findings + 5 second-pass findings), **when** Story 11.4.1's review runs, **then** at least 2-3 HIGH/MEDIUM findings are expected. Likely candidates: (a) the `LD C, (IX-6) / LD B, (IX-5)` post-frame-pop read — what if a future edit interleaves an IX write between `ADD IX, BC` and the saved-BC read? Document the read-before-overwrite invariant inline. (b) the `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` SP-capture idiom — what if a future edit moves a PUSH into that window? Same kind of fragility as the original pre-POP-BC capture. (c) nested-CATCH coverage gaps — the AC #12 nested test only exercises ONE level of nesting; verify 3-level nested with i*x at each level. (d) THROW from non-colon IX frames (DO-LOOP, EXECUTE) with non-empty pre-CATCH stack — Story 11.3 review F3's analog. (e) the `+2` slot rename — every comment in the codebase that references "saved IX" in the exception-frame context must be re-checked (grep `saved.IX|saved-IX|\bsaved IX\b` across `src/*.asm`, `_bmad-output/**/*.md`, `docs/**/*.md`). (f) `architecture.md`'s implementation-pattern example at `:582-585` references the legacy 6-byte frame — re-check that this is example-only stale text, not load-bearing. Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale.

19. **Given** the verdict-table format from Story 11.3 / 11.4 (`feedback_plain_qa_language.md`), **when** Story 11.4.1 lands, **then** Completion Notes mirror that format: one row per AC, columns `Gate text | Evidence | Verdict`. State the value, the gate, and the reason plainly.

20. **Given** the post-Story-11.4 regression baseline (`make` / `make test` / `make test-repl` clean — 0 errors, 0 warnings, 726 PASS / 0 FAIL per Story 11.4 final), **when** Story 11.4.1 lands, **then** all three passes run clean; new tests appended at PASS ~727..(~727+12). Total PASS lines should rise to ~735-742 (assuming ~8-15 new tests covering the AC #1-#4 + #11 + #12 cases). **Critical regression check:** the existing 726 prior tests must continue to PASS — particularly the Story 11.4 caught-underflow + caught-divisor-zero tests at PASS 696..717 (which use empty pre-CATCH stacks; they were the only forms that exercised the THROW-caught path in Story 11.4 at all). Story 11.3's Section 7 colon-body-THROW tests (`1 2 3 ' T1 CATCH . . . .` → `42 3 2 1  ok`, etc.) currently pass by coincidence; post-fix they pass by design. Story 11.4 Note A is **closed** by the post-fix verification — update Story 11.4's Completion Notes verdict table from `PARTIAL` to `PASS` for ACs #9 / #11 / #12 (with a forward-pointer to this story).

## Tasks / Subtasks

- [x] **Task 1 — Verify the bug pre-edit; lock down baseline (AC: #1, #5, #9, #16, #20)**
  - [x] 1.1 `wc -c build/antforth.com` — record pre-edit baseline (expected 17373 bytes per Story 11.4 final).
  - [x] 1.2 Re-run the empirical evidence cases from Story 11.4 Note A: `printf "1 ' + CATCH . .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null` — confirm output matches `-4 1483` form (the i*x cell is **not** `1`). Capture exact output (the `1483`-equivalent kernel address may drift; the assertion is "not `1`"). Record in Debug Log References.
  - [x] 1.3 Run the spec-form tests: `printf "1 2 3 ' DROP CATCH . . . .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null` and observe the i*x cells are NOT `3 2 1`. Same for `1 2 3 ' DROP CATCH DEPTH .` (likely shows `1`, not `4`). Record exact pre-edit outputs.
  - [x] 1.4 `grep -nE 'IX\+2|IX\+3' src/exception.asm` — confirm only **two** matches (CATCH backfill writes at `:92-93`); no read site. This validates AC #5's "the +2 slot is dead code" claim.
  - [x] 1.5 `grep -rnE 'saved.IX|saved-IX|saved IX' src/*.asm _bmad-output/planning-artifacts/architecture.md _bmad-output/implementation-artifacts/11-*.md` — record every occurrence; these are AC #18(e) candidates for the post-fix sweep.

- [x] **Task 2 — Update CATCH frame-push to the new layout (AC: #5, #6, #7, #13, #14, #15, #17)**
  - [x] 2.1 Open `src/exception.asm` at `w_CATCH_cf:` (`:63-103`). Restructure the body in this order:
    1. `CALL check_underflow` (unchanged).
    2. `LD H, B / LD L, C` (move xt to HL — was after frame push, now before).
    3. `POP BC` (consume i*x's TOS into BC; SP advances to `SP_safe` — was after frame push, now before).
    4. `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` is the **wrong ordering** here — see clean idiom below.
    5. **Clean SP-capture idiom**: `PUSH HL` (stash xt), `LD HL, 2`, `ADD HL, SP` (HL = SP_safe = `current SP + 2` undoes the PUSH), then later `POP HL` (recover xt) **after** the frame is fully written.
    6. Push the 8-byte frame in the order: `+6 prev CATCH-TOP` (from `IY+catch_top`), `+4 catching-IP` (from DE), `+2 saved BC` (from BC, **NEW** — replaces the old saved-IX placeholder + backfill), `+0 saved SP` (from HL = SP_safe).
    7. After the four pairs of `DEC IX` + 16-bit store, IX = frame base. Set CATCH-TOP via `PUSH IX / POP HL / LD (IY+catch_top), L / LD (IY+catch_top+1), H`. (HL is now frame base, not SP_safe — but we already wrote SP_safe to frame +0, so it's safe to clobber.)
    8. `POP HL` recovers xt. `LD DE, catch_resume_thread`. `JP (HL)`.
  - [x] 2.2 Replace the file-header frame-layout block at `src/exception.asm:14-19` and the CATCH-docstring frame-layout block at `:41-46` with the new layout. The **single canonical** frame layout described in both blocks now reads:
    ```
    Frame layout (E11-D1, post-Story-11.4.1):
      +6: previous CATCH-TOP   (chain link)
      +4: catching-IP          (caller's IP at CATCH entry)
      +2: saved BC             (i*x's TOS-cell value at CATCH entry; restored
                                to data stack on THROW caught path)
      +0: saved SP             (parameter-stack pointer **after** the POP BC
                                that consumed xt → HL and i*x's TOS → BC.
                                This SP_safe value sits one cell above the
                                memory location that CATCH-entry's [SP] held
                                — see Story 11.4.1 root-cause analysis: any
                                CALL inside xt writes its return-address byte
                                at [SP_safe-2], never at [SP_safe]; the cell
                                at [SP_safe] is therefore preserved across xt,
                                and saved-BC at +2 is the value to restore at
                                [SP_safe-2] on THROW caught path.)
    ```
  - [x] 2.3 Add a comment block above the SP-capture site (at the new `PUSH HL / LD HL, 2 / ADD HL, SP` idiom) describing the why per AC #14:
    ```
    ; --- SP_safe capture: the saved-SP slot must hold the SP value AFTER
    ;     the POP BC consumed i*x's TOS into BC. Pre-Story-11.4.1 this
    ;     was captured BEFORE the POP — frame +0 then pointed at the
    ;     i*x's TOS-cell location, which xt's first CALL (typically
    ;     check_underflow) would clobber with its return-address byte.
    ;     THROW's `LD SP, HL` then landed on stale return-address data
    ;     instead of i*x's TOS. The post-Story-11.4.1 design captures
    ;     SP_safe = SP after POP BC; xt's CALLs write at [SP_safe - 2]
    ;     (never at SP_safe or above — Z80 PUSH/CALL discipline);
    ;     i*x's TOS-cell value lives in frame +2 instead of in memory
    ;     at [old SP].
    ;
    ; The PUSH HL / LD HL, 2 / ADD HL, SP / POP HL idiom is required
    ; because Z80 has no direct LD HL, SP — the canonical
    ; LD HL, 0 / ADD HL, SP would also work but only AT this point HL
    ; holds xt; we'd need to spill xt first. Equivalent total cycle
    ; cost; both forms are 4-instruction sequences.
    ; --------------------------------------------
    ```
  - [x] 2.4 Confirm at write time that the frame-push DEC IX count is **still 4 pairs (8 bytes)** — frame size is unchanged. The slot-content semantic at +2 is what changes.

- [x] **Task 3 — Update THROW caught path to restore i*x's TOS-cell from frame +2 (AC: #8, #14, #15, #18)**
  - [x] 3.1 Open `src/exception.asm` at `w_THROW_cf.kernel_entry:` (`:236-290`). The pre-edit caught path (from `LD (throw_saved_n), BC` through `LD BC, (throw_saved_n) / NEXT`) restructures to:
    1. `LD (throw_saved_n), BC` (stash n — unchanged).
    2. `PUSH HL / POP IX` (IX = target frame base — unchanged).
    3. Restore CATCH-TOP from +6 (unchanged).
    4. Read catching-IP (DE) from +4 (unchanged).
    5. Read saved-SP from +0 into HL (unchanged — but the value's semantic now is SP_safe, post-POP-BC, not pre-POP-BC).
    6. `LD BC, 8 / ADD IX, BC` to pop the frame (unchanged).
    7. **NEW**: `LD C, (IX-6) / LD B, (IX-5)` reads the saved-BC slot (now at IX-6 = old +2 location after IX-advance). Comment: "Read saved i*x's TOS-cell from the now-popped frame. Safe because no other writer touches IX-relative memory between ADD IX, BC and this read; the popped frame's bytes are stale-but-readable until something else writes to them. Per CCD-1, only CATCH and INCLUDE write to the IX rstack, and we hold the kernel until NEXT — no intermediate writer."
    8. `LD SP, HL` (restore SP_safe — same instruction, semantic now is "above the i*x's TOS-cell slot" not "at the i*x's TOS-cell slot").
    9. **NEW**: `PUSH BC` (restore i*x's TOS-cell to data stack at `[SP_safe - 2]` — overwrites whatever return-address garbage xt's CALLs may have left there).
    10. `LD BC, (throw_saved_n) / NEXT` (load THROW code into BC and continue — unchanged).
  - [x] 3.2 Rewrite the post-NEXT invariant comment block at `src/exception.asm:168-175` to describe the actual mechanism per AC #15:
    ```
    ; Post-NEXT invariant on the caught path: BC = n is a real TOS, not
    ; phantom (project_tos_in_register.md). At CATCH entry, BC held xt
    ; (TOS-in-register) and [SP] held i*x's TOS-cell. CATCH's POP BC
    ; consumed i*x's TOS into BC and CATCH's frame +2 captured BC as
    ; saved-BC. After the POP, SP = SP_safe (one cell above the
    ; original i*x's TOS-cell slot); CATCH stored SP_safe at frame +0.
    ;
    ; Pre-Story-11.4.1 (Story 11.4 Note A): saved-SP was captured
    ; BEFORE the POP BC, so frame +0 pointed at the memory cell that
    ; held i*x's TOS. xt's first CALL (typically check_underflow's
    ; entry CALL) wrote its return-address byte at THAT cell, clobbering
    ; the i*x's TOS value the THROW caught path expected to find via
    ; LD SP, HL. Post-Story-11.4.1: saved-SP is captured AFTER the POP
    ; (SP_safe = post-POP SP), and saved-BC at frame +2 holds the
    ; i*x's TOS-cell value separately. THROW's caught path:
    ;   LD SP, HL    (HL = SP_safe — points one cell above xt's
    ;                 CALL/PUSH territory; preserved across xt)
    ;   PUSH BC      (BC = saved-BC at this point — restores
    ;                 i*x's TOS-cell to [SP_safe - 2])
    ;   LD BC, n
    ;   NEXT
    ; DEPTH thus reports pre-CATCH-DEPTH (BC=n + K SP cells where K
    ; was the i*x cell count + xt = K+1 cells pre-CATCH; post-NEXT the
    ; xt is consumed leaving K SP cells + BC=n = K+1 = DEPTH).
    ```
  - [x] 3.3 Add a comment at the new `LD C, (IX-6) / LD B, (IX-5)` site explaining the IX-relative addressing into the popped frame:
    ```
    ; Read saved i*x's TOS-cell from the popped frame (now at IX-6
    ; relative to the post-add IX, since the frame's +2 slot was 6
    ; bytes below the pre-add IX = frame_base+8 - 6 = frame_base+2).
    ; Safe: the popped frame's memory is unwritten between ADD IX, BC
    ; and this read — only CATCH and INCLUDE write to the IX rstack
    ; (per CCD-1, architecture.md:166-191), and we hold the kernel
    ; until NEXT. FUTURE-EDIT NOTE: any new instruction inserted
    ; between ADD IX, BC and these two LDs that writes IX-relative
    ; memory would corrupt the saved-BC read.
    ```
  - [x] 3.4 Confirm `catch_resume_cf` (`src/exception.asm:127-151`) requires NO edits (per AC #9). The normal-return path doesn't read +2 — it just pops the 8-byte frame. Add a brief comment at the existing PUSH BC / LD BC, 8 / ADD IX, BC block noting "Story 11.4.1: the +2 slot's repurposing as saved-BC has zero effect here — normal-return path doesn't read the slot, just pops the 8-byte frame."

- [x] **Task 4 — Update architecture.md frame layout decision E11-D1 + E11-D2 (AC: #13)**
  - [x] 4.1 Open `_bmad-output/planning-artifacts/architecture.md` at `:270-279` (E11-D1 frame layout).
  - [x] 4.2 Replace the frame-layout code block (`:275-278`) with the new layout per AC #13 first bullet:
    ```
    +6: previous CATCH-TOP   (chain link — value of CATCH-TOP just before CATCH entered)
    +4: catching-IP          (where to resume after THROW)
    +2: saved BC             (i*x's TOS-cell value at CATCH entry — captured
                              from BC immediately after CATCH's POP BC. Restored
                              to the data stack on THROW caught path so the
                              i*x cells underneath the catching frame are
                              preserved across xt's CALL/RET clobbering of
                              memory at [SP_safe]. Pre-Story-11.4.1 this slot
                              was named "saved IX" but was unused — see Story
                              11.4.1 root-cause analysis.)
    +0: saved SP             (parameter stack pointer AFTER CATCH's POP BC —
                              i.e., one cell above the original i*x's TOS-cell
                              memory slot. Pre-Story-11.4.1 this was captured
                              BEFORE POP BC, leading to the bug that Story
                              11.4.1 fixes — see "i*x preservation under THROW"
                              note below E11-D2.)
    ```
  - [x] 4.3 Replace the CATCH-implementation step 1 at `:282`: the `saved IX = current IX (post-frame-push)` clause becomes `saved BC = i*x's TOS-cell value at CATCH entry (= BC immediately after POP BC)` and `saved SP = current SP` becomes `saved SP = current SP after POP BC (= SP_safe)`.
  - [x] 4.4 Replace the THROW caught-path step 3 at `:296`: "Restore SP and IX from the target exception frame; push the THROW code onto the parameter stack" amended to "Restore SP from the target exception frame's saved-SP slot (LD SP, HL where HL = saved-SP); push saved-BC from frame +2 onto the data stack to restore the i*x's TOS-cell that was captured at CATCH entry; then load BC = n (the THROW code)."
  - [x] 4.5 Append a new paragraph to E11-D2's rationale at `:300` describing the i*x preservation mechanism:
    ```
    **i*x preservation under THROW (Story 11.4.1):** The frame's saved-SP
    is captured AFTER CATCH's POP BC (which consumes xt → HL and i*x's
    TOS → BC). The cell at [old SP — pre-POP-BC] held i*x's TOS at CATCH
    entry; xt's CALLs write at [SP_safe - 2] (= [old SP]), clobbering
    the original i*x-TOS-cell memory. To preserve the value, frame +2
    holds saved-BC = the i*x-TOS-cell value, captured from BC immediately
    after the POP. THROW's caught path: LD SP, HL (HL = saved-SP =
    SP_safe); PUSH BC (where BC has been reloaded with saved-BC from
    the popped frame's +2 slot via LD C, (IX-6) / LD B, (IX-5));
    LD BC, n; NEXT. Result: BC = n (real TOS), [SP] = i*x's TOS-cell,
    [SP+2] = i*x's second-from-top, … [SP+2*(K-1)] = i*x's deepest,
    where K = the i*x cell count at CATCH entry. DEPTH = K + 1 =
    pre-CATCH-DEPTH (xt consumed, n on top instead).
    ```
  - [x] 4.6 No edit to CCD-1's "Exception frame: 8 bytes" row at `:176` — frame size is **unchanged**.

- [x] **Task 5 — Add tests for the four spec-form ACs + the smallest reproducer (AC: #10, #11, #12, #20)**
  - [x] 5.1 Open `tests/exception_tests.fth`. After Section 7's existing test `1 2 3 ' T1 CATCH . . . .` line (`:98`), add a comment block:
    ```
    \ --- Section 7.1: i*x preservation across colon-body THROW (Story 11.4.1) ---
    \ Pre-Story-11.4.1, this test passed by coincidence: T1's `LIT 42`
    \ pushes BC=3 to [SP-2]=[old SP], restoring the i*x's TOS-cell to
    \ its original memory location (with the same value). The CATCH
    \ frame layout treated [old SP] as the i*x-TOS-cell holder, which
    \ broke for any xt that did a CALL before any data-stack PUSH (e.g.,
    \ kernel primitives whose body started with CALL check_underflow_N).
    \ Story 11.4.1 redesigned the frame: +2 now holds saved-BC (= i*x's
    \ TOS-cell value), restored to data stack on THROW caught path.
    \ Post-fix, this test passes by design.
    ```
  - [x] 5.2 In `tests/exception_tests.fth` Section 8 (nested CATCH), append the AC #12 test:
    ```
    \ --- Section 8.1: i*x preservation under nested CATCH (Story 11.4.1 AC #12) ---
    : T84 -5 THROW ;
    : N84 ['] T84 CATCH ;
    1 2 ' N84 CATCH . . . .                 \ expect: 0 -5 2 1  ok
    \ Inner CATCH catches -5; outer CATCH normal-returns with 0; the
    \ pre-outer-CATCH i*x = (1, 2) is preserved underneath.
    ```
  - [x] 5.3 Open `tests/throw_migration_tests.fth`. After Section 1's existing tests (line 68), add a new sub-section:
    ```
    \ --- Section 1.1: i*x preservation under caught underflow (Story 11.4.1) ---
    \ The Story 11.4 i*x-PRESERVATION CAVEAT (file header) is REMOVED
    \ by Story 11.4.1 — these tests now pass.
    1 ' + CATCH . .                         \ expect: -4 1  ok    (smallest reproducer of Story 11.4 Note A)
    1 2 3 ' DROP CATCH . . . .              \ expect: -4 3 2 1  ok    (Story 11.4 AC #9 spec form)
    1 2 3 ' DROP CATCH DEPTH .              \ expect: 4  ok    (Story 11.4 AC #11 spec form)
    \ Two-arg consumer at depth 1: + tries to consume 2, depth is 1,
    \ check_underflow_2 trips, kernel-internal -4 THROW. Pre-fix this
    \ printed -4 then a kernel-address byte for the i*x cell.
    1 2 ' + CATCH . . .                     \ expect: -4 2 1  ok
    ```
  - [x] 5.4 In `tests/throw_migration_tests.fth` Section 2 (divisor zero), after line 110, add the AC #4 test:
    ```
    \ --- Section 2.1: i*x preservation under caught divisor-zero (Story 11.4.1 AC #4) ---
    : T241 1 0 / ;
    5 6 7 ' T241 CATCH DEPTH .              \ expect: 4  ok
    5 6 7 ' T241 CATCH . . . .              \ expect: -10 7 6 5  ok
    ```
  - [x] 5.5 Update the `tests/throw_migration_tests.fth` file-header caveat at lines 29-37 ("I*X PRESERVATION CAVEAT (Story 11.4 Completion-Notes Note A)…"). Replace with a closure note: "Story 11.4.1 closed this defect — the CATCH frame +2 slot now holds saved-BC (i*x's TOS-cell value); THROW's caught path restores it to the data stack via PUSH BC after LD SP, HL. Tests below assert the full spec form."
  - [x] 5.6 Update `tests/throw_migration_tests.fth` Section 1's `' DROP CATCH DEPTH .` test at line 59. The existing comment at `:56-58` reads "DEPTH itself pushes the depth, so it reads 1 and prints 1." That was the K=0 form. Add a sibling test for the K=3 case (already added in Task 5.3 line 3). The K=0 case stays at `1  ok` since pre-CATCH stack is empty (only xt) — post-POP SP_safe is sp_base+2; frame+2 is junk-from-above-stack; THROW restores SP=sp_base+2 then PUSH junk; final SP=sp_base, BC=-4. DEPTH=1. **No regression.**

- [x] **Task 6 — Append matching Makefile blocks for new tests (AC: #11, #20)**
  - [x] 6.1 Highest existing PASS test number per Story 11.4 final: 717 (per Story 11.4 Debug Log "post-Story-11.4: 726 PASS"). Verify with `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending.
  - [x] 6.2 For each new test in Tasks 5.2-5.4, add a Makefile block following the Story 11.3/11.4 pattern. Estimated count: ~8-12 new tests covering the AC #1 / #2 / #3 / #4 / #11 / #12 forms plus the supplementary `1 2 ' + CATCH . . .` / `5 6 7 ' T241 CATCH . . . .` and the nested-CATCH `1 2 ' N84 CATCH . . . .`.
  - [x] 6.3 Run `make test-repl` after Makefile update. Expected: 726 prior PASS + ~8-12 new = ~734-738 PASS, zero FAIL.

- [x] **Task 7 — Build, full regression, and binary-size delta (AC: #16, #17, #20)**
  - [x] 7.1 `make` — clean assemble, zero errors, zero warnings.
  - [x] 7.2 `wc -c build/antforth.com` post-edit. Pre-Story-11.4.1 baseline: 17373 bytes. Estimated post-Story-11.4.1: 17373..17381 (delta 0..+8 per AC #16). Record actual; investigate if delta exceeds ±15 bytes.
  - [x] 7.3 `make test` — assembly thread regression passes clean. Zero new assembly tests required (Epic 3+ rule).
  - [x] 7.4 `make test-repl` — confirm all tests PASS. Particularly verify:
    - Story 11.2 normal-return tests at PASS 653..684 — unchanged behaviour.
    - Story 11.3 caught/uncaught tests at PASS 685..695 — unchanged behaviour.
    - Story 11.4 caught-underflow + caught-divisor-zero tests at PASS 696..717 — unchanged behaviour (these all use empty pre-CATCH stacks; the fix is no-op for them by AC #16's saved-BC = junk semantic).
    - Story 11.4.1 new tests at PASS 718..(~727) — pass.
  - [x] 7.5 Reproduce the AC #1 / #2 / #3 / #4 spec forms one more time interactively to confirm the fix landed correctly:
    - `printf "1 ' + CATCH . .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE '\\-4 1  ok'` → expect a hit.
    - `printf "1 2 3 ' DROP CATCH . . . .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE '\\-4 3 2 1  ok'` → expect a hit.
    - `printf "1 2 3 ' DROP CATCH DEPTH .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE '4  ok'` → expect a hit.
    - `printf ": T 1 0 / ;\r\n5 6 7 ' T CATCH DEPTH .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE '4  ok'` → expect a hit.

- [x] **Task 8 — Sweep stale "saved IX" references in source comments + planning artifacts (AC: #13, #18(e))**
  - [x] 8.1 `grep -rnE 'saved.IX|saved-IX|\bsaved IX\b' src/*.asm _bmad-output/planning-artifacts/architecture.md _bmad-output/implementation-artifacts/11-*.md docs/`. For each hit (other than the architecture.md edit from Task 4 and the exception.asm edits from Tasks 2-3): determine if it's a real reference to the (now-defunct) saved-IX slot or a coincidental match (e.g., "saved IX" in a docstring about a different IX use). Update real references; leave coincidences.
  - [x] 8.2 Review `architecture.md:582-585` (the Implementation Patterns "6-byte exception frame per CCD-1 / E11-D1" example). This is example-only stale text from an earlier draft — confirm at edit time and update to "8-byte exception frame per E11-D1 (post-Story-11.4.1: +0 saved-SP, +2 saved-BC, +4 catching-IP, +6 prev-CATCH-TOP)" or strike the size-specific number entirely.
  - [x] 8.3 Confirm via re-grep that no remaining `saved.IX` or `saved-IX` references exist in load-bearing context.

- [x] **Task 9 — Update Story 11.4's deferred ACs (AC: #20)**
  - [x] 9.1 Open `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md`. The verdict-table row for AC #9 (currently "**PARTIAL** (i\\*x preservation sub-claim deferred to Story 11.4.1)") flips to "**PASS** (i\\*x preservation sub-claim closed by Story 11.4.1 — see 11-4-1-catch-throw-ix-preservation-bug-fix.md)". Same for AC #11 and AC #12.
  - [x] 9.2 Note A's "Forward action" line currently says "Forward action (completed in code-review pass): … dedicated bug story 11-4-1-catch-throw-ix-preservation-bug-fix added at sprint-status.yaml:152 (status backlog) with a hard ordering constraint to land before Story 11.7's ABORT-retarget." Append: "Closed 2026-04-2X by Story 11.4.1 landing — see that story's Completion Notes for the redesign details."
  - [x] 9.3 Re-run the empirical evidence cases recorded in Note A (`1 ' + CATCH . .` and `1 ' DROP CATCH . .`) against the post-fix binary; confirm both now produce the spec-form output. Append the post-fix outputs to Story 11.4's Note A as the closure evidence.

- [x] **Task 10 — Code review (AC: #18, all)**
  - [x] 10.1 Run adversarial code review via `bmad-bmm-code-review` skill (or fresh `general-purpose` Agent). Per `feedback_adversarial_review.md`: a clean review is suspect — expect ≥2-3 HIGH/MEDIUM findings (likely candidates listed in AC #18).
  - [x] 10.2 Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale. Mirror Story 11.3 / 11.4 review-log discipline.
  - [x] 10.3 Post-review-fix `make` / `make test` / `make test-repl`: confirm no regressions; binary delta within ±5 bytes of pre-review post-fix figure.
  - [x] 10.4 Record review log in Completion Notes per Story 11.3 / 11.4 format: `ID / Severity / Category / Description / Resolution` columns.

- [x] **Task 11 — Update sprint status and finalize (AC: #19, #20)**
  - [x] 11.1 Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `11-4-1-catch-throw-ix-preservation-bug-fix: backlog` → `ready-for-dev` (the create-story flip; the dev pass moves it to `in-progress` then `review` → `done`).
  - [x] 11.2 Set `Status:` field at the top of this story file to `ready-for-dev` upon initial creation. Dev pass updates through the lifecycle.
  - [x] 11.3 After dev pass completes (post-review, status `done`), remove the multi-line "Known defect" comment block at `sprint-status.yaml:120-132` (above the `11-4-…` row). The defect is closed; the comment becomes stale. Leave the `11-4-1-…` row's tracking comment at `:140-148` until the row itself moves to `done` to preserve the audit trail.

## Dev Notes

### Mission and shape of this story

This story is a **structural bug fix** in the Story 11.2 CATCH frame design. It sits between Story 11.4 (just landed in `review`) and Story 11.5 (compiler/dictionary migration), with a hard ordering constraint to land before Story 11.7's ABORT-retarget (`sprint-status.yaml:139-152`).

What this story lands:
- A redesigned 8-byte exception frame: `+2` slot's semantic flips from "saved IX (dead — unused)" to "saved BC (i*x's TOS-cell value at CATCH entry)". Frame size unchanged.
- CATCH captures saved-SP **after** `POP BC` (post-POP SP_safe), not before (pre-POP SP-at-CATCH-entry). Stores i*x's TOS-cell into frame +2 at the same time.
- THROW's caught path reads saved-BC from the popped frame, then `LD SP, HL ; PUSH BC ; LD BC, (throw_saved_n) ; NEXT` to restore the i*x's TOS-cell to data stack at `[SP_safe - 2]` and put the THROW code in BC.
- `architecture.md` E11-D1 frame layout updated; E11-D2 caught-path step 3 amended to describe the saved-BC restore.
- New tests in `tests/exception_tests.fth` and `tests/throw_migration_tests.fth` covering the four Story 11.4 deferred AC spec forms (#9, #11, #12) plus the AC #1 smallest reproducer + nested-CATCH-with-i*x.
- Story 11.4's Note A closed; verdict-table flips from PARTIAL to PASS for ACs #9 / #11 / #12.

What this story explicitly does **NOT** land:
- No new THROW codes or migration of additional ABORT sites (Story 11.5 / 11.6 own those).
- No retarget of `ABORT` / `ABORT"` (Story 11.7 owns).
- No change to frame size (still 8 bytes; only the +2 slot semantic flips).
- No change to CCD-1 dual-chain discipline (CATCH-TOP chain unchanged).
- No change to `catch_resume_cf` body (the normal-return path doesn't read +2; +2's repurposing has zero effect on it).
- No change to NFR4 cycle budget (estimated ~5 t-state delta; cycle-neutral within budget slack).

### Bug analysis (the canonical trace)

Pre-Story-11.4.1 trace for `1 ' + CATCH . .`:
1. After `1 ' +` — pre-CATCH state: `BC = xt(+)`, `SP = sp_base-2`, `[sp_base-2] = 1`. DEPTH = 2.
2. CATCH entry:
   - `CALL check_underflow` (passes; depth ≥ 1).
   - `LD HL, 0 / ADD HL, SP` — HL = `sp_base-2` (SP at CATCH entry). **(BUG: captures pre-POP-BC SP.)**
   - Frame push: `+0 = HL = sp_base-2`; `+2..+6` filled.
   - `LD H, B / LD L, C` — HL = xt(+).
   - `POP BC` — BC = `[sp_base-2] = 1`; SP advances to `sp_base`.
   - `JP (HL)` — execute `+`.
3. `+` body: `CALL check_underflow_2`.
   - CALL decrements SP to `sp_base-2`, writes return-address byte at `[sp_base-2]`. **CLOBBERS the cell that held 1 (the i*x's TOS).**
   - `check_underflow_2` body: depth = (sp_base - (sp_base-2))/2 + (BC valid? 1 : 0). With BC = 1 (valid TOS), depth would be 1+1=2. But the check requires depth ≥ 2 with TWO more cells under TOS — actually the implementation at `src/system.asm:485-497` checks `sp_base - SP_measured ≥ 6` (2 for ret-addr + 4 for two cells). With SP = `sp_base-2` post-CALL, `sp_base - (sp_base-2) = 2`, not ≥ 6. **Underflow.**
   - JPs to `do_underflow_error`. Per Story 11.4: `LD BC, -4 / JP w_THROW_cf.kernel_entry`.
4. THROW kernel_entry caught path:
   - `LD (throw_saved_n), BC` — stash -4.
   - Read CATCH-TOP, walk to target frame (frame base from CATCH).
   - Read frame +0 = `sp_base-2` into HL.
   - Pop 8-byte frame.
   - `LD SP, HL` — SP = `sp_base-2`. **[sp_base-2] now holds the return-address byte, NOT the i*x's TOS-cell value 1.**
   - `LD BC, (throw_saved_n)` — BC = -4.
   - NEXT.
5. Post-THROW state: BC = -4 (correct), `[SP] = [sp_base-2] = ret-addr-byte (e.g., 0x05CB or similar)`. `. .` prints `-4` then the ret-addr-byte interpreted as a 16-bit decimal (`1483` in Story 11.4 evidence).

Post-Story-11.4.1 trace for the same incantation:
1. Pre-CATCH state: same.
2. CATCH entry:
   - `CALL check_underflow` (unchanged).
   - `LD H, B / LD L, C` — HL = xt(+).
   - `POP BC` — BC = `[sp_base-2] = 1`; SP advances to `sp_base = SP_safe`. **(POP happens BEFORE SP capture.)**
   - `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` — HL captures `SP_safe = sp_base`. (POP HL recovers xt at the end.)
   - Frame push: `+0 = SP_safe = sp_base`; `+2 = BC = 1` (saved i*x's TOS-cell); `+4 = DE` (catching IP); `+6 = prev CATCH-TOP`.
   - Update CATCH-TOP, restore HL = xt, `LD DE, catch_resume_thread`, `JP (HL)`.
3. `+` body: `CALL check_underflow_2`.
   - CALL decrements SP to `sp_base-2`, writes return-address byte at `[sp_base-2]`. **(Still clobbers — but [sp_base-2] is now BELOW SP_safe; xt's writes at-or-below-SP were always going to live there.)**
   - Same underflow as before; same THROW -4 fires.
4. THROW kernel_entry caught path:
   - Stash n = -4.
   - Read frame +0 = `sp_base = SP_safe` into HL.
   - Pop 8-byte frame: `LD BC, 8 / ADD IX, BC`.
   - **NEW:** `LD C, (IX-6) / LD B, (IX-5)` — BC = saved-BC = 1 (the i*x's TOS-cell value).
   - `LD SP, HL` — SP = `sp_base = SP_safe`.
   - **NEW:** `PUSH BC` — writes BC = 1 to `[sp_base-2]`; SP = `sp_base-2`. **(Restores i*x's TOS-cell to its expected memory slot; overwrites the return-address-byte garbage left by xt.)**
   - `LD BC, (throw_saved_n)` — BC = -4.
   - NEXT.
5. Post-THROW state: BC = -4 (correct), `[SP=sp_base-2] = 1` (correct). `. .` prints `-4 1`. **Spec form satisfied.**

### Architecture references

- **CCD-1 — Return-stack frame taxonomy + dual-chain discipline:** `architecture.md:166-191`. Frame size for the exception frame stays at 8 bytes — no change to the table row at `:176`. Chain discipline (`CATCH-TOP` / `INCLUDE-TOP`) unchanged.
- **CCD-3 — Standards-citation discipline:** `architecture.md:206-216`. The new comment block at the SP-capture-after-POP-BC site carries an inline reference to the bug origin (Story 11.4 Note A); the THROW caught-path comment block is rewritten to describe the actual mechanism per AC #15.
- **E11-D1 — Exception frame layout:** `architecture.md:270-279`. **Edited by this story:** +2 slot's semantic flips from "saved IX" to "saved BC"; +0 slot's capture-time-of-SP flips from pre-POP-BC to post-POP-BC. Size unchanged.
- **E11-D2 — CATCH/THROW mechanism:** `architecture.md:289-300`. **Edited by this story:** caught-path step 3 amended to describe the saved-BC restore; new "i*x preservation under THROW" rationale paragraph appended.
- **NFR4 — kernel-ROM-footprint budget:** `architecture.md:57`. Estimated +0 to +8 byte delta; no change to per-epic envelope.
- **Source-file organisation:** `architecture.md:434-447`. Story 11.4.1 edits `src/exception.asm` (the kernel CATCH/THROW), the architecture spec (`_bmad-output/planning-artifacts/architecture.md`), the test files (`tests/exception_tests.fth`, `tests/throw_migration_tests.fth`), and `Makefile` (test-block append). No edits to `src/system.asm` (Story 11.4's `do_underflow_error` migration is unaffected — it just `JP w_THROW_cf.kernel_entry` with `BC=-4` and the kernel_entry's caught-path now correctly preserves i*x).

### Constraints and conventions

- **Standards-compliance discipline** (`feedback_standards_compliance.md`): the bug violated the spirit of ANS Forth 1994 §6.1.0875 / §9.6.1.0875 (the `( i*x xt -- j*x 0 | i*x n )` stack effect). The fix restores it. No new standards citations needed; the existing CATCH/THROW citations at `src/exception.asm` already cover §9.6.1.0875 and §9.6.1.2275.
- **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use the Story 11.3 / 11.4 verdict-table format. State the value, the gate, the reason — plainly.
- **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): the Story 11.3 post-NEXT invariant ("BC = n is a real TOS") is restored to validity by this fix. DEPTH = pre-CATCH-DEPTH for the THROW-caught path with non-empty pre-CATCH stack.
- **REPL tests preferred** (`feedback_repl_tests_preferred.md`): all Story 11.4.1 tests are REPL-piped Forth lines, with corresponding Makefile entries. **No new assembly test threads.**
- **Adversarial review** (`feedback_adversarial_review.md`): expect ≥ 2-3 HIGH/MEDIUM findings per AC #18.
- **Follow the process** (`feedback_follow_process.md`): Tasks 1-11 form the standard create-story → dev-story → code-review → finalize workflow. Don't ask permission for the next sub-task; just execute.
- **Design upfront** (`feedback_design_upfront.md`): the new frame layout is designed for ALL future caught-path THROWs, not just Story 11.4's two THROW codes. Stories 11.5 / 11.6 / 11.7 inherit the fix transparently — no per-story re-touch.
- **Standards compliance — investigate before defending** (`feedback_standards_compliance.md`): the project lead flagged Story 11.4's Note A as a structural defect requiring redesign, not a documentation deferral. This story is the redesign.

### Implementation pitfalls

1. **The SP-capture order MUST be: `POP BC` first, then capture SP_safe.** Inverting this re-introduces the bug. Document the order rule explicitly in the comment block above the SP-capture site (Task 2.3).

2. **The saved-BC slot at +2 MUST be written from BC immediately after `POP BC`.** If a future edit inserts code between the POP and the saved-BC store that clobbers BC (e.g., `LD BC, 0` for some unrelated init), the saved-BC slot would hold garbage. Defensive option: explicitly tag the BC-clobber-free zone in the comment block.

3. **The `LD C, (IX-6) / LD B, (IX-5)` post-frame-pop read MUST happen between `ADD IX, BC` (which moves IX past the popped frame) and any subsequent IX-relative write.** Document the ordering invariant in the comment block at the read site (Task 3.3).

4. **`PUSH BC` after `LD SP, HL` overwrites `[SP_safe - 2]`.** If `[SP_safe - 2]` happens to hold something the user cares about (it shouldn't — by construction xt's CALLs/PUSHes are the only thing that wrote there during xt execution), it's overwritten. This is by design: we're restoring i*x's TOS to its proper slot.

5. **The `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` SP-capture idiom assumes that no instruction between the `PUSH HL` and the matching `POP HL` shifts SP independently.** Specifically, between the PUSH and the POP, the only allowed SP-changing operations are: the IX manipulations (which don't touch SP), and the IY-relative reads (which don't touch SP). DO NOT insert any system-stack PUSH/POP between these two — the recovery offset of `2` would be wrong.

6. **The `+2` slot rename (saved-IX → saved-BC) is a cross-cutting edit.** Every comment, docstring, design-doc reference, and architecture-spec line that names the slot must update in lockstep (Task 8 sweep). A stale "saved IX" reference in `architecture.md` or `_bmad-output/implementation-artifacts/11-2-…md` would mislead future developers.

7. **Architecture-doc consistency: `architecture.md:582-585` (Implementation Patterns example) currently references a 6-byte exception frame.** This is **stale** from an earlier draft (pre-CCD-1 redesign per Finding 1 at `:902` says "E11-D1 exception frame expanded to 8 bytes"). Confirm this at edit time; the size change to 6→8 was Story 11.2's prerequisite, not Story 11.4.1's. If the line still says 6 bytes, it's a leftover stale ref unrelated to this story — fix in Task 8.2.

8. **Don't touch `catch_resume_cf` (the normal-return path).** It pops the 8-byte frame and goes about its business. The +2 slot's repurposing has ZERO effect on it. Task 3.4 confirms this with a brief comment, but no behavioural change.

9. **Don't touch `do_underflow_error` (Story 11.4's `src/system.asm:565-568`).** It calls `JP w_THROW_cf.kernel_entry` with `BC = -4`. The kernel_entry's caught path is what changes — `do_underflow_error` continues to work transparently.

10. **The DEPTH-invariant tests verify K cells preserved, not K+1.** The xt is consumed; the THROW code replaces it; net depth change is zero (xt out, n in). For `1 2 3 ' DROP CATCH DEPTH`, pre-CATCH DEPTH = 4 (1, 2, 3, xt), post-THROW DEPTH = 4 (1, 2, 3, -4). DEPTH word pushes 4. `.` prints 4. ✓

11. **Empty pre-CATCH stack tests still pass.** When K=0 (no i*x cells), the saved-BC slot at +2 holds junk-from-above-stack (whatever was at `[sp_base]` at CATCH entry). On THROW, `PUSH BC` pushes that junk to `[sp_base-2]`, then `LD BC, n / NEXT`. Final BC = n, [SP] = junk, but DEPTH = 1 (just BC). The junk at [SP] is irrelevant because no `.` would read it (DEPTH = 1 means nothing under TOS). All Story 11.4 caught tests use K=0; they continue to pass.

12. **Colon-body THROW tests `1 2 3 ' T1 CATCH . . . .` (Story 11.3 Section 7) pass pre-fix by coincidence (LIT 42's PUSH BC restores i*x's TOS to [old SP] before THROW reads it) and post-fix by design (saved-BC at +2 is restored regardless of LIT push patterns).** The Section 7 comment update in Task 5.1 documents the fragility removal.

13. **Nested CATCH preserves i*x at each frame level independently.** The outer CATCH's frame +2 holds outer's i*x's TOS-cell; the inner CATCH's frame +2 holds inner's. THROW unwinds to a specific frame (target = `CATCH-TOP` at THROW time); only that frame's +2 is consumed via the `LD C, (IX-6) / LD B, (IX-5) / PUSH BC` sequence. Frames above (= older nesting layers) keep their +2 intact for any future THROW that targets them.

### Test discipline

- Tests live in `tests/exception_tests.fth` (Story 11.4.1 adds Section 7.1 + Section 8.1) and `tests/throw_migration_tests.fth` (Story 11.4.1 adds Section 1.1 + Section 2.1).
- Counterpart `printf | $(IZCPM)` blocks land in `Makefile` starting at PASS test 718 (post-Story-11.4 highest = 717 per Debug Log; verify before append).
- For caught-THROW round-trip i*x-preservation tests: assert the THROW code AND each i*x cell appears as expected.
- For DEPTH-invariant tests: use `' WORD CATCH DEPTH .` form — DEPTH pushes the depth, `.` prints it; DEPTH = pre-CATCH-DEPTH.
- For nested-CATCH tests: structure as a colon definition that wraps another colon definition's CATCH; outer CATCH catches if inner doesn't, etc. Stack-effect annotation on each colon definition for readability.
- For the smallest-reproducer test (AC #1, `1 ' + CATCH . .`): use the exact form from Story 11.4 Note A's empirical evidence.

### Project Structure Notes

- **Edits:**
  - `src/exception.asm` — restructure CATCH frame-push (Task 2); restructure THROW caught path (Task 3); rewrite the file-header and CATCH-docstring frame-layout blocks (Task 2.2). Estimated growth: ~10 source lines net (some additions, some deletions per Tasks 2.1 / 3.1).
  - `_bmad-output/planning-artifacts/architecture.md` — update E11-D1 frame layout (`:275-282`); update E11-D2 caught-path step 3 + new rationale paragraph (`:296-300`). Estimated growth: ~10-15 source lines.
  - `tests/exception_tests.fth` — add Section 7.1 i*x preservation note (~6 lines); add Section 8.1 nested-CATCH-with-i*x test (~5 lines). Total: ~12 new lines.
  - `tests/throw_migration_tests.fth` — add Section 1.1 i*x preservation under caught underflow (~8 lines); add Section 2.1 i*x preservation under caught divisor-zero (~5 lines); update file-header CAVEAT (Task 5.5, ~10 lines edited). Total: ~15 net new lines.
  - `Makefile` — append PASS test blocks 718..(~727). Estimated: ~50-80 new lines (per Story 11.3 / 11.4 block-pattern length).
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-4-1-…: backlog` → `ready-for-dev`. Optional cleanup: remove the multi-line "Known defect" comment block at `:120-132` after the dev pass completes (Task 11.3).
  - `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — Story 11.4 verdict-table flips for ACs #9 / #11 / #12; Note A "Forward action" line gets a closure date (Task 9).
  - `_bmad-output/implementation-artifacts/11-4-1-catch-throw-ix-preservation-bug-fix.md` — this file (Status, task checkboxes, Completion Notes, File List, Change Log on dev pass).
- **No new files.** All edits land in existing files.
- File-list expectation in Dev Agent Record: 1 modified `src/*.asm` file (`exception.asm`) + 1 modified architecture spec + 2 modified test files + Makefile + sprint-status + Story 11.4 file + this story file.

### Previous-story intelligence (Story 11.4 patterns to reuse)

**Reuse from Story 11.4:**
- *Verdict-table Completion Notes* (Story 11.3 / 11.4): one row per AC, columns `Gate text | Evidence | Verdict`. Mirror exactly.
- *Per-task evidence sections with explicit grep / wc commands*: "ran command X, got output Y, here's the implication" — no hand-waving.
- *Re-grep before publishing*: every line number cited in Dev Notes (e.g., `src/exception.asm:236-290`) re-verified at dev-pass time.
- *Adversarial-review-finding triage table*: review-log format (`ID / Severity / Category / Description / Resolution` columns) replicated in Completion Notes.
- *Binary-size delta table*: Stage / bytes / delta, mirroring Story 11.3 / 11.4 Completion Notes.
- *EXX-hygiene comments at kernel-entry contracts*: irrelevant here (the bug is on the data-stack side, not register-set side; no EXX activity inside CATCH/THROW). But the existing EXX commentary at `src/exception.asm:217-221` stays put.

**Pitfalls Story 11.4's review surfaced (avoid in 11.4.1):**
- *F1: framing about post-NEXT staleness was misleading* — write comments about register / stack state in terms of the actual TOS-in-register convention. Story 11.4.1's rewrite of the post-NEXT-invariant comment (Task 3.2) directly addresses this — describe the ACTUAL mechanism (saved-BC restore via PUSH BC), not the buggy intended behaviour.
- *F2: missing edge-case test for BC = 0x8000* — irrelevant here; Story 11.4.1 doesn't touch the divisor-zero guards.
- *F3: missing tests for non-colon IX frames (DO-LOOP, EXECUTE)* — Story 11.4.1 adds at least one DO-LOOP-frame i*x preservation test (or notes that Story 11.4 / 11.3 already cover the IX-snap-back semantic and this story adds the data-stack-i*x preservation orthogonally).
- *R-M2: stale `\\ expect: ...` reference comments* — Story 11.4.1's only edit to existing test files is the Section 7 / 7.1 comment update + Section 1's CAVEAT removal. No bulk regex edits like Story 11.4's 58-occurrence sweep.
- *R-M3: docs not updated alongside code* — Task 4 + Task 8 ensure architecture.md and the source-file frame-layout comments update in lockstep with the code change.
- *R-M5: Debug Log inaccuracy* — be exact about the prose-comment-vs-instruction match counts on `grep -nE 'JP\\s+w_ABORT_cf|DW\\s+w_ABORT_cf'` — Story 11.4.1 shouldn't change this count (the kernel-internal THROW path's `JP w_ABORT_cf` at `src/exception.asm:322` is unchanged).

### Comparison to Story 11.4's adversarial review F-findings (Story 11.4.1 watch-list)

Story 11.4 yielded 2 HIGH, 4 MEDIUM, 2 LOW findings on first pass + 1 HIGH, 4 MEDIUM, 1 LOW on the code-review pass. Story 11.4.1 deliberately watches for these analogous issues:
- **Future-edit hazard at the `LD C, (IX-6) / LD B, (IX-5)` post-pop read** (analog of F2 future-edit-hazard): document the read-before-overwrite invariant inline (Task 3.3).
- **Nested-CATCH coverage gaps** (analog of F3 missing-edge-case): include at least one nested-CATCH-with-i*x test (Task 5.2) plus a 3-level-nested test if time permits.
- **Stale "saved IX" references in source comments / docs** (analog of R-M2 stale-comments-sweep): Task 8 sweep across `src/`, `_bmad-output/`, `docs/`.
- **Architecture-doc consistency** (analog of R-M3 docs-not-updated): Task 4 (architecture.md edits) + Task 8.2 (Implementation Patterns example check).
- **Cycle-cost regression** (analog of R-L1 / NFR4 audit): Task 7's wc -c + the Completion Notes cycle-count estimate (Task 17 AC).
- **Story 11.4 Note A closure** (analog of R-H1 verdict-table-accuracy): Task 9 flips Story 11.4's ACs #9 / #11 / #12 to PASS with forward-pointer; Note A's "Forward action" gets a closure date.

### References

- `_bmad-output/planning-artifacts/architecture.md:166-191` — CCD-1 dual-chain discipline (frame size unchanged at 8 bytes per `:176`).
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline.
- `_bmad-output/planning-artifacts/architecture.md:270-279` — E11-D1 exception frame layout (Story 11.4.1 edits the +2 / +0 slot semantics).
- `_bmad-output/planning-artifacts/architecture.md:289-300` — E11-D2 CATCH/THROW mechanism (Story 11.4.1 edits caught-path step 3).
- `_bmad-output/planning-artifacts/architecture.md:302-306` — E11-D3 internal-error migration strategy (this story is a bug-fix interlude in the crawl, not a new migration).
- `_bmad-output/planning-artifacts/architecture.md:434-447` — source-file organisation.
- `_bmad-output/planning-artifacts/architecture.md:582-585` — Implementation Patterns 6-byte exception frame example (stale; Task 8.2 fixes).
- `_bmad-output/planning-artifacts/prd.md:392-402` — FR15-FR22 (Epic 11 functional requirements).
- `_bmad-output/planning-artifacts/prd.md:455-463` — NFR3, NFR6, NFR7 (CATCH/THROW perf + REPL survivability + state integrity).
- `_bmad-output/implementation-artifacts/11-2-exception-frame-infrastructure-and-catch-word.md` — Story 11.2's CATCH frame design (the design with the latent bug).
- `_bmad-output/implementation-artifacts/11-3-throw-word-and-uncaught-throw-repl-handler.md` — Story 11.3's THROW + uncaught handler.
- `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — Story 11.4 (Note A surfaced the bug; ACs #9 / #11 / #12 verdict-table flips on Task 9).
- `_bmad-output/implementation-artifacts/sprint-status.yaml:120-152` — defect tracking comment block + 11-4-1 row with hard ordering constraint.
- `src/exception.asm:14-19` — file-header frame-layout block (Task 2.2 update).
- `src/exception.asm:41-46` — CATCH-docstring frame-layout block (Task 2.2 update).
- `src/exception.asm:63-103` — `w_CATCH_cf` body (Task 2 restructure).
- `src/exception.asm:127-151` — `catch_resume_cf` body (NO edit; Task 3.4 confirms with comment).
- `src/exception.asm:168-175` — post-NEXT invariant comment block (Task 3.2 rewrite).
- `src/exception.asm:236-290` — `w_THROW_cf.kernel_entry` body (Task 3 restructure).
- `src/system.asm:460-547` — `check_underflow{,_2,_3,_4}` (NOT edited by this story; the CALL pattern is what triggers the bug, but the helpers themselves are correct).
- `src/system.asm:565-568` — `do_underflow_error` (Story 11.4's migration; NOT edited by this story).
- `tests/exception_tests.fth` — Story 11.2 / 11.3 tests (Story 11.4.1 adds Section 7.1 + 8.1).
- `tests/throw_migration_tests.fth` — Story 11.4 tests (Story 11.4.1 adds Section 1.1 + 2.1; updates file-header CAVEAT).
- `Makefile` — REPL test blocks (Story 11.4.1 appends 718..(~727)).
- DPANS94 §6.1.0875 / §9.6.1.0875 — `CATCH` stack effect `( i*x xt -- j*x 0 | i*x n )` — the spec the bug violates.
- DPANS94 §6.1.2275 / §9.6.1.2275 — `THROW` stack effect — unchanged by this fix.
- `feedback_adversarial_review.md` — review discipline.
- `feedback_plain_qa_language.md` — Completion Notes verdict-table format.
- `feedback_repl_tests_preferred.md` — test-form rule (Forth REPL scripts, no assembly threads).
- `feedback_standards_compliance.md` — investigate the standard before defending code; project lead's defect flag is non-negotiable.
- `feedback_design_upfront.md` — frame redesign is for ALL future caught-path THROWs, not just Story 11.4's two codes.
- `project_tos_in_register.md` — TOS-in-register & DEPTH discipline (post-NEXT invariant restored).

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

| Stage | Command | Output / Evidence |
|-------|---------|-------------------|
| Pre-edit binary baseline (Task 1.1) | `wc -c build/antforth.com` | `17373 build/antforth.com` |
| Pre-edit smallest reproducer (Task 1.2) | `printf "1 ' + CATCH . .\r\nBYE\r\n" \| iz-cpm build/antforth.com` | `-4 1483  ok` (i*x's TOS-cell `1` clobbered; `1483` is a code-side return-address byte) |
| Pre-edit AC #2 spec form (Task 1.3) | `printf "1 2 3 ' DROP CATCH . . . .\r\nBYE\r\n" \| iz-cpm` | `0 2 1 error -4: stack underflow` — DROP did NOT underflow with 3 i*x cells (AC #2's literal trace was wrong; 2OVER substituted as the underflow-correct test xt) |
| Pre-edit AC #3 DEPTH form (Task 1.3) | `printf "1 2 3 ' DROP CATCH DEPTH .\r\nBYE\r\n" \| iz-cpm` | `3  ok` — DROP succeeded, returned 0 success, depth = 3 ([1, 2, 0]) |
| Pre-edit AC #4 divisor-zero form (Task 1.3) | `printf ": T 1 0 / ;\r\n5 6 7 ' T CATCH DEPTH .\r\nBYE\r\n" \| iz-cpm` | `4  ok` — divisor-zero THROW fired correctly, depth=4 (this AC's literal form already worked because the inner T uses an internal LIT push that coincidentally repopulated [SP] before THROW ran, similar to Story 11.3's Section 7 colon-body-THROW coincidence) |
| Pre-edit dead-code confirmation (Task 1.4) | `grep -nE 'IX\+2\|IX\+3' src/exception.asm` | 2 hits at `:92-93` (CATCH backfill writes); 0 read sites — confirms +2 was dead code |
| Pre-edit highest PASS test (Task 6.1) | `grep -oE 'PASS: REPL test [0-9]+' Makefile \| awk '{print $4}' \| sort -n -u \| tail -1` | `717` |
| Post-edit binary (Task 7.2) | `wc -c build/antforth.com` | `17382 build/antforth.com` (+9 bytes; AC #16 estimated +0..+8, slightly over but well within ±15-byte investigate threshold) |
| Post-edit `make` (Task 7.1) | `make` | `Errors: 0, warnings: 0, compiled: 22879 lines` |
| Post-edit `make test` (Task 7.3) | `make test` | `PASS: Output matches expected` |
| Post-edit `make test-repl` (Task 7.4) | `make test-repl \| grep -cE "^PASS:"` / `^FAIL:` | `735 PASS / 0 FAIL` (was 726; +9 new tests at 718-726) |
| Post-edit smallest reproducer (Task 7.5) | `printf "1 ' + CATCH . .\r\nBYE\r\n" \| iz-cpm` | `-4 1  ok` ✓ |
| Post-edit AC #2 spec form (Task 7.5; 2OVER substitute) | `printf "1 2 3 ' 2OVER CATCH . . . .\r\nBYE\r\n" \| iz-cpm` | `-4 3 2 1  ok` ✓ |
| Post-edit AC #3 DEPTH form (Task 7.5; 2OVER substitute) | `printf "1 2 3 ' 2OVER CATCH DEPTH .\r\nBYE\r\n" \| iz-cpm` | `4  ok` ✓ |
| Post-edit AC #4 divisor-zero (Task 7.5) | `printf ": T 1 0 / ;\r\n5 6 7 ' T CATCH DEPTH .\r\nBYE\r\n" \| iz-cpm` | `4  ok` ✓ |
| Post-edit `saved IX` sweep (Task 8.1, 8.3) | `grep -rnE 'saved.IX\|saved-IX\|\bsaved IX\b' src/exception.asm _bmad-output/planning-artifacts/architecture.md docs/register-conventions.md` | 3 hits — all are paragraph text that explains the rename (historical context); no load-bearing stale references remain. (Story 11.2 / 11.3 implementation-artifact files have historical refs — left intact per BMAD discipline; review F3 caught a missed `epics.md:737` ref which was fixed in-pass.) |

### AC trace correction (AC #2 / AC #3 — DROP does not underflow)

Discovered during Task 1 baseline capture: AC #2's spec form `1 2 3 ' DROP CATCH . . . .` → `-4 3 2 1  ok` is **unsatisfiable as written**. With 3 i*x cells, CATCH's POP BC leaves DROP at depth=3 (BC + 2 SP cells); DROP's `check_underflow_1` requires only 1 SP cell, so DROP succeeds, consumes one i*x cell, and CATCH normal-returns with code 0. Pre-fix and post-fix both produce `0 2 1 error -4: stack underflow` (the 4 dots underflow on the 4th).

Same problem for AC #3's `1 2 3 ' DROP CATCH DEPTH .` → `4  ok`: DROP succeeds, post-CATCH stack is `[1, 2, 0]`, DEPTH=3, prints `3`.

**Substitution:** the test forms preserve AC #2/#3's *intent* (assert i*x cells preserved underneath caught -4 THROW with 3 pre-CATCH i*x cells) using `2OVER` (which calls `check_underflow_4`, requiring 4 SP cells; with 3 i*x cells post-POP, depth=3, fails → -4 THROW). Pre-fix `1 2 3 ' 2OVER CATCH . . . .` → `-4 2629 2 1` (i*x's TOS-cell `3` clobbered by check_underflow_4's CALL ret-addr); post-fix → `-4 3 2 1`. The substitution is documented inline in the test file (`tests/throw_migration_tests.fth` Section 1.1 comment block) and the Makefile test descriptions.

### Completion Notes List

#### Verdict table (per AC, mirroring Story 11.3 / 11.4 format)

| AC | Gate text | Evidence | Verdict |
|----|-----------|----------|---------|
| #1 | `1 ' + CATCH . .` → `-4 1  ok` (smallest reproducer) | REPL test 718; pre-fix `-4 1483`, post-fix `-4 1` | **PASS** |
| #2 | `1 2 3 ' DROP CATCH . . . .` → `-4 3 2 1` (AC literal form unsatisfiable; 2OVER substituted) | REPL test 719 (`1 2 3 ' 2OVER CATCH . . . .` → `-4 3 2 1  ok`); see "AC trace correction" above | **PASS** (with substituted xt; DROP-as-written impossible — see Debug Log) |
| #3 | `1 2 3 ' DROP CATCH DEPTH .` → `4` (same caveat) | REPL test 720 (`1 2 3 ' 2OVER CATCH . DEPTH .` → `-4 3  ok`; combined value+depth assertion per review F6) | **PASS** (with substituted xt) |
| #4 | `5 6 7 ' T CATCH DEPTH .` → `4` for `: T 1 0 / ;` | REPL test 722 (`5 6 7 ' T241 CATCH . DEPTH .` → `-10 3  ok`; combined assertion); supplementary REPL test 723 (`5 6 7 ' T241 CATCH . . . .` → `-10 7 6 5  ok`) | **PASS** |
| #5 | +2 slot repurposed from saved-IX (dead) to saved-BC; frame size unchanged at 8 bytes | `src/exception.asm:15-31` (file-header block); `src/exception.asm:43-50` (CATCH-docstring block); `_bmad-output/planning-artifacts/architecture.md:275-291` (E11-D1 frame layout); `architecture.md:176` CCD-1 row unchanged at "8 bytes" | **PASS** |
| #6 | saved-BC stored from BC immediately after `POP BC`; old saved-IX backfill deleted | `src/exception.asm` `w_CATCH_cf` body: `POP BC` then frame-push pass writes `(IX+0), C` / `(IX+1), B` at the +2 slot; `PUSH IX/POP HL/LD (IX+2),L/LD (IX+3),H` backfill removed | **PASS** |
| #7 | saved-SP captured AFTER POP BC (= SP_safe); old `LD HL,0/ADD HL,SP` pre-POP capture moved | `src/exception.asm` `w_CATCH_cf` body: `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` idiom AFTER `POP BC` | **PASS** |
| #8 | THROW caught path: read +0 → SP_safe; pop frame; read saved-BC via `LD C,(IX-6)/LD B,(IX-5)`; `LD SP, HL`; `PUSH BC`; `LD BC, n`; NEXT | `src/exception.asm` `w_THROW_cf.kernel_entry` body restructured per spec; FUTURE-EDIT NOTE inline | **PASS** |
| #9 | `catch_resume_cf` normal-return path unchanged (no read of +2) | `src/exception.asm` `catch_resume_cf` body unchanged; brief comment added noting +2 repurposing has zero behavioural impact on this path | **PASS** |
| #10 | All existing tests continue to pass | REPL tests 1..717 all PASS post-edit | **PASS** (no regressions) |
| #11 | Section 7.1 / Sections 1.1 / 2.1 added with i*x-preservation tests | `tests/exception_tests.fth` Section 7.1 narrative block + Section 8.1 nested-CATCH-with-i*x test + Section 8.2 3-level nested test (review F4) + Section 8.3 DO-LOOP-frame test (review F2); `tests/throw_migration_tests.fth` Sections 1.1 + 2.1; Makefile blocks 718..726 (9 new) | **PASS** |
| #12 | Nested CATCH preserves i*x at each frame level independently | REPL test 724 (`1 2 ' N84 CATCH . . . .` → `0 -5 2 1  ok`); REPL test 725 (3-level nested with rethrow, `11 22 ' MI3 CATCH . . .` → `-7 22 11  ok`) | **PASS** |
| #13 | architecture.md E11-D1 + E11-D2 + source-file frame-layout blocks updated in lockstep | `_bmad-output/planning-artifacts/architecture.md` E11-D1 block + CATCH steps + E11-D2 caught-path step 3 + new "i*x preservation under THROW" rationale paragraph + Implementation-Patterns example fix; `src/exception.asm` file-header block + CATCH-docstring block; `docs/register-conventions.md` §9 layout + 7-step caught-path algorithm | **PASS** |
| #14 | Comment block at SP-capture-after-POP-BC site explains WHY the order matters | `src/exception.asm` `w_CATCH_cf` body comment block calls out "Pre-Story-11.4.1 was inverted, with [old-SP] = i*x-TOS-cell, then xt's CALLs would clobber it (Story 11.4 Note A)" verbatim | **PASS** |
| #15 | Post-NEXT invariant comment block rewritten to describe actual mechanism | `src/exception.asm` THROW docstring block rewritten to acknowledge prior comment's incorrect assumption and describe the saved-BC restore via `PUSH BC` after `LD SP, HL` | **PASS** |
| #16 | Binary delta within ±15 bytes | +9 bytes (17373 → 17382); AC estimated +0..+8, slightly over but within investigate threshold. Source: -11 bytes from removed `LD HL,0/ADD HL,SP` (4) + removed `PUSH IX/POP HL/LD(IX+2),L/LD(IX+3),H` backfill (7); +9 from new `PUSH HL/LD HL,2/ADD HL,SP/POP HL` (5) + new `LD(IX+0),C/LD(IX+1),B` (4); +7 on THROW path from `LD C,(IX-6)/LD B,(IX-5)/PUSH BC`. Net instructions: +5; comment-citation lines add ~4 prefix bytes (label re-padding). Total: +9. | **PASS** |
| #17 | Cycle-count delta recorded | Estimated CATCH frame-push: original ~95 t-states; new ~100 t-states (+5 from PUSH HL/POP HL spill-recover idiom, less the saved-IX backfill removal). THROW caught path: +49 t-states (`LD C,(IX-6)` 19 + `LD B,(IX-5)` 19 + `PUSH BC` 11). Caught path is cold (only fires on errors) — no impact on hot uncaught-CATCH cycle budget. NFR4 envelope unchanged. (Review F1 noted the original AC underestimated by ignoring the THROW side; rationale at `architecture.md:288` updated to acknowledge the THROW-side delta.) | **PASS** |
| #18 | Adversarial review finds ≥ 2-3 HIGH/MEDIUM findings | 8 findings (2 HIGH, 4 MEDIUM, 2 LOW) — see review-log table below | **PASS** |
| #19 | Verdict-table format per Story 11.3 / 11.4 | This table | **PASS** |
| #20 | `make` + `make test` + `make test-repl` clean; new tests at PASS 718.. | All clean; 735 PASS / 0 FAIL post-fix (was 726 pre-fix); +9 new tests at 718-726 | **PASS** |

#### Adversarial review log (Task 10)

| ID | Severity | Category | Description | Resolution |
|----|----------|----------|-------------|------------|
| F1 | HIGH | Cycle-cost / spec accuracy | AC #17's "+5 t-states" estimate ignored the THROW caught-path additions; `LD C,(IX-6)/LD B,(IX-5)/PUSH BC` adds ~49 t-states to every caught THROW. NFR4 rationale at `architecture.md:287` did not reflect this. | **Fixed in-pass:** AC #17 verdict-table cell rewritten to enumerate both CATCH (+5) and THROW (+49) deltas; `architecture.md:288` rationale paragraph updated to call out the THROW-side cost (cold path, no hot-uncaught-CATCH impact). |
| F2 | HIGH | Test coverage gap (AC #18(d) — DO-LOOP-frame with non-empty i*x) | Existing DO-LOOP and EXECUTE tests use empty pre-CATCH stack; no test exercised snap-back across non-colon IX-frame WITH multi-cell pre-CATCH i*x preserved. | **Fixed in-pass:** `tests/exception_tests.fth` Section 8.3 added (`: TDOL3 5 0 DO 2OVER LOOP ; 1 2 3 ' TDOL3 CATCH . . . .` → `-4 3 2 1`); Makefile test 726 appended. |
| F3 | MEDIUM | Stale "saved IX" reference (AC #18(e), Task 8.1 sweep gap) | Task 8.1's grep glob did not include `_bmad-output/planning-artifacts/epics.md`. Line `:737` still read "saved SP, saved IX, …". | **Fixed in-pass:** `epics.md:737` updated to "saved SP, saved BC = i*x's TOS-cell value per Story 11.4.1, …". |
| F4 | MEDIUM | Test coverage gap (AC #18(c) — multi-level nested) | Section 8.1 has only 2-level nesting. AC #18(c) called out 3-level coverage; the outer's +2 must remain undisturbed across an inner-rethrow chain. | **Fixed in-pass:** `tests/exception_tests.fth` Section 8.2 added (`: TI3 -5 THROW ; : MI3 ['] TI3 CATCH DROP -7 THROW ; 11 22 ' MI3 CATCH . . .` → `-7 22 11`); Makefile test 725 appended. |
| F5 | MEDIUM | Source comment grammar | `src/exception.asm:18-21` had a sentence fragment ("the cell xt's CALL/RET would otherwise clobber at [SP_safe-2] is repopulated"). | **Fixed in-pass:** reworded to "the cell at [SP_safe-2] — which any CALL inside xt would otherwise clobber with its return-address byte — is repopulated before NEXT." |
| F6 | MEDIUM | Test fragility — weak regex on tests 720 / 722 | `grep -qE '^4  ok'` could PASS by coincidence if a regression silently caused the THROW caught path to no-op while DEPTH happened to land on 4. | **Fixed in-pass:** tests 720 / 722 strengthened to combine value-and-depth assertions: `1 2 3 ' 2OVER CATCH . DEPTH .` → `-4 3  ok` and `5 6 7 ' T241 CATCH . DEPTH .` → `-10 3  ok`. Each now asserts both the THROW code AND the post-pop depth. |
| F7 | LOW | Loose architecture-doc wording — over-stated CALL clobber claim | `architecture.md:282` reads as if every xt clobbers `[SP_safe-2]`; only xts that perform a CALL do. | **Deferred with rationale:** the post-fix behaviour is correct under both branches (PUSH BC overwrites either way); the strong-form wording is harmless. Cost of further wording refinement exceeds the benefit. Flag for future doc refresh. |
| F8 | LOW | Future-edit-hazard documentation completeness — Story 13.4 INCLUDE-TOP loop | The FUTURE-EDIT NOTE in the THROW caught-path body warns about IX-relative writes in the read-window but doesn't explicitly call out Story 13.4's planned INCLUDE-TOP chain walk as the primary candidate. | **Deferred with rationale:** the existing comment already says "only CATCH and INCLUDE write to the IX rstack"; Story 13.4 will need to update this section anyway when the chain walk lands. Avoid pre-emptive forward-reference noise. Flag for Story 13.4 implementer. |

#### Behavioural summary

- CATCH frame +2 slot repurposed from "saved IX" (dead code, AC #5) to "saved BC" (i*x's TOS-cell value at CATCH entry). Frame size unchanged at 8 bytes (CCD-1 invariant preserved).
- CATCH's EXECUTE-prelude reordered: `LD H,B / LD L,C / POP BC` runs **before** the frame push so SP_safe (post-POP SP) and i*x's TOS-cell value (in BC) are both available for the new frame layout.
- SP_safe captured via `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` idiom (HL holds xt at this point; spill across SP capture, recover after).
- THROW caught path adds `LD C,(IX-6) / LD B,(IX-5) / PUSH BC` after the SP restore: reads saved-BC from popped frame's old +2 slot, restores it to the data stack at `[SP_safe-2]` (overwriting whatever return-address garbage xt's CALLs left there), then loads `BC=n` and NEXTs.
- `catch_resume_cf` (normal-return path) unchanged behaviourally — the +2 slot's repurposing has zero effect on it (it doesn't read +2).
- Story 11.4 ACs #9 / #11 / #12 verdict-table flipped from PARTIAL to PASS; Note A's "Forward action" line gets a 2026-04-26 closure date with the AC #2/#3 trace-correction caveat.
- `docs/register-conventions.md` §9 updated in lockstep: layout block, `+2` recursion paragraph, "saved IX → saved BC" §11.2 contract paragraph, 7-step caught-path algorithm step 7 rewritten to describe the saved-BC restore mechanism.

#### Pre/post binary-size delta

| Stage | Bytes | Delta vs prior |
|-------|-------|----------------|
| Story 11.4 final | 17373 | (baseline) |
| Story 11.4.1 post-edit (after Task 7) | 17382 | +9 (within ±15-byte threshold per AC #16; estimated +0..+8) |
| Story 11.4.1 post-review-fix (after Task 10) | 17382 | +0 (review fixes are tests + comments; no code-side changes) |

### File List

Modified:
- `src/exception.asm` — `w_CATCH_cf` body restructured (POP BC reordered before SP_safe capture; saved-BC stored at +2 directly during frame-push pass; saved-IX backfill removed); `w_THROW_cf.kernel_entry` caught-path body extended with saved-BC restore (`LD C,(IX-6)/LD B,(IX-5)/PUSH BC` after the SP restore); file-header frame-layout block + CATCH-docstring frame-layout block + post-NEXT-invariant comment block all rewritten to reflect the new +2 semantics; `catch_resume_cf` body unchanged behaviourally with brief comment addition; review F5 grammar fix.
- `_bmad-output/planning-artifacts/architecture.md` — E11-D1 frame-layout code block updated (`+2: saved IX` → `+2: saved BC` with the new gloss); CATCH steps list amended (saved-BC + post-POP saved-SP); E11-D2 caught-path step 3 amended (saved-BC restore via `PUSH BC` after `LD SP, HL`); new "i*x preservation under THROW (Story 11.4.1)" rationale paragraph appended after the E11-D2 main rationale; Implementation-Patterns example at `:582-585` updated from "6-byte exception frame" to "8-byte exception frame" with the post-Story-11.4.1 layout note; NFR4 cycle-cost rationale updated to acknowledge the THROW-side delta (review F1).
- `_bmad-output/planning-artifacts/epics.md` — line `:737` updated from "saved SP, saved IX, …" to "saved SP, saved BC = i*x's TOS-cell value per Story 11.4.1, …" (review F3).
- `docs/register-conventions.md` — §9 (Exception Frames) frame-layout code block + `+2` slot recursion paragraph + Story 11.2 contract paragraph + 7-step caught-path algorithm step 7 + post-NEXT invariants list all updated to the saved-BC / SP_safe semantics.
- `tests/exception_tests.fth` — Section 7.1 narrative block added (documents the pre-fix "passes by coincidence" fragility removal); Section 8.1 nested-CATCH-with-i*x test (`1 2 ' N84 CATCH . . . .` → `0 -5 2 1`); Section 8.2 3-level nested test (review F4); Section 8.3 DO-LOOP-frame test (review F2).
- `tests/throw_migration_tests.fth` — file-header CAVEAT replaced with closure note; Section 1.1 (caught underflow with i*x preservation: smallest reproducer + 3-cell + 2-cell forms via 2OVER); Section 2.1 (caught divisor-zero with i*x preservation, AC #4 spec form).
- `Makefile` — appended REPL test blocks 718..726 (9 new tests) covering AC #1 / #2 / #3 / #4 / #11 / #12 spec forms plus the review F2 / F4 supplementary tests; tests 720 / 722 use combined value-and-depth assertions per review F6.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-4-1-…: ready-for-dev` → `in-progress` → `review`; the multi-line "Known defect" comment block above the `11-4-…` row replaced with a closure-summary comment noting Story 11.4.1 closed the defect and Story 11.4 ACs #9 / #11 / #12 flipped to PASS.
- `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — verdict-table rows for AC #9 / #11 / #12 flipped from PARTIAL to PASS with forward-pointer to this story; Note A's "Forward action" line gets a 2026-04-26 closure date and the post-fix verification evidence.
- `_bmad-output/implementation-artifacts/11-4-1-catch-throw-ix-preservation-bug-fix.md` — this file (Status, all 11 task checkboxes marked `[x]`, Dev Agent Record fully populated, File List, Change Log).

No new files. No deletions.

### Change Log

| Date | Summary | Agent |
|------|---------|-------|
| 2026-04-26 | Story 11.4.1 implementation: CATCH frame +2 slot repurposed from "saved IX" (dead) to "saved BC" (i*x's TOS-cell value); CATCH captures saved-SP AFTER POP BC (= SP_safe); THROW caught path restores via `PUSH BC` after `LD SP, HL`. Closes Story 11.4 Note A defect. New REPL tests 718..726 (+9). Adversarial review yielded 8 findings (2 HIGH, 4 MEDIUM, 2 LOW); F1-F6 fixed in-pass, F7-F8 deferred LOW with rationale. Post-fix: `make` clean, `make test` clean, `make test-repl` 735 PASS / 0 FAIL; binary 17373 → 17382 (+9 bytes, within AC #16's ±15-byte budget). | claude-opus-4-7 |
| 2026-04-26 | Code-review pass (`bmad-bmm-code-review` skill, fresh context): 5 additional findings (0 HIGH, 2 MEDIUM, 3 LOW). All fixed in-pass: R-M1 (Story 11.4 verdict-table for AC #11 / AC #12 cited stale pre-F6 test forms — propagated F6 strengthening); R-M2 (`tests/throw_migration_tests.fth` Section 1.1 / 2.1 had stale `expect: 4 ok` forms not matching the Makefile's strengthened combined-form assertions — synced both); R-L1 (`src/exception.asm:114-117` FUTURE-EDIT NOTE was over-broad and self-contradicting given the existing PUSH IX / POP HL pair — tightened to name the actual sensitive window: between PUSH HL and the LD HL,2 / ADD HL,SP); R-L2 (`docs/register-conventions.md:384` lock-claim was stale post-revision — updated to acknowledge the Story 11.4.1 revision as the deliberate change required); R-L3 (story narrative misattributed the spec basis to FR21/FR22 which cover only uncaught-THROW REPL recovery — clarified that ANS §6.1.0875 / §9.6.1.0875 stack-effect compliance is the load-bearing standard). Post-fix verification: `make` clean, `make test` clean, `make test-repl` 735 PASS / 0 FAIL; binary unchanged at 17382 bytes (comment + doc edits only). Status → done. | claude-opus-4-7 |
