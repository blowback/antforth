# Story 27.4: `?DO`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer,
I want `?DO`,
so that a counted loop whose limit equals its start runs zero times instead of 65,536.

**Covers:** FR-P7-11, FR-P7-13 (part). Source: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` § "Story 27.4".

## Acceptance Criteria

1. **Behaviour (§6.2.0620).** `?DO ( n1|u1 n2|u2 -- ) ( R: -- loop-sys )` is IMMEDIATE and compile-only. With `: _q1 ( n -- count ) 0 SWAP 0 ?DO 1+ LOOP ;`, `0 _q1 .` `1 _q1 .` `5 _q1 .` print `0 1 5`.
2. **`+LOOP`.** `?DO … +LOOP` skips the body when limit = start, and otherwise gives the same results as `DO … +LOOP` for positive and negative steps (iteration counts and the `I` sequence).
3. **Inside the loop.** `LEAVE` (bare and inside `IF … THEN`), `UNLOOP EXIT`, `I`, and `J` across nested `?DO`/`DO` behave exactly as in a `DO` loop. A skipped `?DO` loop that contains a `LEAVE` exits through the same point.
4. **Balanced stacks.** After a skipped loop, a completed loop and a `LEAVE` exit, the data stack is balanced and no loop frame is left on the return stack: a word that runs a skipped `?DO` and then returns comes back normally, and the REPL `-274` return-stack check never fires during the probe.
5. **Structure.** `?DO` compiles `(?DO)` followed by one forward-branch cell. That cell starts the loop's LEAVE chain (`leave_chain_head`), so `LOOP`/`+LOOP` patch it to the loop exit with no change to `LOOP`, `+LOOP`, `(DO)`, `(LOOP)` or `(+LOOP)`. `: _qs ?DO LOOP ;` compiles exactly `(?DO) 6 (LOOP) -2 EXIT`; `: _ql ?DO LEAVE LOOP ;` has `12` in the `(?DO)` cell and `6` in `LEAVE`'s cell (checked by reading body cells; neither word is run).
6. **Runtime.** `(?DO)` is a DEFCODE word next to `(DO)`. On limit = start it drops limit and start and takes the inline offset (no loop frame pushed). Otherwise it steps IP past the offset cell and continues into `(DO)`'s frame-push code. It keeps DE = IP / BC = TOS as `BRANCH` and `(DO)` do, and uses no EXX. `(DO)` gains only a label (0 bytes); `DO`/`LOOP`/`+LOOP` runtime cost is unchanged (NFR-P7-3).
7. **Compile-only.** `?DO` typed at the prompt (`STATE` = 0) raises `-14` through `?COMP`, as `DO` does.
8. **Banked.** A `?DO` word defined in bank 1 runs correctly from bank 1 and from bank 0. In a banked definition the existing `GUARD_BANKED_WRITE` in `,` raises `-8` when the `(?DO)` cell or its offset cell would cross `$C000`, and accepts the case where the offset cell ends at `$BFFF`. No new guard code.
9. **Tests.** New REPL-piped probe `tests/qdo_tests.fth` plus Makefile target `test-repl-qdo`, a prerequisite of `test-repl` after `test-repl-again`, covering AC1–AC8. Probe lines ≤ 128 chars. The target was seen to fail before `?DO` existed.
10. **Docs sync.** In `docs/ans-forth-core-compliance.md` the `?DO` row (§6.2.0620) moves from "§6.2 Deliberately Omitted" to "§6.2 Implemented" in § order (between `<>` §6.2.0500 and `AGAIN` §6.2.0700), workaround note removed; every §6.2 count recounted from the rows (expected 23 implemented / 23 omitted); `README.md` 6.2 row matches; `control_flow.asm:` citations that moved are re-pointed. `docs/dev_journal.md` ` - ?DO ` marked resolved.
11. **Regression.** `make test` passes; `make test-repl` 0 FAIL with the baseline count plus the new probes, none removed; `make check-doc-sync` passes.
12. **Budget.** Real byte delta recorded and compared item by item with the estimate (+60 B).
13. **Hardware.** S9 smoke recipe run on real MicroBeast and posted in the closing review chat message.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 31,017 B (2026-10-08, HEAD `3b50b0c`, after Story 27.3) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (27.3 recorded 1058 PASS / 0 FAIL / 2 SKIP — re-measure).
- [x] Write the probe and Makefile target first; run `make test-repl-qdo` once to see it fail (pre-flight `' ?DO DROP` → `-13`, caught by `--fail-line`).

### Story tasks

