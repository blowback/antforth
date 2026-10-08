# Story 27.3: `AGAIN`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer,
I want `BEGIN … AGAIN`,
so that infinite loops (task bodies, event loops) read as what they are.

**Covers:** FR-P7-10, FR-P7-13 (part). Source: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` § "Story 27.3".

## Acceptance Criteria

1. **Behaviour (§6.2.0700).** `AGAIN ( C: dest -- )` is IMMEDIATE and compiles `BRANCH` plus a backward offset to the matching `BEGIN`. `: _a1 0 BEGIN 1+ DUP 5 = IF EXIT THEN AGAIN ;` then `_a1 .` prints `5`.
2. **Structure.** `AGAIN` is a DEFIMMED word in `src/control_flow.asm` directly after `UNTIL`, with the same thread as `UNTIL` except `w_BRANCH_cf` in place of `w_QBRANCH_cf`. `: _a5 BEGIN AGAIN ;` compiles exactly `BRANCH -2 EXIT` (checked by reading the body cells; `_a5` is never run).
3. **Nesting.** Each of these exits through the expected path with a balanced data and return stack:
   - `BEGIN … AGAIN` inside `IF … THEN` (taken and not taken).
   - `BEGIN … AGAIN` enclosing a `DO … LOOP` that exits by `LEAVE`.
   - `BEGIN … WHILE … AGAIN THEN` (the ANS control-flow-stack combination: `WHILE`'s orig stays under `AGAIN`'s dest and `THEN` resolves it).
4. **Checking parity with `UNTIL`.** No new control-structure checking: `: _g AGAIN ;` (no `BEGIN`) fails the same way `: _u UNTIL ;` does today (`error -4: stack underflow`, from `-` inside the word).
5. **Compile-only.** `AGAIN` typed at the prompt (`STATE` = 0) raises `-14` through `?COMP`, as `UNTIL` does.
6. **Banked window top.** In a banked colon definition, the existing `GUARD_BANKED_WRITE` in `,` (`src/memory.asm:239`) raises `-8` when `AGAIN`'s `BRANCH` cell or its offset cell would cross `$C000`, and accepts the case where the offset cell ends exactly at `$BFFF`. No new guard code. A probe covers all three.
7. **`REPEAT` reuses `AGAIN`.** `REPEAT`'s body becomes `AGAIN THEN` (ANS §6.1.2140 defines it that way), saving 20 B. `REPEAT` compiles the same cells as before: `: _w BEGIN DUP WHILE 1- REPEAT ;` has `8` at body+4, `BRANCH` at body+8, `-10` at body+10 (verified on the 31,009 B binary, 2026-10-08), and `5 _w .` prints `0`. (Project lead may veto; see Dev Notes "`REPEAT` refactor".)
8. **Demo and docs.** `disk/a/TRAFFIC.FTH` (still ending `0x0A 0x1A`), `docs/phase6-multitasker.md` (three sites) and `docs/throw-codes.md` (one site) use `BEGIN … AGAIN` in place of `BEGIN … 0 UNTIL`, and their "AGAIN is undefined" remarks are removed. Test files keep their `0 UNTIL` code unchanged (see Dev Notes "Stale comments in tests").
9. **Tests.** New REPL-piped probe `tests/again_tests.fth` plus Makefile target `test-repl-again`, added as a prerequisite of `test-repl` after `test-repl-comparisons`, covering AC1–AC7 at interpret level and inside colon bodies. Probe lines ≤ 128 chars.
10. **Docs sync.** In `docs/ans-forth-core-compliance.md` the `AGAIN` row (§6.2.0700) moves from "§6.2 Deliberately Omitted" to "§6.2 Implemented" in § order (after `<>` §6.2.0500), workaround note removed; every §6.2 count is recounted from the rows (expected 22 implemented / 24 omitted); the §6.1 Control Flow rows' `control_flow.asm:` citations point at the real DEFIMMED/DEFCODE lines. `README.md` 6.2 row matches the recount. `docs/dev_journal.md` ` - AGAIN ` is marked resolved.
11. **Regression.** `make test` passes; `make test-repl` 0 FAIL with the baseline count plus the new probes, none removed; `make test-repl-multitasker-demo` (loads `TRAFFIC.FTH`, not part of `test-repl`) passes; `make check-doc-sync` passes.
12. **Budget.** Real byte delta against the pre-edit baseline recorded in Dev Notes and compared item by item with the estimate (+8 B net: `AGAIN` +28, `REPEAT` −20).
13. **Hardware.** S9 smoke includes running the updated `TRAFFIC.FTH`; the recipe is posted in the closing review chat message.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 31,009 B (2026-10-08, HEAD `35c096d`, after Story 27.2) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (27.2 recorded 1046 PASS / 0 FAIL / 2 SKIP — re-measure).
- [x] Before writing `AGAIN`, write the probe and run `make test-repl-again` once to see it fail (pre-flight `' AGAIN DROP` → `-13`).

