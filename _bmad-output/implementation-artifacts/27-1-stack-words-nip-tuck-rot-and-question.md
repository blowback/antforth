# Story 27.1: Stack words `NIP`, `TUCK`, `-ROT` and `?`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer,
I want `NIP`, `TUCK`, `-ROT` and `?` built in,
so that common stack shuffles and quick variable inspection work without defining them myself.

**Covers:** FR-P7-1, FR-P7-2, FR-P7-3, FR-P7-12, FR-P7-13 (part). Source: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` § "Story 27.1".

## Acceptance Criteria

1. **Behaviour.** On the candidate kernel, `1 2 NIP .S` shows `<1> 2 `, `1 2 TUCK .S` shows `<3> 2 1 2 `, and `1 2 3 -ROT .S` shows `<3> 3 1 2 ` (ANS 94 §6.2.1930, §6.2.2300; `-ROT` is the inverse of `ROT`). `1 2 3 -ROT ROT` leaves `1 2 3`.
2. **`?`.** After `VARIABLE V  42 V !`, `V ?` prints `42 ` (§15.6.1.0600, defined as `@ .`). `HEX V ?` prints `2A ` (BASE is honoured). The probe restores `DECIMAL` afterwards.
3. **Underflow.** With too few items, `NIP`, `TUCK`, `-ROT` and `?` raise `-4` ("stack underflow") through an existing `check_underflow*` helper; no new checking scheme. `NIP`/`TUCK` use `check_underflow_2` (as `SWAP`/`OVER` do). `-ROT` uses `check_underflow_3` so that `1 2 -ROT` raises `-4` rather than reading below the stack (see Dev Notes, "The ROT depth-2 gap"). `?` gets its check from `@`.
4. **Register contract.** Each new CODE word preserves DE = IP, leaves BC = TOS, and uses no `EXX`.
5. **Extension flag.** `-ROT` carries a `; antforth extension` source comment.
6. **Tests.** A new REPL-piped probe file `tests/stack_words_tests.fth` plus a Makefile target `test-repl-stack-words`, added as a prerequisite of `test-repl` (like `test-repl-rstack-guard`), covers every case in AC1–3 both at interpret level and inside a colon body. Probe lines stay ≤ 128 chars.
7. **Docs.** In `docs/ans-forth-core-compliance.md`: the `NIP`/`TUCK` rows move from "§6.2 Deliberately Omitted" to "§6.2 Implemented" with verdict `Implemented`, a `src/stack_ops.asm:LINE` source and Closure `Story 27.1`; `?` gets a row in "Non-standard words" as TOOLS §15.6.1.0600; `-ROT` is listed there as `Non-standard (antforth extension)`. The §6.2 implemented/omitted counts are recounted from the table rows (see Dev Notes, "Compliance doc counts are already stale"). In `docs/dev_journal.md` the `-ROT`, `?` and `NIP, TUCK` entries are marked `— RESOLVED 2026-MM-DD, Story 27.1` in the existing style. `README.md`'s 6.2 and 15.6 coverage rows match the recount.
8. **Regression.** `make test` passes; `make test-repl` passes at 0 FAIL with the baseline count plus the new probes; none removed.
9. **Budget.** The real byte delta against the pre-edit baseline is recorded in Dev Notes (estimate 76 B, itemised below).
10. **Hardware.** The S9 hardware-smoke recipe is posted in the closing review chat message.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 30,754 B (2026-10-08) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (epic doc says 1012 PASS / 0 FAIL — re-measure)

### Story tasks

- [x] **Task 1 — CODE words in `src/stack_ops.asm`** (AC: 1, 3, 4, 5)
  - [x] 1.1 `NIP` after `OVER` (or after `ROT`; keep the file's grouping): `CALL check_underflow_2` / `POP HL` / `NEXT`. BC already holds x2.
  - [x] 1.2 `TUCK`: `CALL check_underflow_2` / `POP HL` (x1) / `PUSH BC` (x2) / `PUSH HL` (x1) / `NEXT`. BC stays x2.
  - [x] 1.3 `-ROT` directly after `ROT`, with `; antforth extension` on the header comment: `CALL check_underflow_3` / `LD H,B` / `LD L,C` (HL = x3) / `POP BC` (BC = x2, new TOS) / `EX (SP),HL` (HL = x1, deep slot = x3) / `PUSH HL` / `NEXT`.
  - [x] 1.4 Update the file's top-of-file word list comment (`; Parameter stack: DUP, DROP, SWAP, …`).
  - [x] 1.5 Header comments follow the existing shape: `; NAME ( stack -- effect )` + one-line description; add the ANS § line for `NIP`/`TUCK` as other §6.2 words do.
- [x] **Task 2 — `?` in `src/formatting.asm`** (AC: 2, 3)
  - [x] 2.1 DEFWORD `"?"` next to the Tools word `.S` (place it immediately before the `.S` block, after `UD.`). Body: `DW w_FETCH_cf` / `DW w_DOT_cf` / `DW EXIT_CODE`. Use the DEFWORD `cf` label pattern: `w_QUESTION_body:` then `w_QUESTION_cf EQU w_QUESTION_body - 3` (`feedback_defword_cf_label`).
  - [x] 2.2 Header comment: `; ? ( a-addr -- )   Display the cell at a-addr.` + `; ANS Forth 1994 §15.6.1.0600   ?   — Programming-Tools`.
- [x] **Task 3 — decide the `ROT` depth-2 gap** (AC: 3) — see Dev Notes. Default plan: change `ROT`'s `CALL check_underflow_2` to `CALL check_underflow_3` (0 B) and drop the "DEPTH=2 not caught" comment, so `ROT` and `-ROT` really do raise the same error at the same depth. Add the `1 2 ROT` → -4 case to the probe. If the project lead says no, leave `ROT` alone and record that as an open defect in `docs/dev_journal.md`.
- [x] **Task 4 — probe file `tests/stack_words_tests.fth`** (AC: 1, 2, 3, 6)
  - [x] 4.1 Header comment in the style of `tests/rstack_guard_tests.fth`: what it pins, why greps are column-0 anchored. Start with `DECIMAL`.
  - [x] 4.2 Pre-flight: `' NIP DROP  ' TUCK DROP  ' -ROT DROP  ' ? DROP` (undefined → -13 fails loudly).
  - [x] 4.3 Interpret level, tagged column-0 output asserted by the Makefile, each line cleaning its stack afterwards, e.g. `." swA=" 1 2 NIP .S CR DROP`, `." swB=" 1 2 TUCK .S CR DROP DROP DROP`, `." swC=" 1 2 3 -ROT .S CR DROP DROP DROP`, `." swD=" 1 2 3 -ROT ROT .S CR DROP DROP DROP`.
  - [x] 4.4 `?`: `VARIABLE V  42 V !` then `." qA=" V ? CR` and `HEX ." qB=" V ? CR DECIMAL`. Add `-1 V ! ." qC=" V ? CR` (signed print → `-1 `).
  - [x] 4.5 Colon-body self-asserting words, e.g. `: _nip 1 2 NIP 2 = DEPTH 1 = AND IF ." PASS: sw-nip" ELSE ." FAIL: sw-nip" THEN CR ;` — check value AND depth for each word, one each for `NIP`, `TUCK` (check all three cells), `-ROT` (all three cells), `-ROT ROT` round trip, and `?` inside a colon body (tagged print line, since `?` prints rather than returns).
  - [x] 4.6 Underflow at interpret level, one per line, empty stack first: `NIP`, `1 NIP`, `TUCK`, `1 TUCK`, `-ROT`, `1 -ROT`, `1 2 -ROT`, `?`, and (if Task 3 lands) `1 2 ROT`. Then a column-0 `PASS: sw-survives` line computed at runtime with `DEPTH 0=` to prove the REPL came back clean.
  - [x] 4.7 Keep every line ≤ 128 chars including any `\` annotation (`feedback_tib_size_inline_comments`). No `BANK!` anywhere (the 23.8 lint).
  - [x] 4.8 The file is in `tests/`, not `disk/a/`, so no 0x1A terminator is required; check how the other `tests/*.fth` files end and match them.
- [x] **Task 5 — Makefile** (AC: 6, 8)
  - [x] 5.1 Add `STACK_WORDS_PROBE = tests/stack_words_tests.fth` beside `RSTACK_GUARD_PROBE` (Makefile:199).
  - [x] 5.2 Add target `test-repl-stack-words` using the `test-repl-rstack-guard` recipe shape (Makefile:646): pipe through `sed 's/$$/\r/'`, append `BYE`, `timeout $(PROBE_TIMEOUT)`, then `tests/assert_verdicts.sh --label "REPL stack-words probe" --fail-line '^FAIL: sw-'` with the PASS patterns, the tagged lines (`'swA=<1> 2 '`, `'qA=42 '`, `'qB=2A '`, …) and `--count N '^error -4: stack underflow' 'stack-words underflow raises -4 N times'` where N is the number of underflow lines in 4.6.
  - [x] 5.3 Add it to `.PHONY` (Makefile:56) and to the `test-repl:` prerequisite list (Makefile:1926).
  - [x] 5.4 Run the new target alone, then a deliberately broken variant (e.g. temporarily expect `swA=<1> 1 `) to see it fail, then restore.
- [x] **Task 6 — docs** (AC: 7)
  - [x] 6.1 `docs/ans-forth-core-compliance.md`: move the `NIP` (§6.2.1930) and `TUCK` (§6.2.2300) rows into "§6.2 Implemented", keeping § order. While there, move the two already-`Implemented` rows still sitting in the omitted table (`TO` §6.2.2295, `VALUE` §6.2.2405) into the implemented table too.
  - [x] 6.2 Recount from the rows and fix every count that quotes them: the summary table "Core Extension words implemented (§6.2) | 12 of 46" (line 78), the paragraph at line 387, and the headings at lines 391 and 415. Expected after this story: 17 of 46 implemented (13 + TO + VALUE + NIP + TUCK), 29 omitted, plus HOLDS as the Forth-2014 bonus — verify by counting `^| §6.2` rows, don't trust this arithmetic.
  - [x] 6.3 "Non-standard words" table (line ~858): add `?` (`formatting.asm:LINE`, TOOLS — §15.6.1.0600) next to `.S`, and `-ROT` (`stack_ops.asm:LINE`, `Non-standard (antforth extension)`). The existing `WORDS`/`.S` line numbers there are stale (`dictionary.asm:160` vs actual `:362`; `formatting.asm:263` vs `:270`) — correct them while editing that table.
  - [x] 6.4 `docs/dev_journal.md`: mark ` - \`-ROT\``, ` - \`?\` …` and ` - NIP, TUCK ` resolved using the existing `— RESOLVED 2026-MM-DD, Story 27.1` suffix.
  - [x] 6.5 `README.md` lines 48 and 58: 6.2 row to the recounted figure (state whether HOLDS is included, as the current "14" does); 15.6 row to `3 / 5 | ~60% (.S, WORDS, ? — no SEE/DUMP)`.
  - [x] 6.6 Leave `src/system.asm:576` (`env_table` CORE-EXT "13/46" comment) for Story 27.5, which owns it. `ENVIRONMENT? CORE-EXT` must still answer false.
  - [x] 6.7 Run `make check-doc-sync`; it must pass.
- [x] **Task 7 — verify and record** (AC: 8, 9, 10)
  - [x] 7.1 `make` then `wc -c build/antforth.com`; record delta vs baseline and compare per word against the itemised estimate.
  - [x] 7.2 `make test` and `make test-repl` green; record the new PASS count.
  - [x] 7.3 If any banking probe now halts or times out, read `feedback_banking_probe_straddle_halt` first: kernel growth shifting a probe body across `$8000` is a known effect of adding bytes, and the fix is in the probe, not the kernel.
  - [x] 7.4 Write the S9 hardware-smoke recipe into Dev Notes (and post it in the review close message): type the AC1/AC2/AC3 lines at the MicroBeast prompt and compare against the expected output.

## Dev Notes

### Design: register-level sequences

Stack model: BC = TOS; `(SP)` = second; `(SP+2)` = third (`project_tos_in_register`). Every word below touches only HL (and AF via the check helper). DE = IP is never touched, no `EXX`, no IX use. The check helpers preserve BC, DE, IX, IY and SP and clobber AF, HL (`src/system.asm:625-700`).

```asm
; NIP ( x1 x2 -- x2 )
        CALL    check_underflow_2
        POP     HL              ; discard x1; BC = x2 already
        NEXT

; TUCK ( x1 x2 -- x2 x1 x2 )
        CALL    check_underflow_2
        POP     HL              ; HL = x1
        PUSH    BC              ; x2
        PUSH    HL              ; x1
        NEXT                    ; BC = x2 unchanged

; -ROT ( x1 x2 x3 -- x3 x1 x2 )   ; antforth extension
        CALL    check_underflow_3
        LD      H, B
        LD      L, C            ; HL = x3
        POP     BC              ; BC = x2 (new TOS); (SP) = x1
        EX      (SP), HL        ; HL = x1; deep slot = x3
        PUSH    HL              ; x1 above x3
        NEXT
```

Trace `-ROT` with `1 2 3`: start BC=3, SP→[2][1]. After `LD HL,BC`: HL=3. `POP BC`: BC=2, SP→[1]. `EX (SP),HL`: HL=1, SP→[3]. `PUSH HL`: SP→[1][3]. Result bottom→top `3 1 2`. ✓

`?` is a threaded word: `@ .`. `@` (`src/memory.asm:44`) runs `check_underflow`, so `?` on an empty stack raises -4 before touching memory. `.` is `S>D D.`, which follows `BASE`.

### Byte budget (itemised, est. 76 B)

Kernel dictionary header (DEFCODE / DEFWORD macros, `src/macros.asm:66-136`): fat link 3 B + count/flags 1 B + name bytes. `NEXT` expands to 7 B (`EX DE,HL` + `LD E,(HL)` + `INC HL` + `LD D,(HL)` + `INC HL` + `EX DE,HL` + `JP (HL)`). `CALL nn` = 3 B; `POP`/`PUSH rr` (BC/HL), `LD r,r`, `EX (SP),HL` = 1 B each.

| Word | Header | Body | Total |
|---|---|---|---|
| `NIP` | 3+1+3 = 7 | CALL 3 + POP 1 + NEXT 7 = 11 | 18 |
| `TUCK` | 3+1+4 = 8 | CALL 3 + POP 1 + PUSH 1 + PUSH 1 + NEXT 7 = 13 | 21 |
| `-ROT` | 3+1+4 = 8 | CALL 3 + LD 1 + LD 1 + POP 1 + EX 1 + PUSH 1 + NEXT 7 = 15 | 23 |
| `?` | 3+1+1 = 5 | JP DOCOL 3 + 3 × DW 2 = 9 | 14 |
| `ROT` check change | — | `CALL` target swap, same size | 0 |
| **Total** | | | **76** |

Epic allocation for 27.1 is ≈ 85 B; envelope for the epic ≤ 500 B (NFR-P7-2). If the measured delta differs from 76 B, explain the difference word by word.

### The ROT depth-2 gap (found while drafting)

`ROT` uses `check_underflow_2`, and its own comment says depth 2 is not caught (`src/stack_ops.asm:79`). Verified on iz-cpm-banking 2026-10-08 against the v3.2.1 binary:

```
1 2 ROT .S   →   <2> 2 0  ok
```

No error is raised; the `1` is lost and a `0` read from at/below `sp_base` appears. That is a silent wrong result, not a cosmetic gap. Copying that check into `-ROT` would copy the defect, so `-ROT` uses `check_underflow_3`, which is an existing helper (same `-4`, same `do_underflow_error` path), so AC3's "no new checking scheme" holds.

Task 3 proposes fixing `ROT` the same way in this story because it is 0 bytes, in the same file, and makes "same error as `ROT`" literally true. Per `feedback_no_preexisting_discharge`, it should not be left as "accepted: pre-existing". This is the one decision in the story the project lead may want to overrule; see Questions.

Existing probes that use `ROT` (checked 2026-10-08): `tests/throw_migration_tests.fth:48` runs `' ROT CATCH .` on an empty stack and expects `-4`, which still holds with `check_underflow_3`. The banking/pictured/wordlist uses all run `ROT` with ≥ 3 items. Re-run `grep -n "ROT" tests/*.fth Makefile` before changing it in case that has moved.

### Compliance doc counts are already stale

Counted 2026-10-08 in `docs/ans-forth-core-compliance.md`:
- "§6.2 Implemented" table (starts line 391): 13 rows.
- "§6.2 Deliberately Omitted (33 of 46)" table (starts line 415): 33 rows, but 2 of them (`TO`, `VALUE`, added by Story 23.2) already have verdict `Implemented`.
- Summary table at line 78 still says "12 of 46"; paragraph at 387 says 13.

So the real figure before this story is 15 implemented / 31 omitted. Fix this while moving `NIP`/`TUCK`; it's the same table and leaving it would mean recording a wrong count under Story 27.1. README's `14 / 46` (line 48) appears to be 13 + HOLDS; keep whatever convention you choose consistent between README and the compliance doc and say which it is.

### Placement and names

- `NIP`, `TUCK`, `-ROT` → `src/stack_ops.asm` (epic "Home files follow existing grouping"). Labels: `w_NIP` / `w_NIP_cf`, `w_TUCK` / `w_TUCK_cf`, `w_MINUS_ROT` / `w_MINUS_ROT_cf` (check `grep -n "w_MINUS\|w_DASH" src/*.asm` for the house convention for a leading `-`).
- `?` → `src/formatting.asm` beside `.S`. Label `w_QUESTION` / `w_QUESTION_body` / `w_QUESTION_cf` (no `w_QUESTION*` label exists; existing `?`-prefixed words abbreviate to `w_Q…` — `w_QDUP`, `w_QBRANCH` — but a bare `w_Q` would be unreadable). No existing word is named `?` (checked: no `DEF* "?"` in `src/`, no `: ? ` in `disk/`, `examples/`, `tests/`).
- No local definitions of `NIP`/`TUCK`/`-ROT`/`?` exist in `disk/`, `examples/` or `tests/*.fth` (grep 2026-10-08), so nothing in-tree needs removing.
- New kernel words are in fixed memory below `$8000`; they are findable from every bank like any other kernel word. No banking change.

### Testing standards

- Test through the Forth threading model, REPL-piped (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Verdict greps are column-0 anchored: runtime output starts at column 0, echoed source does not (the 23.2 lesson; see the header of `tests/rstack_guard_tests.fth`).
- Printed results (`.S`, `?`) are asserted as tagged lines in the Makefile; computed results self-assert with `PASS:`/`FAIL:` lines.
- `assert_verdicts.sh` options: `--label`, `--mode anchored|strip-source`, `--fail-line`, `--count N REGEX LABEL`, `--present REGEX LABEL`; config flags come before assertions (`tests/assert_verdicts.sh:17-36`).
- Ask "what is BASE?" if a number looks wrong (`project_hex_base_leak_literal_truncation`); the `HEX` probe line must end in `DECIMAL`.
- Underflow output text is `error -4: stack underflow` (asserted that way in `test-repl-in-out`, Makefile:634).

### Project Structure Notes

- Files touched: `src/stack_ops.asm`, `src/formatting.asm`, `tests/stack_words_tests.fth` (new), `Makefile`, `docs/ans-forth-core-compliance.md`, `docs/dev_journal.md`, `README.md`, this story file, `sprint-status.yaml`.
- Source comments say what and why, never story/date provenance (`feedback_source_comment_discipline`). Story references belong in docs, git and this file.
- Commits: no Claude co-author trailer (`feedback_no_claude_coauthor`).
- No conflicts with the existing structure.

### References

- Epic: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — FR-P7-1/2/3/12/13, NFR-P7-1..7, Story 27.1 ACs.
- Neighbour words: `src/stack_ops.asm:44-86` (`SWAP`, `OVER`, `ROT`).
- Underflow helpers: `src/system.asm:625-700` (`check_underflow`, `_2`, `_3`).
- DEFCODE/DEFWORD macros and `NEXT`: `src/macros.asm:32-136`.
- `.`, `UD.`, `.S`: `src/formatting.asm:180-275`.
- `@`: `src/memory.asm:44`.
- Probe/Makefile pattern: `tests/rstack_guard_tests.fth`, `tests/ud_env_tests.fth`, Makefile:637-653, Makefile:1926.
- Compliance doc: `docs/ans-forth-core-compliance.md:55-80, 385-460, 858-890`.
- ANS Forth 1994 §6.2.1930 `NIP`, §6.2.2300 `TUCK`, §15.6.1.0600 `?`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (pre-edit, re-measured): `build/antforth.com` = 30,754 B; `make test-repl` = 1012 PASS / 0 FAIL / 2 SKIP.
- Red run: new probe failed 14 of 15 assertions (words undefined → -13; 0 × -4). `sw-survives` passed because the REPL recovers from -13 too.
- Green run: 15/15. Raw output has exactly 18 `error -4: stack underflow` lines (9 interpret level + 9 colon body), one per underflow source line.
- Task 5.4: changing the expectation to `swA=<1> 1 ` made the target fail; restored.

### Completion Notes List

- **Byte delta: +76 B** (30,754 → 30,830 B), exactly the itemised estimate: NIP 18, TUCK 21, -ROT 23, ? 14, ROT 0. Inside the ≈85 B allocation.
- **Task 3 (ROT depth-2 gap): fixed with the default plan.** `ROT` now calls `check_underflow_3`; the "DEPTH=2 not caught" comment is gone. `1 2 ROT` raises -4 at interpret level and in a colon body (both in the probe). `' ROT CATCH .` (REPL test 700, `throw_migration_tests.fth:48`) still gives -4. All ROT users in `tests/`, `Makefile` run it with ≥ 3 items; full `test-repl` is green. 0 bytes.
- `NIP`/`TUCK` use `check_underflow_2`; `-ROT` uses `check_underflow_3`; `?` gets its check from `@`. None touch DE, IX or use EXX; BC = TOS on exit.
- **Regression:** `make test` PASS. `make test-repl` 1027 PASS / 0 FAIL / 2 SKIP (1012 + 15 new; none removed). `make check-doc-sync` 0 drift. `ENVIRONMENT? CORE-EXT` still false (`env-core-x` in `test-repl-ud-env` passes); `src/system.asm:576` left for 27.5.
- **Compliance doc recount (from table rows):** §6.2 Implemented 17 rows, Deliberately Omitted 29 rows, no `Implemented` verdicts left in the omitted table. Moved NIP, TUCK, and the already-implemented TO and VALUE into the implemented table in § order. Summary table, §6.2 paragraph and both headings updated. **README convention:** `17 / 46 (+ HOLDS)` — the 46-word DPANS94 baseline count, with the Forth-2014 HOLDS noted separately, matching the compliance doc. (The old README "14" was 13 + HOLDS.)
- **Line citations:** inserting NIP/TUCK/-ROT shifted every later word in `stack_ops.asm`, and `?` shifted `.S` onward in `formatting.asm`. Updated every citation that was exact before this story (§6.1 ROT/DEPTH/>R/R>/R@, §6.2 PICK/ROLL, SP@..RP! row, `register-conventions.md` ROLL). Also corrected citations that were already stale in the tables touched: WORDS, .S, HEX, DECIMAL, TO (was pointing at `w_VALUE_cf`), VALUE. Left alone: `docs/shadow-register-followup-survey.md` (historical survey, already stale), `register-conventions.md:173` `.S` (already stale).
- **S9 hardware-smoke recipe** (type at the MicroBeast prompt; `DECIMAL` first):
  1. `1 2 NIP .S` → `<1> 2  ok`, then `DROP`
  2. `1 2 TUCK .S` → `<3> 2 1 2  ok`, then `DROP DROP DROP`
  3. `1 2 3 -ROT .S` → `<3> 3 1 2  ok`, then `DROP DROP DROP`
  4. `1 2 3 -ROT ROT .S` → `<3> 1 2 3  ok`, then `DROP DROP DROP`
  5. `VARIABLE V  42 V !  V ?` → `42  ok`; `HEX V ? DECIMAL` → `2A  ok`; `-1 V ! V ?` → `-1  ok`
  6. Each of these on its own line, empty stack, → `error -4: stack underflow`: `NIP`, `1 NIP`, `TUCK`, `1 TUCK`, `-ROT`, `1 -ROT`, `1 2 -ROT`, `?`, `1 2 ROT`
  7. `DEPTH .` → `0  ok` (prompt is still alive and the stack is clean)

- **S9 hardware smoke, 2026-10-08 (beastty-20261008-121509.txt):** steps 1–4 match exactly; `?` prints `42`, `2A` (HEX) and `-1`; `NIP`, `1 NIP`, `TUCK`, `1 TUCK`, `-ROT`, `1 -ROT`, `1 2 -ROT` and `1 2 ROT` each raise `error -4: stack underflow`; `DEPTH .` → `0`. Not run: bare `?` on an empty stack. **Open anomaly:** the line `variable v 5 42 v ! v ?` (raw bytes clean, no line edits) left a stray `5` on the stack. The emulator keeps it (`.s` → `<1> 5` after every later line), but on hardware the next `.s` showed `<0>`. Not reproduced: a narrowing run on hardware in the same session kept every item through `VARIABLE`, `!`, `?`, `HEX` and `.s` (its `42` under `hex` was BASE still HEX from the earlier `hex v ?`, not a fault), and replaying log lines 81–122 verbatim in the emulator gives `<1> 5` at the `.s`. Not attributed to this story; a fresh-session hardware replay of lines 81–104 would close it. Bare `?` on an empty stack, verified on hardware 2026-10-08: `.s` → `<0>`, `?` → `error -4: stack underflow`, `.s` → `<0>`.

### File List

- `src/stack_ops.asm` — NIP, TUCK, -ROT added; ROT uses `check_underflow_3`; word-list comment
- `src/formatting.asm` — `?` added before `.S`
- `tests/stack_words_tests.fth` — new probe
- `Makefile` — `STACK_WORDS_PROBE`, `test-repl-stack-words` target, `.PHONY`, `test-repl` prerequisite
- `docs/ans-forth-core-compliance.md` — §6.2 tables/counts, non-standard table, line citations
- `docs/register-conventions.md` — ROLL line citation
- `docs/dev_journal.md` — -ROT, ?, NIP/TUCK marked resolved
- `README.md` — 6.2 and 15.6 coverage rows
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 27-1 status
- `_bmad-output/implementation-artifacts/27-1-stack-words-nip-tuck-rot-and-question.md` — this file

### Change Log

- 2026-10-08: Story 27.1 implemented — NIP, TUCK, -ROT, ? (+76 B); ROT depth-2 underflow fixed (0 B); probe + Makefile target (15 assertions); compliance doc recount (§6.2 17/46); status → review.
- 2026-10-08: S9 hardware pass (`beastty-20261008-121509.txt`); stray-`5` anomaly left open. Committed as `2868649`. Status → done. No code-review record was kept for this story.
- 2026-10-12: Stray-`5` anomaly closed by the Story 27.5 fresh-session hardware replay (`<1> 5`, same as the emulator).