- [x] **Task 1 — `(?DO)` in `src/control_flow.asm`** (AC: 1, 4, 6)
  - [x] 1.1 In `(DO)` (`w_PAREN_DO_cf`, DEFCODE at line 198), add a local label `.push_frame:` directly after `POP HL` and before the `DEC IX` pair. No other change to `(DO)`.
  - [x] 1.2 Insert `(?DO)` directly after `(DO)` (before the `(LOOP)` header comment). Code in Dev Notes "Design". The `JR` back to `w_PAREN_DO_cf.push_frame` must stay in range; it does if `(?DO)` sits right after `(DO)`.
- [x] **Task 2 — `?DO` in `src/control_flow.asm`** (AC: 1, 5, 7)
  - [x] 2.1 Insert DEFIMMED `?DO` directly after `DO` (before the `LOOP` header comment). Labels `w_QDO` / `w_QDO_body` / `w_QDO_cf EQU w_QDO_body - 3` (`feedback_defword_cf_label`). Code in Dev Notes.
  - [x] 2.2 Update the block comment above `LC@` (the "Compile-time data stack convention" list) to add `?DO ( -- do-addr old-lc )`, and say in one line that `?DO`'s skip cell is the first link of the new chain. No story/date provenance in source comments (`feedback_source_comment_discipline`).