### Story tasks

- [x] **Task 1 — `AGAIN` in `src/control_flow.asm`** (AC: 1, 2, 5)
  - [x] 1.1 Insert directly after `UNTIL` (currently ends at line 107, before `WHILE`'s header comment at 109). Code in Dev Notes. Labels `w_AGAIN` / `w_AGAIN_body` / `w_AGAIN_cf EQU w_AGAIN_body - 3` (`feedback_defword_cf_label`).
  - [x] 1.2 Header comment in the file's shape: `; AGAIN ( begin-addr -- )  IMMEDIATE, compile-only` + `;   Compile BRANCH with backward offset to begin-addr`. No story/date provenance (`feedback_source_comment_discipline`).
  - [x] 1.3 File header line 1 lists the words by kind, not by name; leave it.
- [x] **Task 2 — `REPEAT` body** (AC: 7)
  - [x] 2.1 Replace `REPEAT`'s body with `DW w_AGAIN_cf, w_THEN_cf` + `DW EXIT_CODE`, and its comment with `;   Compile BRANCH back to begin-addr (AGAIN), then resolve WHILE's fwd-ref (THEN)`. The `?COMP` line goes: `AGAIN` runs it first. Keep the stack comment `( while-fwd begin-addr -- )`.
  - [x] 2.2 If the project lead vetoes this (see Dev Notes), skip Task 2 and the `agR` probe line stays as a regression check on the unchanged `REPEAT`.
- [x] **Task 3 — probe file `tests/again_tests.fth`** (AC: 1–7, 9). Content in Dev Notes "Probe file". Header comment in the style of `tests/comparison_tests.fth` (what it pins, column-0 anchoring, error counts). Start with `DECIMAL`. End the file as `tests/comparison_tests.fth` does (plain `\n`, no 0x1A). No line over 128 chars including `\` annotations (`feedback_tib_size_inline_comments`).
- [x] **Task 4 — Makefile** (AC: 9, 11)
  - [x] 4.1 `AGAIN_PROBE = tests/again_tests.fth` after `COMPARISON_PROBE` (Makefile:201).
  - [x] 4.2 Target `test-repl-again` after `test-repl-comparisons` (Makefile:667), copying its recipe (timeout + straddle message, `sed 's/$$/\r/'`, `BYE`, `tests/assert_verdicts.sh --label "REPL AGAIN probe" --fail-line '^FAIL: ag-'`). Assertions listed in Dev Notes "Makefile assertions".
  - [x] 4.3 Add to `.PHONY` (line 56) and to the `test-repl:` prerequisites (Makefile:1950) after `test-repl-comparisons`.
  - [x] 4.4 Run the target alone; then break one expectation (e.g. `'agA=4 $$'`) to see it fail; restore.
  - [x] 4.5 Makefile:8664 comment says "antforth has no AGAIN"; reword to say the test uses `BEGIN 1 0 UNTIL` because each pass must push one cell (the probe code stays as is).
- [x] **Task 5 — demo and docs** (AC: 8)
  - [x] 5.1 `disk/a/TRAFFIC.FTH:46-58`: `0 UNTIL ;` → `AGAIN ;`, and rewrite the comment at 46-47 to drop "`AGAIN` is not defined in antforth" (keep the point that `Ctrl-\` can still stop it, which is what "(terminable)" meant: every `DELAY` is a yield point where the break is taken). Edit with a tool that preserves the trailing `0x0A 0x1A`; check with `tail -c 4 disk/a/TRAFFIC.FTH | xxd` before and after (`feedback_cpm_0x1a_eof_marker`).
  - [x] 5.2 `docs/phase6-multitasker.md:69-71`: drop the forever-loop half of "Two smaller notes…", leaving the active-low LED note as one sentence. Lines 204 and 281: `0 UNTIL ;` → `AGAIN ;` and remove the "AGAIN is undefined" trailing comments (line 281 becomes `BEGIN PAUSE AGAIN ;       \ park, still yielding`).
  - [x] 5.3 `docs/throw-codes.md:154`: `: SPIN BEGIN 0 UNTIL ;` → `: SPIN BEGIN AGAIN ;`.
  - [x] 5.4 Re-run `grep -rn "0 UNTIL\|AGAIN" docs/ disk/ examples/ README.md` and confirm nothing else claims `AGAIN` is missing (draft-time sweep: only the sites above, plus the compliance doc and dev journal handled in Task 6).
- [x] **Task 6 — compliance doc, README, dev journal** (AC: 10)
  - [x] 6.1 Move the `AGAIN` row (`docs/ans-forth-core-compliance.md:442` today) into "§6.2 Implemented" after `<>` (§6.2.0500), as `| §6.2.0700 | \`AGAIN ( -- )\` | Implemented | src/control_flow.asm:LINE | Story 27.3 | DEFIMMED; \`BRANCH\` + backward offset, as \`UNTIL\` with \`?BRANCH\`. |`.
  - [x] 6.2 Recount `^| §6.2` rows in both tables (don't trust 22/24) and update: summary table (line 78), the §6.2 paragraph (line 387; append `AGAIN` added by Story 27.3 to its "added by" list), the "§6.2 Implemented" heading (391) and "§6.2 Deliberately Omitted" heading (419). `README.md:49` → `22 / 46 (+ HOLDS) | ~48%` (or whatever the recount gives).
  - [x] 6.3 §6.1 Control Flow rows (`docs/ans-forth-core-compliance.md:279-294`): the `control_flow.asm:` citations were already off before this story (e.g. `IF` cites 32, its DEFIMMED is at 27; `UNTIL` cites 101, DEFIMMED at 96). After the edit, point every one at its DEFIMMED/DEFCODE line (the convention 27.2 used for `logic.asm`). Then `grep -rn "control_flow.asm:" docs/ README.md` and fix the live docs the same way: `docs/register-conventions.md:275` (`(DO)`'s `CALL rpush_bc`, cites 207, now at 202 before this edit) and `docs/throw-codes.md:190,448,524` (`?COMP`'s THROW: cites 20; the `JP w_THROW_cf.kernel_entry` is at 17). Leave `docs/shadow-register-followup-survey.md` alone: it is a dated survey record.
  - [x] 6.4 `docs/dev_journal.md:22`: ` - AGAIN ` → ` - AGAIN — RESOLVED 2026-MM-DD, Story 27.3` (strip the trailing space).
  - [x] 6.5 Leave the `src/system.asm` `env_table` CORE-EXT comment for Story 27.5. Run `make check-doc-sync`; it must pass.
- [x] **Task 7 — verify and record** (AC: 11, 12, 13)
  - [x] 7.1 `make`, `wc -c build/antforth.com`; record the delta against the budget table.
  - [x] 7.2 `make test`, `make test-repl`, `make test-repl-multitasker-demo`, `make test-repl-banking-23-6` (shares the guard `AGAIN` relies on) green; record the new PASS count.
  - [x] 7.3 If a banking probe now halts or times out, read `feedback_banking_probe_straddle_halt` first. +8 B is unlikely to move a probe body across `$8000`, but if it does, fix the probe, not the kernel.
  - [x] 7.4 Update memory `project_multitasker_pause_register_contract.md`: it says "`AGAIN` undefined → forever-loop = `BEGIN … 0 UNTIL`". Change to note `AGAIN` exists from v3.3.0 (and the MEMORY.md index line).
  - [x] 7.5 Write the S9 recipe into Dev Notes and post it in the review close message (draft in Dev Notes "S9 recipe").

## Dev Notes

### Design

`UNTIL` today (`src/control_flow.asm:92-107`):

```asm
w_UNTIL:
        DEFIMMED "UNTIL"
w_UNTIL_body:
w_UNTIL_cf EQU w_UNTIL_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( begin-addr -- )
        DW w_LIT_cf, w_QBRANCH_cf
        DW w_COMMA_cf                ; compile ?BRANCH
        DW w_HERE_cf                 ; ( begin-addr here ) here = offset cell addr
        DW w_MINUS_cf                ; ( begin-addr - here ) negative backward offset
        DW w_COMMA_cf                ; compile offset
        DW EXIT_CODE
```

`AGAIN`, inserted after it:

```asm
; -----------------------------------------------
; AGAIN ( begin-addr -- )  IMMEDIATE, compile-only
;   Compile BRANCH with backward offset to begin-addr
; -----------------------------------------------
w_AGAIN:
        DEFIMMED "AGAIN"
w_AGAIN_body:
w_AGAIN_cf EQU w_AGAIN_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( begin-addr -- )
        DW w_LIT_cf, w_BRANCH_cf
        DW w_COMMA_cf                ; compile BRANCH
        DW w_HERE_cf                 ; ( begin-addr here ) here = offset cell addr
        DW w_MINUS_cf                ; ( begin-addr - here ) negative backward offset
        DW w_COMMA_cf                ; compile offset
        DW EXIT_CODE
```

The offset is relative to the offset cell itself: `BRANCH` (`src/inner_interpreter.asm:283-292`) loads the cell at IP and adds it to IP. So `BEGIN AGAIN` with an empty body compiles `BRANCH -2` and `BRANCH` jumps to itself.

No CODE is added, so the register contract (DE = IP, BC = TOS) is unaffected. The compiled `BRANCH` + offset is position-independent, so banked colon bodies work with no banking change. `AGAIN` is a kernel word in fixed memory, findable from every bank.

A `BEGIN … AGAIN` loop is 2 B smaller per use than `BEGIN … 0 UNTIL` (no `LIT 0`) and skips the `LIT` + `?BRANCH` work each pass.

### `REPEAT` refactor (AC7)

`REPEAT` today (`src/control_flow.asm:127-147`) compiles `BRANCH` + backward offset and then resolves `WHILE`'s forward reference: the first half is `AGAIN`'s body and the second half is `THEN`'s body, line for line. ANS §6.1.2140 gives `REPEAT` as `POSTPONE AGAIN POSTPONE THEN`. New body:

```asm
w_REPEAT:
        DEFIMMED "REPEAT"
w_REPEAT_body:
w_REPEAT_cf EQU w_REPEAT_body - 3
        ; ( while-fwd begin-addr -- )
        DW w_AGAIN_cf                ; compile BRANCH back to begin-addr; ( while-fwd )
        DW w_THEN_cf                 ; resolve WHILE's forward reference; ( )
        DW EXIT_CODE
```

- Calling an IMMEDIATE colon word's cf from a thread just runs it; `AGAIN` and `THEN` both run `?COMP`, so `REPEAT` at the prompt still raises `-14` (from `AGAIN`'s check, before anything is compiled).
- Compile-time cost only (two extra nestings per `REPEAT` while compiling); no runtime change. NFR-P7-3 untouched.
- Same cells compiled: AC7's `_w` layout check pins it. Draft-time reading on the 31,009 B binary: `' W 3 + @` = `DUP`, `+5` = `?BRANCH`, `+7` = `8`, `+9` = `1-`, `+11` = `BRANCH`, `+13` = `-10`, `+15` = `EXIT`.
- Not done: the same trick on `ELSE` (its tail is `THEN`'s body; would save 8 B). Out of scope for an `AGAIN` story; note it in Completion Notes as a follow-up idea only.

This touches an existing word, which the epic didn't ask for. It is in the story because it is the same code, it is the ANS reference definition, and it more than pays for `AGAIN`. If the project lead prefers `AGAIN` alone, skip Task 2: the estimate becomes +28 B.

### Byte budget (itemised, est. +8 B net)

DEFWORD/DEFIMMED header (`src/macros.asm:98-133`): fat link 3 B + count/flags 1 B + name bytes + `JP DOCOL` 3 B. Each thread cell is 2 B.

| Item | Components | Bytes |
|---|---|---|
| `AGAIN` header | link 3 + count 1 + "AGAIN" 5 + `JP DOCOL` 3 | 12 |
| `AGAIN` body | `?COMP` 2 + `LIT` 2 + `BRANCH` xt 2 + `,` 2 + `HERE` 2 + `-` 2 + `,` 2 + `EXIT` 2 | 16 |
| `REPEAT` body, old | `?COMP` 2 + `LIT` 2 + `BRANCH` xt 2 + `,` 2 + `HERE` 2 + `-` 2 + `,` 2 + `HERE` 2 + `OVER` 2 + `-` 2 + `SWAP` 2 + `!` 2 + `EXIT` 2 = 26 | −26 |
| `REPEAT` body, new | `AGAIN` 2 + `THEN` 2 + `EXIT` 2 | +6 |
| **Net** | 28 − 20 | **+8** |

Epic estimate was ≈ 30 B for `AGAIN` alone; the itemised `AGAIN` is 28 B. Epic running total after this story: 76 (27.1) + 179 (27.2) + 8 = 263 B of the 500 B envelope. If the measured delta differs, explain it item by item (the symbol table gives `w_AGAIN` → `w_WHILE` spacing directly).

### Probe file (`tests/again_tests.fth`)

Draft; adjust names if they collide, keep the expected values. Tags `agX=` print with `.`, so each number has a trailing space; the Makefile asserts the whole line ending `$$`.

```forth
DECIMAL

\ --- Pre-flight: an undefined word raises -13 here and the verdicts go missing ---
' AGAIN DROP

\ --- AC1: exit by EXIT from inside the loop ---
: _a1 0 BEGIN 1+ DUP 5 = IF EXIT THEN AGAIN ;
." agA=" _a1 . CR

\ --- AC3: inside IF..THEN (taken / not taken) ---
: _a2 ( n -- m ) DUP 0> IF BEGIN 1- DUP 0= IF EXIT THEN AGAIN THEN 100 + ;
." agB=" 3 _a2 . -2 _a2 . CR

\ --- AC3: encloses DO..LOOP left by LEAVE (each pass adds 3; 0 3 6 9 12) ---
: _a3 0 BEGIN 10 0 DO I 3 = IF LEAVE THEN 1+ LOOP DUP 9 > IF EXIT THEN AGAIN ;
." agC=" _a3 . CR

\ --- AC3: BEGIN .. WHILE .. AGAIN THEN ---
: _a4 0 BEGIN DUP 4 < WHILE 1+ AGAIN THEN ;
." agD=" _a4 . CR

\ --- AC2: compiled cells. _a5 is never executed. ---
: _a5 BEGIN AGAIN ;
." agS=" ' _a5 3 + @ ' BRANCH = . ' _a5 5 + @ . CR

\ --- AC7: REPEAT still compiles ?BRANCH 8 .. BRANCH -10, and runs ---
: _w BEGIN DUP WHILE 1- REPEAT ;
." agR=" ' _w 7 + @ . ' _w 11 + @ ' BRANCH = . ' _w 13 + @ . 5 _w . CR
```

Then a computed depth line (`DEPTH 0=` → `PASS: ag-depth` / `FAIL: ag-depth`), as in `tests/comparison_tests.fth`. A leaked `LEAVE` frame in `_a3` would crash `EXIT` or trip the REPL `-274` return-stack check, so `agC=12` plus the depth line covers the return stack too.

Error cases, one per line:

```forth
AGAIN
: _u UNTIL ;
: _g AGAIN ;
```

→ one `error -14: interpreting a compile-only word`, then two `error -4: stack underflow` (parity, AC4). Verified for `UNTIL` on the 31,009 B binary.

Banked window top (AC6), last in the file because it switches banks. Self-calibrating from live `HERE` inside the definition, so it doesn't depend on where a bank's `HERE` starts. Verified at draft time with `UNTIL` in place of `AGAIN` (same two-cell shape): X and Y raised `-8`, Z printed `49152` and then `;`'s own guard raised `-8` on `EXIT`; `DEPTH` and `STATE` were 0 after each.

```forth
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK
1 BANK!  : _bx BEGIN [ $C000 HERE - 1 - ALLOT ] AGAIN ;
2 BANK!  : _by BEGIN [ $C000 HERE - 3 - ALLOT ] AGAIN ;
3 BANK!  : _bz BEGIN [ $C000 HERE - 4 - ALLOT ] AGAIN [ HERE U. ] ;
0 BANK!
```

- X: `HERE` = `$BFFF`; the `BRANCH` cell would cover `$BFFF..$C000` → `-8`.
- Y: `HERE` = `$BFFD`; `BRANCH` fits, the offset cell would cover `$BFFF..$C000` → `-8`.
- Z: `HERE` = `$BFFC`; both cells fit, ending at `$BFFF`; `HERE U.` prints `49152`; then `;` compiling `EXIT` raises `-8` (that is `;`'s guard, `src/compiler.asm:734`, not `AGAIN`'s).
- The `ALLOT` inside `[ … ]` leaves a gap in the half-built body. That is fine here: every case throws before `;` finishes, so none of these words is ever run. Don't copy this pattern into a word that runs.

Finish with a computed ALIVE line after `0 BANK!` (e.g. `." ag-alive=" 6 7 * . CR` → `ag-alive=42 `), which only real execution can produce.

### Makefile assertions

```
--count 1 '^error -14: interpreting a compile-only word' 'AGAIN at the prompt raises -14'
--count 2 '^error -4: stack underflow' 'UNTIL/AGAIN without BEGIN raise -4'
--count 2 '^error -8: dictionary overflow' 'banked AGAIN cell straddling $C000 raises -8'
--present '^49152 error -8: dictionary overflow' 'banked AGAIN ending at $BFFF accepted'
'agA=5 $$' 'agB=0 98 $$' 'agC=12 $$' 'agD=4 $$' 'agS=-1 -2 $$' 'agR=8 -1 -10 0 $$'
'PASS: ag-depth$$' 'ag-alive=42 $$'
```

Config flags before assertions (`tests/assert_verdicts.sh:17-36`). Check the `-4` count isn't polluted: the probe must not hit `-4` anywhere else. If the `$` in the label strings breaks the shell quoting, drop it from the label.

### Stale comments in tests

The epic says test files are not changed, so regression probes keep their shape. Four test files carry comments saying `AGAIN` is undefined: `tests/mutex_tests.fth:57`, `tests/mailbox_tests.fth:60`, `tests/multitasker_break_tests.fth:36`, `tests/throw_migration_tests.fth:388`; so does Makefile:8664. After this story those comments are false. This story fixes only the Makefile comment (Task 4.5; it is not a test file) and leaves the four test-file comments alone, as the epic says. Raise it in Completion Notes so the project lead can decide whether a comment-only sweep goes into 27.5.

### Testing standards

- Test through the Forth threading model, REPL-piped (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Verdict greps are column-0 anchored; echoed source starts with `."`, `:` or a word name, so it can't false-green. Runtime output lands at column 0 after the echo newline (checked at draft time).
- `IZCPM` is `iz-cpm-banking` (Makefile:19), so `BANK!`/`+BANK` work in a plain `test-repl` target.
- No probe may run an `AGAIN` loop that has no exit: the operator can't be broken out of a non-yielding loop (`docs/throw-codes.md:153-160`), so CI would hang until `PROBE_TIMEOUT` (30 s).
- If a number looks wrong, check BASE first (`project_hex_base_leak_literal_truncation`).

### Previous story (27.2) — what carries over

- The header formula gave exact estimates in both 27.1 (76/76) and 27.2 (179/179). Trust it, but measure.
- Probe/Makefile shape: `tests/comparison_tests.fth` + `test-repl-comparisons` (Makefile:667-676) is the template.
- Inserting words shifted `logic.asm:` citations, which 27.2 had to chase; the same happens here for `control_flow.asm:` (Task 6.3), and here the citations were already wrong.
- 27.2's S9 found a real bug outside the story (batnball's tick source). If S9 shows something unrelated, record it and file it; don't widen this story.

### Git intelligence

Last two commits: `35c096d feat: add <>, 0<>, 0>, U>, <= and >= (Story 27.2)`, `2868649 feat: add NIP, TUCK, -ROT and ? (Story 27.1)`. Message style: `feat: add AGAIN (Story 27.3)` plus a body line for the `REPEAT` change and the demo/doc switch. No Claude co-author trailer (`feedback_no_claude_coauthor`).

### S9 recipe (draft)

At the MicroBeast prompt (fresh boot):

1. Type the `_a1`…`_a4` definitions and their tag lines from `tests/again_tests.fth`. Expected `agA=5`, `agB=0 98`, `agC=12`, `agD=4`.
2. `AGAIN` alone → `error -14: interpreting a compile-only word`.
3. Copy the updated `disk/a/TRAFFIC.FTH` to the CP/M disk (check the trailing 0x1A survived). `INCLUDE TRAFFIC.FTH`, `TIMER-ON`, `' RUN-LIGHTS LIGHTS ACTIVATE`. Lights cycle red → red+amber → green → amber on tempo while the prompt stays live (`1 2 + .` → `3`). `.TASKS` shows both tasks AWAKE. `Ctrl-\` breaks the light task (`-28`), then `TIMER-OFF`.
4. Optional banked check on hardware: the three `_bx`/`_by`/`_bz` lines → two `error -8` lines and `49152 error -8`.

### Project Structure Notes

- Files touched: `src/control_flow.asm`, `tests/again_tests.fth` (new), `Makefile`, `disk/a/TRAFFIC.FTH`, `docs/phase6-multitasker.md`, `docs/throw-codes.md`, `docs/ans-forth-core-compliance.md`, `docs/register-conventions.md`, `docs/dev_journal.md`, `README.md`, this story file, `sprint-status.yaml`; memory file per Task 7.4.
- No architecture doc covers Phase 7; the epic's "Additional Requirements" are the constraints. No external libraries; no web research needed.

### References

- Epic: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — FR-P7-10, FR-P7-13, NFR-P7-1..7, Story 27.3 ACs, "`AGAIN` mirrors `UNTIL`", "Follow-on cleanup".
- `src/control_flow.asm:4-20` (`?COMP`), `:39-53` (`THEN`), `:80-107` (`BEGIN`, `UNTIL`), `:109-147` (`WHILE`, `REPEAT`).
- `src/inner_interpreter.asm:283-292` (`BRANCH`).
- `src/memory.asm:236-247` (`,` with `GUARD_BANKED_WRITE 2`); `src/macros.asm:146-161` (`GUARD_BANKED_WRITE`); `src/compiler.asm:734` (`;`'s guard).
- `tests/banking_tests_23_6.fth` (window-top probe pattern), `tests/comparison_tests.fth`, Makefile:667-676, :1950.
- `docs/ans-forth-core-compliance.md:78, 279-294, 387, 391, 419, 442`; `README.md:49`; `docs/dev_journal.md:22`.
- ANS Forth 1994 §6.2.0700 `AGAIN`, §6.1.2140 `REPEAT`, §3.2.3.2 (control-flow stack).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Pre-edit baseline (HEAD `35c096d`, re-measured): `build/antforth.com` = **31,009 B**; `make test-repl` = **1046 PASS / 0 FAIL / 2 SKIP**.
- Failing-first: `make test-repl-again` before `AGAIN` existed → every `AGAIN` line `error -13: undefined word`, verdicts missing, target exit 1.
- Negative check (Task 4.4): `'agA=4 $$'` → `FAIL: REPL AGAIN probe — expected 'agA=4 $' at column 0`; restored.
- After: **31,017 B**; `make test` PASS; `make test-repl` **1058 PASS / 0 FAIL / 2 SKIP** (+12, all from `test-repl-again`); `make test-repl-multitasker-demo` 4/4; `make test-repl-banking-23-6` PASS; `make check-doc-sync` 0 drift.

### Completion Notes List

- `AGAIN` added after `UNTIL` in `src/control_flow.asm` (DEFIMMED at line 113): `UNTIL`'s thread with `w_BRANCH_cf`. `REPEAT` now `AGAIN THEN EXIT` (Task 2 done; no veto received). Compiled cells unchanged: probe `agR=8 -1 -10 0`.
- **Budget: +8 B measured = +8 B estimated** (AGAIN header 12 + body 16 = 28; REPEAT body 26 → 6 = −20). Epic 27 running total 76 + 179 + 8 = 263 B of 500 B.
- Probe `tests/again_tests.fth` / `make test-repl-again` (12 verdicts): AC1 `agA=5`; AC3 `agB=0 98`, `agC=12`, `agD=4`; AC2 `agS=-1 -2 -1` (BRANCH, −2, and the EXIT cell compared against `;`'s own via `: _e ;` — `' EXIT` is the DEFCODE wrapper, not `EXIT_CODE`, so comparing to it gave 0); AC7 `agR`; depth; AC4/AC5 error counts (-14 ×1, -4 ×2); AC6 banked window top (-8 ×2 plus `49152 error -8`); computed alive witness.
- **Found an unrelated, older bug (filed OPEN in `docs/dev_journal.md`, not fixed here):** a word named `_by` defined in bank 2 at `$8000` makes `BANK!` unfindable from bank 3 (`0 BANK!` → `-13`). Reproduced on the pre-story 31,009 B binary with no `AGAIN` in play (`2 BANK! : _by 1 ; 3 BANK! 0 BANK!`). Name- and address-dependent (`_zz` fine; `_by` placed near `$BF9C` fine). The story's draft banked names `_bx/_by/_bz` hit it, so the probe uses `_wx/_wy/_wz` and says why in a comment. This needs its own story; it may affect any kernel word sharing a hash bucket with a banked word.
- **S9 recipe correction:** step 4 of the draft recipe uses `_bx`/`_by`/`_bz`; use `_wx`/`_wy`/`_wz` from the probe file instead, or the final `0 BANK!` will hit the bug above.
- `?COMP`'s THROW is at `control_flow.asm:18` (story said 17); `(DO)`'s `CALL rpush_bc` is at 208. Citations updated to those lines. All 15 §6.1 control-flow rows now cite their DEFIMMED/DEFCODE line.
- `docs/throw-codes.md` other rows cite `compiler.asm:` lines that are likely stale too; not checked, outside this story.
- Stale "AGAIN is undefined" comments in `tests/mutex_tests.fth`, `tests/mailbox_tests.fth`, `tests/multitasker_break_tests.fth` and `tests/throw_migration_tests.fth` were fixed at code review (comment-only).
- Follow-up idea only: `ELSE`'s tail is `THEN`'s body; the same reuse would save 8 B.
- **S9 on real MicroBeast 2026-10-08 (31,017 B, banner 22,999 B free, 12 banks): PASS.** Typed `_a1`..`_a4` + `_w` → `agA=5`, `agB=0 98`, `agC=12`, `agD=4`, `5 _w .` → `0`, `DEPTH` 0; `AGAIN` at the prompt → `error -14`. `TRAFFIC.FTH` (LED board not attached, so tempo not checked): `INCLUDE`, `TIMER-ON`, `' RUN-LIGHTS LIGHTS ACTIVATE` → prompt live (`1 2 + .` → `3`), `.TASKS` both AWAKE, `Ctrl-\` → `task 1: error -28`, task 1 SUSPENDED, `TIMER-OFF` ok. First attempt left out the `'`, so `RUN-LIGHTS` ran in the operator and never returned (expected: operator ignores break); reset and rerun was clean. Banked step 4 (`_wx`/`_wy`/`_wz`): `-8`, `-8`, `49152 -8`, then `0 BANK!` ok and `1 2 + .` → `3`, matching the emulator. The `BANK!` lookup bug also reproduces on hardware from a fresh boot (`_by` → `-13`; `_zz` → ok).
- Memory `project_multitasker_pause_register_contract.md` + MEMORY.md index updated (`AGAIN` exists from v3.3.0).