- [x] **Task 3 — probe file `tests/qdo_tests.fth`** (AC: 1–8, 9). Content in Dev Notes "Probe file". Header comment in the style of `tests/again_tests.fth` (what it pins, column-0 anchoring, error counts, why the banked names were chosen). Start with `DECIMAL`. End with a plain `\n`, no 0x1A. No line over 128 chars (`feedback_tib_size_inline_comments`; the draft's longest line is 92).
- [x] **Task 4 — Makefile** (AC: 9, 11)
  - [x] 4.1 `QDO_PROBE = tests/qdo_tests.fth` after `AGAIN_PROBE` (Makefile:202).
  - [x] 4.2 Target `test-repl-qdo` after `test-repl-again` (Makefile:680-691), copying its recipe (timeout + straddle message, `sed 's/$$/\r/'`, `BYE`, `tests/assert_verdicts.sh`). Assertions in Dev Notes "Makefile assertions".
  - [x] 4.3 Add to `.PHONY` (line 56) and to the `test-repl:` prerequisites (Makefile:1963) after `test-repl-again`.
  - [x] 4.4 Run the target alone; then break one expectation (e.g. `'qdA=0 1 4 $$'`) to see it fail; restore.
- [x] **Task 5 — compliance doc, README, dev journal** (AC: 10)
  - [x] 5.1 Move the `?DO` row (`docs/ans-forth-core-compliance.md:442` today) into "§6.2 Implemented" between `<>` (§6.2.0500, line 399) and `AGAIN` (§6.2.0700, line 400), as `| §6.2.0620 | \`?DO ( n1 n2 -- )\` | Implemented | src/control_flow.asm:LINE | Story 27.4 | DEFIMMED; compiles \`(?DO)\` + a forward cell linked into the LEAVE chain. |` with LINE = `?DO`'s DEFIMMED line. The old workaround note goes with the old row (it was also wrong as written: `DO … LOOP` has to sit in the `ELSE` branch).
  - [x] 5.2 Recount `^| §6.2` rows in both tables (don't trust 23/23) and update: the summary table (line 78), the §6.2 paragraph (line 387; append `?DO` added by Story 27.4 to its "added by" list), the "§6.2 Implemented" heading (391) and "§6.2 Deliberately Omitted" heading (424). `README.md:49` → `23 / 46 (+ HOLDS) | ~50%` (or whatever the recount gives).
  - [x] 5.3 Inserting two words shifts every line below `(DO)`. Re-point the §6.1 Control Flow rows (`docs/ans-forth-core-compliance.md:279-294`) whose DEFIMMED/DEFCODE line moved (`DO`, `LOOP`, `+LOOP`, `LEAVE`, `UNLOOP`, `I`, `J`, `RECURSE`; `IF`…`REPEAT` stay put), and `docs/register-conventions.md:275` (`(DO)`'s `CALL rpush_bc`, 208 today, 209 after the label). Use `grep -n 'DEFIMMED\|DEFCODE' src/control_flow.asm` after the edit; then `grep -rn "control_flow.asm:" docs/ README.md` to confirm nothing else moved (`docs/throw-codes.md`'s `control_flow.asm:18` is above the edit). Leave `docs/shadow-register-followup-survey.md` alone (dated survey record).
  - [x] 5.4 `docs/dev_journal.md:21`: ` - ?DO ` → ` - ?DO — RESOLVED 2026-MM-DD, Story 27.4` (strip the trailing space).
  - [x] 5.5 Add the second instance of the open bank-lookup bug to the `docs/dev_journal.md` entry "2026-10-08 (OPEN) — a word defined in one bank can hide `BANK!` from another" (Dev Notes "Bank-lookup bug, second instance"). Don't fix it here.
  - [x] 5.6 Leave the `src/system.asm:576` `env_table` CORE-EXT comment for Story 27.5. Run `make check-doc-sync`; it must pass.
- [x] **Task 6 — verify and record** (AC: 11, 12, 13)
  - [x] 6.1 `make`, `wc -c build/antforth.com`; record the delta against the budget table.
  - [x] 6.2 `make test`, `make test-repl`, `make test-repl-banking-23-6` (shares the `,` guard) green; record the new PASS count.
  - [x] 6.3 If a banking probe halts or times out, read `feedback_banking_probe_straddle_halt` first. +60 B moves bank-0 `HERE` by 60 B; if a probe body now crosses `$8000`, fix the probe, not the kernel.
  - [x] 6.4 Write the S9 recipe into Dev Notes and post it in the review close message (draft in Dev Notes "S9 recipe").

## Dev Notes

### Design

How `DO`/`LEAVE`/`LOOP` work today (`src/control_flow.asm:156-191`, `:352-463`):

- `DO` compiles `(DO)`, pushes `do-addr` (= `HERE`, the loop body start) and `old-lc` (the outer loop's chain head) on the compile-time data stack, and sets `leave_chain_head` to 0.
- `LEAVE` compiles `UNLOOP BRANCH <cell>`, stores the current chain head in `<cell>`, and makes `<cell>` the new head. The chain is a linked list through the unpatched cells, ending in 0.
- `LOOP`/`+LOOP` compile the runtime + backward offset, then walk the chain and store `HERE - cell` into each cell (so a `BRANCH` reading that cell lands just after the loop), then restore `old-lc`.

`?DO` reuses this. It compiles `(?DO)` and one cell holding 0, makes that cell the head of the new chain, and returns `( do-addr old-lc )` like `DO`. Any `LEAVE` in the body links onto it, and `LOOP` patches it with the others. At run time, `(?DO)` either branches through that cell (skip) or steps over it and builds the loop frame. The skip path doesn't need `UNLOOP` because no frame was pushed.

`(?DO)`, inserted right after `(DO)`:

```asm
; -----------------------------------------------
; (?DO) ( limit start -- ) ( R: -- limit index | )
;   Runtime primitive. If limit = start, drop both and take the inline
;   forward offset past the loop; else skip the offset cell and run (DO).
; -----------------------------------------------
w_PAREN_QDO:
        DEFCODE "(?DO)", 0
w_PAREN_QDO_cf:
        POP     HL                   ; HL = limit
        OR      A
        SBC     HL, BC               ; Z if limit = start
        ADD     HL, BC               ; HL = limit again; Z unchanged
        JR      NZ, .qdo_enter
        POP     BC                   ; drop limit and start
        JP      w_BRANCH_cf          ; DE = IP at the offset cell
.qdo_enter:
        INC     DE
        INC     DE                   ; IP past the offset cell
        JR      w_PAREN_DO_cf.push_frame
```

- `ADD HL,BC` leaves Z alone on the Z80 (it sets only H, N and C), so the `SBC` result survives the restore.
- On entry DE = IP points at the offset cell, which is what `BRANCH` (`src/inner_interpreter.asm:283-292`) expects: it adds the cell's value to the cell's own address.
- On the run path HL = limit and BC = start, the state `(DO)` is in right after its own `POP HL`, so jumping to `.push_frame` is exact.
- `.push_frame` is a local label inside `w_PAREN_DO_cf`; reach it as `w_PAREN_DO_cf.push_frame` (same pattern as `w_THROW_cf.kernel_entry`).
- No underflow check, matching `(DO)` (neither checks today). Story 27.6's audit decides that for both.

`?DO`, inserted right after `DO`:

```asm
; -----------------------------------------------
; ?DO ( -- do-addr old-lc )  IMMEDIATE, compile-only
;   Compile (?DO) + a forward-offset cell that starts this loop's LEAVE
;   chain, so LOOP/+LOOP patch it to the loop exit like any LEAVE.
; -----------------------------------------------
w_QDO:
        DEFIMMED "?DO"
w_QDO_body:
w_QDO_cf EQU w_QDO_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_LIT_cf, w_PAREN_QDO_cf
        DW w_COMMA_cf                ; compile (?DO)
        DW w_HERE_cf                 ; ( skip-cell )
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile 0 = end of this loop's LEAVE chain
        DW w_HERE_cf                 ; ( skip-cell do-addr )
        DW w_LCFETCH_cf              ; ( skip-cell do-addr old-lc )
        DW w_ROT_cf                  ; ( do-addr old-lc skip-cell )
        DW w_LCSTORE_cf              ; chain head = skip-cell; ( do-addr old-lc )
        DW EXIT_CODE
```

`?COMP` runs first, so `?DO` at the prompt throws before anything is compiled. Both new words are kernel words in fixed memory, findable from every bank. The compiled offset is relative, so banked bodies need no banking change.

**Draft-time prototype (2026-10-08).** This exact code was built in a scratch copy of HEAD `3b50b0c`: 31,077 B (+60), `make test-repl` 1058 PASS / 0 FAIL / 2 SKIP (same count as before, nothing broken), and the probe file below passed every assertion; on the unmodified 31,017 B binary it fails as expected. The dev pass still has to do and measure it for real.

Not chosen:
- `(?DO) <cell> (DO)` (a separate `(DO)` cell after the skip cell): about 2 B less kernel code but 2 B more per `?DO` use and an extra dispatch per loop entry.
- Comparing bytes with `LD A,L / CP C / JR NZ / LD A,H / CP B / JR NZ`: 8 B vs 6 B for `OR A / SBC / ADD / JR NZ`.
- Inlining `BRANCH`'s 12 B on the skip path instead of `JP w_BRANCH_cf` (3 B): saves 10 T-states only when the loop is skipped.

**Stale chain after an aborted compile.** If a definition aborts after `?DO` (as the `_wz` probe case does: `;` throws `-8`), `leave_chain_head` keeps pointing at the abandoned cell. `DO` has the same property today. It's harmless: the next `DO`/`?DO` saves it and `LOOP` restores it without walking it. Not in scope.

### Byte budget (itemised, est. +60 B)

DEFCODE header: fat link 3 B + count/flags 1 B + name bytes. DEFIMMED adds `JP DOCOL` 3 B. Thread cells are 2 B.

| Item | Components | Bytes |
|---|---|---|
| `(?DO)` header | link 3 + count 1 + "(?DO)" 5 | 9 |
| `(?DO)` code | `POP HL` 1 + `OR A` 1 + `SBC HL,BC` 2 + `ADD HL,BC` 1 + `JR NZ` 2 + `POP BC` 1 + `JP` 3 + `INC DE` ×2 2 + `JR` 2 | 15 |
| `.push_frame` label in `(DO)` | — | 0 |
| `?DO` header | link 3 + count 1 + "?DO" 3 + `JP DOCOL` 3 | 10 |
| `?DO` body | `?COMP` 2 + `LIT (?DO)` 4 + `,` 2 + `HERE` 2 + `LIT 0` 4 + `,` 2 + `HERE` 2 + `LC@` 2 + `ROT` 2 + `LC!` 2 + `EXIT` 2 | 26 |
| **Total** | | **60** |

Epic estimate was ≈ 70 B. Epic running total after this story: 76 (27.1) + 179 (27.2) + 8 (27.3) + 60 = 323 B of the 500 B envelope. If the measured delta differs, explain it item by item from the symbol table.

**Cost.** `DO`, `LOOP`, `+LOOP` and their runtimes are untouched (NFR-P7-3). A `?DO` loop that runs pays about 76 T-states once on entry over `DO` (`POP HL` 10 + `OR A` 4 + `SBC` 15 + `ADD` 11 + `JR` taken 12 + `INC DE` ×2 12 + `JR` 12), and nothing per pass.

### Probe file (`tests/qdo_tests.fth`)

Verified at draft time against the prototype (all assertions pass) and against HEAD (fails). Add a header comment like `tests/again_tests.fth`'s. Tags print with `.`, so each number has a trailing space.

```forth
DECIMAL

\ --- Pre-flight: an undefined word raises -13 here and the verdicts go missing ---
' ?DO DROP

\ --- Zero, one and five passes ---
: _q1 ( n -- count ) 0 SWAP 0 ?DO 1+ LOOP ;
." qdA=" 0 _q1 . 1 _q1 . 5 _q1 . CR

\ --- With +LOOP, positive step: skip when equal; else same count as DO ---
: _q2 ( lim start -- n ) 0 -ROT ?DO 1+ 2 +LOOP ;  : _d2 0 -ROT DO 1+ 2 +LOOP ;
." qdB=" 5 5 _q2 . 10 0 _q2 . 10 0 _d2 . 9 0 _q2 . 9 0 _d2 . CR

\ --- With +LOOP, negative step ---
: _q3 ( lim start -- n ) 0 -ROT ?DO 1+ -2 +LOOP ;  : _d3 0 -ROT DO 1+ -2 +LOOP ;
." qdC=" 7 7 _q3 . 0 10 _q3 . 0 10 _d3 . -1 10 _q3 . -1 10 _d3 . CR

\ --- Same index sequence as DO; the skipped call prints nothing ---
: _q4 ?DO I . 3 +LOOP ;  : _d4 DO I . 3 +LOOP ;
." qdI=" 10 1 _q4 4 4 _q4 10 1 _d4 CR

\ --- LEAVE, bare and inside IF..THEN, including a skipped loop that holds a LEAVE ---
: _q5 0 10 0 ?DO 1+ LEAVE LOOP ;
: _q7 ( n -- c ) 0 SWAP 0 ?DO I 3 = IF LEAVE THEN 1+ LOOP ;
." qdD=" _q5 . 0 _q7 . 10 _q7 . 2 _q7 . CR

\ --- UNLOOP EXIT ---
: _q8 ( lim -- x ) 0 ?DO I 4 = IF I UNLOOP EXIT THEN LOOP -1 ;
." qdE=" 10 _q8 . 0 _q8 . CR

\ --- Nesting: ?DO in ?DO with J; skipped ?DO inside DO; DO inside ?DO with J ---
: _q9 0 3 0 ?DO 2 0 ?DO J 10 * I + + LOOP LOOP ;
: _qa 0 3 0 DO 0 0 ?DO 99 + LOOP I + LOOP ;  : _qb 0 3 0 ?DO 2 0 DO J + LOOP LOOP ;
." qdF=" _q9 . _qa . _qb . CR

\ --- A skipped loop pushes no frame: EXIT after it returns normally ---
: _qc 0 0 ?DO LOOP 7 ;  : _qd 5 5 ?DO 1 +LOOP 8 ;
." qdG=" _qc . _qd . CR

\ --- Compiled cells. _qs and _ql are never executed ---
: _qs ?DO LOOP ;  : _ql ?DO LEAVE LOOP ;
." qdS=" ' _qs 3 + @ ' (?DO) = . ' _qs 5 + @ . ' _qs 9 + @ . ' _ql 5 + @ . ' _ql 11 + @ . CR

\ --- Every case above left the data stack balanced ---
: _dep ( -- ) DEPTH 0= IF ." PASS: qd-depth" ELSE ." FAIL: qd-depth" THEN CR ;
_dep

\ --- Error: -14 once ---
?DO

\ --- Banked: a ?DO word in bank 1 runs from bank 1 and from bank 0 ---
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK
1 BANK!  : _bq ( n -- c ) 0 SWAP 0 ?DO I 3 = IF LEAVE THEN 1+ LOOP ;
." qdK=" 0 _bq . 10 _bq . 2 _bq . CR
0 BANK!  ." qdL=" 0 _bq . 10 _bq . 2 _bq . CR

\ --- Banked window top: X and Y cross $C000 (-8); Z ends at $BFFF ---
1 BANK!  : _wx [ $C000 HERE - 1 - ALLOT ] ?DO [ ." FAIL: qd-wx" ] ;
2 BANK!  : _wy [ $C000 HERE - 3 - ALLOT ] ?DO [ ." FAIL: qd-wy" ] ;
3 BANK!  : _wz [ $C000 HERE - 4 - ALLOT ] ?DO [ HERE U. ] ;
0 BANK!

\ --- Computed witness: only real execution prints 42 and 4 ---
: _qe 0 4 0 ?DO 1+ LOOP ;
." qd-alive=" 6 7 * . _qe . CR
```

What the cases pin:

- `qdA=0 1 5` — AC1.
- `qdB=0 5 5 5 5`, `qdC=0 6 6 6 6` — AC2: first number is the skip, then `?DO` and `DO` side by side (step 2 and −2, limits that do and don't land on a multiple of the step).
- `qdI=1 4 7 1 4 7` — AC2: same `I` sequence; `4 4 _q4` prints nothing.
- `qdD=1 0 3 2` — AC3: bare `LEAVE`; `0 _q7` is the skipped loop that holds a `LEAVE` (two cells on the chain, both patched).
- `qdE=4 -1` — AC3: `UNLOOP EXIT`, and the skip path falling through to `-1`.
- `qdF=63 3 6` — AC3: `J` in `?DO`/`?DO`; a skipped `?DO` inside `DO` (a leaked frame would break the outer `I`); `J` in `DO` inside `?DO`.
- `qdG=7 8` — AC4: a frame pushed on the skip path would make `EXIT` return into the loop data and crash.
- `qdS=-1 6 -2 12 6` — AC5: `_qs` body is `(?DO) 6 (LOOP) -2 EXIT`; `_ql` is `(?DO) 12 UNLOOP BRANCH 6 (LOOP) -8 EXIT`.
- `qdK=0 3 2`, `qdL=0 3 2` — AC8: banked word run from its own bank and from bank 0.
- `_wx`/`_wy` — `(?DO)` cell at `$BFFF`, and offset cell at `$BFFF`: `-8` from `,` inside `?DO`. The witness after `?DO` prints only if `?DO` did not throw; without it, the `-8` from `;` would satisfy the count on its own.
- `_wz` — both cells fit, `HERE` = `$C000`, prints `49152`, then `;`'s own guard raises `-8` on `EXIT`.
- The `[ … ALLOT ]` trick leaves a gap in a half-built body; fine here because every such word throws before `;` finishes and is never run. Don't copy it into a word that runs.

### Makefile assertions

```
--fail-line '^FAIL: qd-|^error -13|^error -274'
--count 1 '^error -14: interpreting a compile-only word' '?DO at the prompt raises -14'
--count 2 '^error -8: dictionary overflow' 'banked ?DO cell crossing C000 raises -8'
--present '^49152 error -8: dictionary overflow' 'banked ?DO ending at BFFF accepted'
'qdA=0 1 5 $$' 'qdB=0 5 5 5 5 $$' 'qdC=0 6 6 6 6 $$' 'qdI=1 4 7 1 4 7 $$' 'qdD=1 0 3 2 $$'
'qdE=4 -1 $$' 'qdF=63 3 6 $$' 'qdG=7 8 $$' 'qdS=-1 6 -2 12 6 $$' 'PASS: qd-depth$$'
'qdK=0 3 2 $$' 'qdL=0 3 2 $$' 'qd-alive=42 4 $$'
```

- `--fail-line` is one ERE (`tests/assert_verdicts.sh:72-75` uses `grep -E`). The `-13` arm catches a missing `?DO` and the bank-lookup bug below; the `-274` arm catches a leaked loop frame at interpret level (AC4).
- `--count N` means at least N (`tests/assert_verdicts.sh:77-83`), so the counts don't catch extra errors; the `-13`/`-274` tripwire and the per-tag lines do.
- Config flags (`--label`, `--fail-line`) before assertions. Label `"REPL ?DO probe"`. Keep `$` out of the label strings (27.3 dropped it for shell quoting).

### Bank-lookup bug, second instance

While drafting, the first probe draft named the banked word `_qk`. Defining it in bank 1 hides `CR` from banks 2 and 3; reproduced on the unmodified HEAD `3b50b0c` binary (31,017 B), no `?DO` involved:

```forth
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK
1 BANK! : _qk 1 ;
2 BANK!
CR             \ CR ?  error -13: undefined word
```

It also fails from bank 3, and after `0 BANK!` from bank 3. `_zz` in the same place is fine. This is the bug already filed OPEN in `docs/dev_journal.md` ("a word defined in one bank can hide `BANK!` from another"), and it confirms that entry's guess that kernel words other than `BANK!` are exposed. Task 5.5 adds this repro to that entry. The probe uses `_bq`, which doesn't trigger it; the `-13` tripwire will flag it if a later layout change makes `_bq` or `_qe` collide.

### Testing standards

- Test through the Forth threading model, REPL-piped (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Verdict greps are column-0 anchored; echoed source starts with `."`, `:` or a word name, so it can't false-green.
- `IZCPM` is `iz-cpm-banking` (Makefile:19), so `BANK!`/`+BANK` work in a plain `test-repl` target.
- Bank-0 colon bodies in the probe add roughly 700 B on top of `HERE` ≈ 31,330 at the probe's start; they stay below `$8000` (32,768). If that changes, see `feedback_banking_probe_straddle_halt`.
- No loop in the probe may run 65,536 times by accident (a `DO` with equal limits does; that is the bug `?DO` fixes). Every `DO` in the probe has distinct limits.
- If a number looks wrong, check BASE first (`project_hex_base_leak_literal_truncation`).

### Previous story (27.3) — what carries over

- The header formula gave exact estimates in 27.1 (76/76), 27.2 (179/179) and 27.3 (8/8). The prototype here measured 60/60.
- Probe/Makefile shape: `tests/again_tests.fth` + `test-repl-again` (Makefile:680-691) is the template, including the banked window-top block and the `FAIL:` witness after the word under test.
- 27.3 hit the bank-lookup bug with `_by`; this story hit it with `_qk`. Pick banked probe names, run, and if `-13` appears, rename and add the case to the dev-journal entry rather than chasing it.
- 27.3 noted `ELSE` could reuse `THEN` (8 B). Still out of scope.

### Git intelligence

Last three commits: `3b50b0c feat: add AGAIN (Story 27.3)`, `35c096d feat: add <>, 0<>, 0>, U>, <= and >= (Story 27.2)`, `2868649 feat: add NIP, TUCK, -ROT and ? (Story 27.1)`. Message style: `feat: add ?DO (Story 27.4)`. No Claude co-author trailer (`feedback_no_claude_coauthor`).

### S9 recipe (draft)

At the MicroBeast prompt (fresh boot):

1. Type `_q1`, `_q2`/`_d2`, `_q7`, `_q8`, `_q9`/`_qa`/`_qb`, `_qc`/`_qd` and their tag lines from `tests/qdo_tests.fth`. Expected `qdA=0 1 5`, `qdB=0 5 5 5 5`, `qdD=1 0 3 2`, `qdE=4 -1`, `qdF=63 3 6`, `qdG=7 8`; `DEPTH .` → `0`.
2. `?DO` alone → `error -14: interpreting a compile-only word`.
3. Banked: the `BANKS-CLEAR … +BANK` line, then the `_bq` lines → `qdK=0 3 2`, `qdL=0 3 2`.
4. The three `_wx`/`_wy`/`_wz` lines → `error -8`, `error -8`, `49152 error -8`; then `0 BANK!` and `1 2 + .` → `3`.

### Project Structure Notes

- Files touched: `src/control_flow.asm`, `tests/qdo_tests.fth` (new), `Makefile`, `docs/ans-forth-core-compliance.md`, `docs/register-conventions.md`, `docs/dev_journal.md`, `README.md`, this story file, `sprint-status.yaml`.
- No architecture doc covers Phase 7; the epic's "Additional Requirements" are the constraints ("`?DO` must use the existing LEAVE chain"). No external libraries; no web research needed.

### References

- Epic: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — FR-P7-11, FR-P7-13, NFR-P7-1..7, Story 27.4 ACs, "`?DO` must use the existing LEAVE chain".
- `src/control_flow.asm:4-20` (`?COMP`), `:156-191` (LEAVE-chain notes, `LC@`, `LC!`, `leave_chain_head`), `:193-210` (`(DO)`), `:212-312` (`(LOOP)`, `(+LOOP)`), `:314-349` (`UNLOOP`, `I`, `J`), `:351-367` (`DO`), `:369-441` (`LOOP`, `+LOOP`), `:443-463` (`LEAVE`).
- `src/inner_interpreter.asm:230-235` (`rpush_bc`), `:283-292` (`BRANCH`); `src/macros.asm:32-46` (`NEXT`, `NEXTHL`), `:101-133` (DEFWORD/DEFIMMED), `:146-161` (`GUARD_BANKED_WRITE`).
- `tests/again_tests.fth`, Makefile:202, :680-691, :1963; `tests/assert_verdicts.sh:17-36, 70-90`.
- `docs/ans-forth-core-compliance.md:78, 279-294, 387, 391, 399-400, 424, 442`; `README.md:49`; `docs/dev_journal.md:21, 28-58`; `docs/register-conventions.md:275`.
- ANS Forth 1994 §6.2.0620 `?DO`, §6.1.1240 `DO`, §6.1.1760 `LEAVE`, §3.2.3.2 (control-flow stack).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (HEAD `3b50b0c`, re-measured): `build/antforth.com` 31,017 B; `make test-repl` 1058 PASS / 0 FAIL / 2 SKIP.
- Red: `make test-repl-qdo` on the 31,017 B binary failed every tag assertion (pre-flight `' ?DO DROP` → `-13`, caught by `--fail-line`). Mutating `'qdA=0 1 5 $$'` to `0 1 4` failed the target; restored.
- `test-repl-banking-23-6` hung on the 31,077 B binary (no timeout on that target), passed on 31,017 B. Bisected to cases F+G: bank-0 `42 VALUE B0` at `$BFFD`, then bank 6 driven to the brink → next `CR` lookup never returns. Name-dependent (`ZZ`/`Q7`/`F0` fine) — third instance of the open bank-lookup bug in `docs/dev_journal.md`. Fixed the probe (renamed `B0` → `F0`), recorded the repro; kernel unchanged.

### Completion Notes List

- `(?DO)` (DEFCODE, `src/control_flow.asm:220`) and `?DO` (DEFIMMED, `:397`) implemented exactly as designed; `(DO)` gained only the `.push_frame` label. `DO`/`LOOP`/`+LOOP`/`(DO)`/`(LOOP)`/`(+LOOP)` code unchanged.
- **Bytes: 31,017 → 31,077 B = +60, matching the itemised estimate (9 + 15 + 0 + 10 + 26).** Epic 27 running total 76 + 179 + 8 + 60 = 323 B of 500.
- Tests: `tests/qdo_tests.fth` + `test-repl-qdo` (prerequisite of `test-repl` after `test-repl-again`), 16 assertions plus the `-13`/`-274`/`FAIL: qd-` tripwire, covering AC1–AC8. Longest probe line 92 chars.
- Regression: `make test` PASS; `make test-repl` 1074 PASS / 0 FAIL / 2 SKIP (1058 + 16 new, none removed); `test-repl-banking` (57 PASS), `-23-6`, `-23-7`, `-23-9`, `test-straddle-regression`, `lint-banking-probes`, `test-file-sanity` all green; `make check-doc-sync` 0 drift.
- Docs: `?DO` row moved into §6.2 Implemented (between `<>` and `AGAIN`); recount from rows = 23 implemented / 23 omitted, summary/paragraph/headings/README updated (`23 / 46 (+ HOLDS) | 50%`). §6.1 Control Flow rows re-pointed (`DO` 379, `LOOP` 418, `+LOOP` 457, `I` 354, `J` 366, `LEAVE` 495, `UNLOOP` 341, `RECURSE` 516); `register-conventions.md` `(DO)` `CALL rpush_bc` → 210 (the extra comment line in the LC@ block moves it 2, not 1). Dev journal: `?DO` resolved; second (`_qk`/`CR`) and third (`B0`/`CR` hang) bank-lookup instances added.
- Not in this story: the bank-lookup bug itself (OPEN; now three instances, one of which hangs), `env_table` comment (27.5), underflow checks in `(DO)`/`(?DO)` (27.6).
- AC13 (hardware) PASS 2026-10-11 on MicroBeast, 31,077 B binary: every step of the UAT worklist matched (`0 1 5`, `0 5 5 5 5`, `0 6 6 6 6`, `1 4 7 1 4 7`, `1 0 3 2`, `4 -1`, `63 3 6`, `7 8`, `DEPTH` 0, `-1 6 -2 12 6`, `-14`, `0 3 2` ×2, `-8` ×2, `49152 -8`, `3`). Optional step 5: the `B0`/`CR` bank-lookup hang also reproduces on hardware (prints `3`, `CR` never returns).

**S9 recipe (MicroBeast, fresh boot, 31,077 B binary):**

1. Type `_q1`, `_q2`/`_d2`, `_q7`, `_q8`, `_q9`/`_qa`/`_qb`, `_qc`/`_qd` and their tag lines from `tests/qdo_tests.fth`. Expect `qdA=0 1 5`, `qdB=0 5 5 5 5`, `qdD=1 0 3 2` (needs `_q5` too), `qdE=4 -1`, `qdF=63 3 6`, `qdG=7 8`; then `DEPTH .` → `0`.
2. `?DO` alone → `error -14: interpreting a compile-only word`.
3. `BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK`, then the `_bq` lines → `qdK=0 3 2`, `qdL=0 3 2`.
4. The three `_wx`/`_wy`/`_wz` lines → `error -8`, `error -8`, `49152 error -8`; then `0 BANK!` and `1 2 + .` → `3`.
5. Optional (bank-lookup bug on hardware): fresh boot, the 7-bank `BANKS-CLEAR … +BANK` line, `0 BANK!  $C000 HERE - 3 - ALLOT`, `42 VALUE B0`, `6 BANK!  $C000 HERE - 2 - ALLOT`, `CR` → hangs in the emulator; record whether hardware does too.

### File List

- `src/control_flow.asm` — `(?DO)`, `?DO`, `.push_frame` label in `(DO)`, LC@ block comment
- `tests/qdo_tests.fth` — new probe
- `tests/banking_tests_23_6.fth` — case F word renamed `B0` → `F0` (bank-lookup bug workaround), comment
- `Makefile` — `QDO_PROBE`, `test-repl-qdo`, `.PHONY`, `test-repl` prerequisite
- `docs/ans-forth-core-compliance.md` — `?DO` row moved, counts, §6.1 line re-points
- `docs/register-conventions.md` — `(DO)` line re-point
- `docs/dev_journal.md` — `?DO` resolved; bank-lookup bug instances 2 and 3
- `README.md` — §6.2 coverage row
- `_bmad-output/implementation-artifacts/27-4-question-do.md` — this file
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status

## Change Log

- 2026-10-08 — Story 27.4 implemented: `?DO` + `(?DO)` (+60 B), `test-repl-qdo` probe, docs synced; 23-6 probe word renamed after the bank-lookup bug hung it. Status → review.