### File List

- `src/control_flow.asm` (modified)
- `tests/again_tests.fth` (new)
- `Makefile` (modified)
- `disk/a/TRAFFIC.FTH` (modified; trailing `0x0A 0x1A` preserved)
- `docs/phase6-multitasker.md` (modified)
- `docs/throw-codes.md` (modified)
- `docs/ans-forth-core-compliance.md` (modified)
- `docs/register-conventions.md` (modified)
- `docs/dev_journal.md` (modified)
- `README.md` (modified)
- `tests/mutex_tests.fth`, `tests/mailbox_tests.fth`, `tests/multitasker_break_tests.fth`, `tests/throw_migration_tests.fth` (comments only, at code review)
- `_bmad-output/implementation-artifacts/27-3-again.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- 2026-10-08: Added `AGAIN`; `REPEAT` reuses `AGAIN THEN` (+8 B, 31,017 B). New probe `test-repl-again`. `TRAFFIC.FTH` and multitasker/throw-code docs use `BEGIN … AGAIN`. Compliance doc §6.2 recount 22/24, control-flow citations fixed. Filed the cross-bank `BANK!` lookup bug in the dev journal.
- 2026-10-08: S9 hardware check passed (typed loops, `-14`, `TRAFFIC.FTH` as a background task with break, banked window top); `BANK!` lookup bug confirmed on hardware.
- 2026-10-08: Code review: no kernel defects. Fixed two test findings: `_wx`/`_wy` now print a `FAIL: ag-w*` witness after `AGAIN`, so the -8 count can no longer pass on `;`'s own -8 (checked by mutation); removed stale "AGAIN is undefined" comments from four test files. `make test-repl` 1058 PASS / 0 FAIL / 2 SKIP. Status → done.
