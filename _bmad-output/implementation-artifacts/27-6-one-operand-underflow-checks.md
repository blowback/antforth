# Story 27.6: Underflow checks on one-operand words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer,
I want every word that takes stack items to raise `-4` when they aren't there,
so that a stack bug fails loudly at the word that caused it instead of computing on a stale register.

**Covers:** FR-P7-14; NFR-P7-4. Source: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` § "Story 27.6".

**Scope note.** The title says "one-operand", but FR-P7-14 says *every* kernel word that consumes stack items, and the draft-time audit (Dev Notes "Audit") found 2- and 3-cell CODE words with no check too (`TYPE`, `FILL`, `MOVE`, `ACTIVATE`, `(DO)`), plus two words whose check is one cell short (`SET-ORDER`, `RESTORE-INPUT`). All of them are in scope. The epic's ≈ 60 B (≈ 20 × 3 B) was based on the 2026-10-08 sample; the audit gives ≈ 55 sites. See "Byte budget" for the estimate.

**Project-lead decisions (2026-10-11):** (1) full coverage is accepted even though it takes Epic 27 past the 500 B envelope, and none of the byte-saving options M/P/A is taken; (2) the `>NUMBER` cell-order bug found by the audit is fixed in this story (AC14), not filed separately.

## Acceptance Criteria

1. **Audit recorded.** The audit table in Dev Notes lists every kernel word that consumes one or more stack items, with its check before the story (none / `check_underflow*` / inherited / partial) and the action taken. The dev pass re-verifies each row against the source at dev time (the draft was made at HEAD `09b3c00`, 31,077 B), corrects any row that is wrong, and fills in the "after" line numbers where they matter.
2. **Unchecked words raise `-4`.** Every word marked `+1`/`+2`/`+3`/`+U` in the audit raises `-4` when run with too few items, through `check_underflow`, `_2`, `_3` or `_4` (or `check_underflow_u` for `PICK`/`ROLL`, which jumps to the same `do_underflow_error`). The check is the first thing the word does, before any side effect (memory write, output, bank switch, `break_pending` clear, header build, input parse).
3. **`DUP`.** `DUP` on an empty stack raises `-4` and `DEPTH` stays 0 (`' DUP CATCH . DEPTH .` prints `-4 0`).
4. **Short checks fixed.** `SET-ORDER` checks n+1 cells (n wids plus the cell that becomes the new TOS), so `1 SET-ORDER` on an otherwise empty stack raises `-4` and leaves the search order unchanged. `RESTORE-INPUT` raises `-4` on an empty stack, and on the count = 4 path checks for all five cells (`1 2 3 4 RESTORE-INPUT` raises `-4`).
5. **Colon words.** A colon word in the audit marked "prefix" gets a guard as its first cell, so it raises `-4` before its first side effect: `ACCEPT` and `POST` `(?2)`; `SEMAPHORE` a 1-cell guard before `CREATE`. Colon words marked "inherits" raise `-4` once the words they start with are checked (`ABS`, `TO`, `WAIT`, `LOCK`, `FETCH`, `SIGNAL`).
6. **Assembler.** Each assembler mnemonic that takes operands raises `-4` when fewer cells are present than the form it is assembling needs, with `-270` (not in `CODE`) still taking priority. Zero-operand mnemonics (`NOP,`, `RET,`, `LDIR,` …) still work on an empty stack.
7. **Hot-path cost stated.** The story records the T-state cost added per call for `DUP`, `0=`, `1+`, `1-`, `C@`, `>R`, `?BRANCH`, `EXECUTE`, `(+LOOP)` and the per-token cost added to `INTERPRET`. No kernel word gets an unchecked entry point unless that per-token figure says it is needed; if one is added, the story says which word, why, and which kernel threads use it.
8. **Exemptions stated.** Every word that consumes stack items but stays unchecked is listed in the audit with the reason (headerless helper with a fixed caller, test-build-only, internal error path).
9. **Tests.** New REPL-piped probe `tests/underflow_tests.fth` plus Makefile target `test-repl-underflow`, a prerequisite of `test-repl` after `test-repl-qdo`. It covers an empty-stack case (and a one-short case for 2- and 3-cell words) for every newly checked word, at interpret level and inside a colon body (the runtime words `?BRANCH`, `(DO)`, `(?DO)`, `(+LOOP)`, `(ABORT")`, `(TO)` only through the colon words that compile them: `IF`, `DO`, `?DO`, `+LOOP`, `ABORT"`, `TO`), plus AC3, AC4, AC5 and a sample of AC6 forms. Probe lines ≤ 128 chars. The target was seen to fail on the unmodified binary.
10. **Regression.** `make test` passes; `make test-repl` 0 FAIL with the 1074 baseline plus the new probes, none removed; `make check-doc-sync` passes.
11. **Docs.** The `docs/dev_journal.md` entry "2026-10-08 (OPEN, Story 27.6) — one-operand words don't check for underflow" is marked resolved, with the real per-call cost (94 T-states, not "about 50"). The `0<>` row note in `docs/ans-forth-core-compliance.md` ("unlike `0=`, which has no check") is corrected. The stale underflow comments on `D.R` and `U.R` in `src/formatting.asm` are corrected. The `>NUMBER` bug gets a dev-journal entry recorded as found and fixed in this story.
12. **Budget.** The real byte delta is recorded and compared item by item with the estimate in "Byte budget", with the epic running total and the stated reason for exceeding the 500 B envelope (NFR-P7-2).
13. **Hardware.** S9 smoke recipe run on real MicroBeast and posted in the closing review chat message.
14. **`>NUMBER` cell order (§6.1.0570).** `>NUMBER` reads ud1 with the high cell nearer the top (§3.1.4.1), so accumulation continues from a nonzero ud1: `DECIMAL 1 0 S" 0" >NUMBER 2DROP D.` prints `10`, `0 1 S" 0" >NUMBER 2DROP D.` prints `655360`, `65535 0 S" 0" >NUMBER 2DROP D.` prints `655350`. The existing `0 0` cases (`tests/double_tests.fth:103-125`, REPL tests 439–442) still pass. Covered by the new probe file.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 31,077 B (2026-10-11, HEAD `09b3c00`) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (draft-time: 1074 PASS / 0 FAIL / 2 SKIP — re-measure).
- [x] Write the probe and Makefile target first; run `make test-repl-underflow` once to see it fail (e.g. `uA=` shows `0 1` for `DUP` instead of `-4 0`).

### Story tasks

- [x] **Task 1 — re-verify the audit** (AC: 1, 8)
  - [x] 1.1 Walk every `DEFCODE`/`DEFWORD`/`DEFIMMED` in `src/*.asm` against the audit table. Fix rows that are wrong; add any word missing. Keep the table in this file current as you go.
  - [x] 1.2 Confirm the "Exempt" rows still hold (fixed caller, not user-callable or test-build only).
- [x] **Task 2 — 1-cell CODE words** (AC: 2, 3) — add `CALL check_underflow` as the first instruction of each `+1` row (44 sites). For words whose first instruction today is a side effect (`ACTIVATE`/`WAKE` clear `break_pending`; `CONSTANT`/`VALUE` start `build_header`; `WORD` stores the delimiter; `BANK!`'s range check), the CALL goes before it.
  - [x] 2.1 `RESTORE-INPUT` (`src/outer_interpreter.asm:717`): `CALL check_underflow` at entry (count cell). On the count = 4 path, move the existing `CALL check_underflow_4` to after the first `POP HL` (x1): at that point BC + x2..x4 are exactly 4 cells. The one over-pop on a short stack lands in `SP_GUARD` and THROW resets SP. Net +3 B.
  - [x] 2.2 `SET-ORDER` (`src/wordlists.asm:221-228`): the variable check needs `sp_base - SP ≥ 2n + 2`, not `2n`. Add `INC HL / INC HL` after `ADD HL,HL` (+2 B). Worked through: with n wids + n on the stack, SP holds the n wids plus the bottom phantom slot, so `sp_base − SP = 2n + 2`, and the final `POP BC` takes the phantom slot, leaving the normal empty state. `0 SET-ORDER` alone needs 2 bytes (the phantom slot) and still passes; pin it with a probe case.
- [x] **Task 3 — 2- and 3-cell CODE words** (AC: 2) — `CALL check_underflow_2` for `TYPE`, `ACTIVATE`, `(stub-allocate)`, `(TO)`, `(DO)`, `(?DO)`; `CALL check_underflow_3` for `FILL`, `MOVE`. `(?DO)` checks at its own entry; its `JR w_PAREN_DO_cf.push_frame` lands after `(DO)`'s check, so no double check.
- [x] **Task 4 — `PICK` / `ROLL`** (AC: 2) — add `check_underflow_u` in `src/system.asm` after `check_underflow_4` (code in Dev Notes), and `CALL check_underflow_u` as the first instruction of `PICK` and `ROLL`.
- [x] **Task 5 — colon words** (AC: 5) — `ACCEPT` (`src/io.asm:422`): `DW w_PIC_QGUARD_2_cf` before `(LINE)`. `POST` (`src/multitasker.asm:721`): same, before `DUP`. `SEMAPHORE` (`:559`): `DW w_DUP_cf, w_DROP_cf` before `CREATE` (4 B; a new headed `(?1)` would cost 18 B for one site). Update their stack-comment lines. `(?2)`'s header comment calls it "Pictured-local"; reword to say it's the shared 2-cell guard.
- [x] **Task 6 — assembler** (AC: 6) — design in Dev Notes "Assembler". Do Tier 2 (`asm_need1/2/3` replacing `check_asm_mode` at the operand-taking prologues) and then the remaining multi-cell forms; itemise each site.
- [x] **Task 6a — `>NUMBER` cell order** (AC: 14) — in `src/strings.asm` (`w_TO_NUMBER_cf`, ~:351-363) swap the targets of the second and third `POP HL`: the cell under c-addr1 is ud1-**high**, the one under that is ud1-low. Fix the entry stack comment to match (`SP+2 = ud1-high`, `SP+4 = ud1-low`). The output pushes at `.tonum_done` are already right. 0 B. Design in Dev Notes "`>NUMBER` fix".
- [x] **Task 7 — hot-path cost** (AC: 7) — fill in the T-state table in Dev Notes from the code as built; estimate `INTERPRET`'s added cost per token from its thread (`src/outer_interpreter.asm`, count the checked words on the found-word and number paths).
- [x] **Task 8 — probe file `tests/underflow_tests.fth`** (AC: 9) — pattern and sketch in Dev Notes "Probe file". Header comment in the style of `tests/qdo_tests.fth`. Starts with `DECIMAL`; ends with a plain `\n`, no 0x1A. No line over 128 chars.
- [x] **Task 9 — Makefile** (AC: 9, 10)
  - [x] 9.1 `UNDERFLOW_PROBE = tests/underflow_tests.fth` after `QDO_PROBE` (Makefile:203).
  - [x] 9.2 Target `test-repl-underflow` after `test-repl-qdo` (Makefile:693-703), same recipe shape (timeout + rc 124 FAIL, `sed 's/$$/\r/'`, `BYE`, `tests/assert_verdicts.sh`).
  - [x] 9.3 Add to `.PHONY` (line 56) and to the `test-repl:` prerequisites (Makefile:1976) after `test-repl-qdo`.
  - [x] 9.4 Break one expectation to see the target fail; restore.
- [x] **Task 10 — docs** (AC: 11)
  - [x] 10.1 `docs/dev_journal.md`: retitle the 2026-10-08 Story 27.6 entry `(RESOLVED <date>, Story 27.6)`, add a short resolution paragraph (what was checked, real cost 94 T per `CALL check_underflow`, byte delta, anything left unchecked and why).
  - [x] 10.2 `docs/dev_journal.md`: new entry `(RESOLVED <date>, Story 27.6) — >NUMBER read ud1 with its cells swapped`, with the repro and the fix in two or three lines.
  - [x] 10.3 `docs/ans-forth-core-compliance.md:397` (`0<>` row): drop "(unlike `0=`, which has no check)". Grep the doc for other "no check"/"unchecked" notes that this story makes false.
  - [x] 10.4 `src/formatting.asm` `D.R` (~:133) and `U.R` (~:228) header comments: say which word actually traps (`DABS`), not `OVER`/`LIT +`/`check_underflow_3`.
  - [x] 10.5 `docs/throw-codes.md` cites `CALL check_underflow` hit counts and `system.asm:591` as a historical migration record; leave it. Run `make check-doc-sync`.
- [x] **Task 11 — verify and record** (AC: 10, 12, 13)
  - [x] 11.1 `make`, `wc -c build/antforth.com`; record the delta against the budget table, item by item.
  - [x] 11.2 `make test`, `make test-repl`, the banking targets (`test-repl-banking`, `-23-6`, `-23-7`, `-23-9`), `test-straddle-regression`, `lint-banking-probes`, `test-file-sanity`. Record the new PASS count.
  - [x] 11.3 If an existing probe now raises `-4`, find out whether the probe or a kernel thread relied on running a now-checked word on an empty stack. A kernel thread that does so is a bug to fix in the thread, not a reason to drop the check. If a banking probe halts, read `feedback_banking_probe_straddle_halt` first: +≈250 B moves bank-0 `HERE`.
  - [x] 11.4 Write the S9 recipe into Dev Notes and post it in the review close message.

## Dev Notes

### How the checks work

- TOS lives in BC; the rest of the stack is on the Z80 stack. The first push puts a junk ("phantom") cell at the bottom of SP, so with d user items there are d cells on SP and `DEPTH = (sp_base − SP)/2`.
- `check_underflow` (`src/system.asm:627-652`) and `_2`/`_3`/`_4` (`:654-727`) compare `sp_base − SP` against 4/6/8/10 (2 for the CALL's return address + 2 per cell) and `JP do_underflow_error` (`:794`, `-4` via `w_THROW_cf.kernel_entry`). They clobber AF and HL only; BC, DE, IX, IY, SP are kept. So a `CALL check_underflow` can go in front of any word that doesn't take a live A or HL on entry (no CODE word does).
- `sp_base` is per task (PAUSE swaps it from `t_sp_base`), so checks in task code measure the task's own stack.
- An unchecked word that POPs on an empty stack moves SP above `sp_base` into the 8-byte `SP_GUARD` (`src/antforth.asm:22`, `src/constants.asm:95`); nothing notices until a later checked word's `JR C` fires. That is why the 2026-10-08 sample showed `-4` for some words and silence for others.
- Probing: `CATCH` keeps its frame off the data stack, so `' W CATCH .` runs `W` on an empty stack. Verified at draft time: `' DROP CATCH . DEPTH .` → `-4 0`; `' DUP CATCH . DEPTH .` → `0 1` (the bug).

### Audit (draft 2026-10-11, HEAD `09b3c00`; re-verify — AC1)

Action key: `+1`/`+2`/`+3` add `CALL check_underflow`/`_2`/`_3` as the first instruction · `+U` add `CALL check_underflow_u` · `ok` already checked before any side effect · `inh` colon word, caught by its first consuming word before any side effect · `prefix` colon word, add a guard cell · `fix` existing check wrong · `exempt` stays unchecked (reason given).

**`src/stack_ops.asm`**

| Word | Line | Needs | Before | Action |
|---|---|---|---|---|
| `?DUP` | 13 | 1 | none | +1 |
| `DUP` | 27 | 1 | none (pushes phantom) | +1 |
| `DROP` | 37 | 1 | `_1` | ok |
| `SWAP` `OVER` `NIP` `TUCK` | 48, 62, 78, 90 | 2 | `_2` | ok |
| `ROT` `-ROT` | 103, 119 | 3 | `_3` | ok |
| `PICK` | 135 | u+2 | none (reads past `sp_base`) | +U |
| `ROLL` | 153 | u+2 | none (`LDDR` over u·2 bytes: memory corruption) | +U |
| `SP!` | 253 | 1 | none | +1 |
| `RP!` | 278 | 1 | none | +1 |
| `>R` | 290 | 1 | none | +1 |
| `DEPTH` `SP@` `RP@` `R>` `R@` | — | 0 (R-stack only for `R>`/`R@`) | — | — (return-stack underflow, `-6`, is out of scope) |

**`src/arithmetic.asm`, `src/logic.asm`, `src/bootstrap.asm`**

| Word | Line | Needs | Before | Action |
|---|---|---|---|---|
| `1+` `1-` `2*` `2/` | arith 13, 23, 33, 44 | 1 | none | +1 |
| `+` `-` `*` `/MOD` `/` `MOD` | arith 55–280 | 2 | `_2` | ok |
| `*/MOD` `*/` | arith 302, 321 | 3 | inh via `M*`'s `2DUP` (an unchecked `>R` runs first; R-stack only, THROW resets it) | inh — becomes a clean `>R` trap once `>R` is checked |
| `INVERT` | logic 69 | 1 | none | +1 |
| `0=` | logic 268 | 1 | none | +1 |
| `0<` | logic 300 | 1 | none | +1 |
| `0<>` `0>` | logic 284, 316 | 1 | `_1` | ok |
| all 2-operand logic/compare words | logic 18–354 | 2 | `_2` | ok |
| `NEGATE` | boot 9 | 1 | inh via `SWAP` | ok |
| `ABS` | boot 22 | 1 | none in effect (`DUP 0< ?BRANCH` all unchecked) | inh once `DUP` is checked |
| `MIN` `MAX` | boot 38, 56 | 2 | inh via `OVER` | ok |

**`src/memory.asm`, `src/double.asm`**

| Word | Line | Needs | Before | Action |
|---|---|---|---|---|
| `CELL+` `CHAR+` `CHARS` | mem 13, 24, 34 | 1 | none (`CHARS` is a no-op today) | +1 |
| `C@` | mem 76 | 1 | none (`@` checks) | +1 |
| `ALLOT` | mem 196 | 1 | none (moves HERE by the phantom) | +1 |
| `,` `C,` | mem 235, 261 | 1 | none (compiles the phantom) | +1 |
| `ALIGNED` `CELLS` | mem 295, 308 | 1 | none | +1 |
| `FILL` `MOVE` | mem 319, 358 | 3 | none (block op on junk address/count) | +3 |
| `@` `!` `C!` `+!` | mem 44–104 | 1/2 | checked | ok |
| all of `double.asm` | — | — | checked or inh | ok. `D*` (562): `SWAP` permutes before `2SWAP`'s `_4` fires — stack permutation only, left as is |

**`src/inner_interpreter.asm`, `src/control_flow.asm`**

| Word | Line | Needs | Before | Action |
|---|---|---|---|---|
| `?BRANCH` | inner 299 | 1 | none | +1 — consumes the user's flag (`: T IF … THEN ; T` on an empty stack branches on the phantom) |
| `EXECUTE` | inner 335 | 1 | none (jumps to the phantom address) | +1 |
| `(DO)` | cf 199 | 2 | none | +2 — consumes the user's limit/start |
| `(?DO)` | cf 220 | 2 | none | +2 |
| `(+LOOP)` | cf 280 | 1 | none | +1 — consumes the user's step |
| `LIT` `BRANCH` `(LOOP)` `UNLOOP` `I` `J` | — | 0 | — | — |
| `ELSE` `UNTIL` `AGAIN` `WHILE` `REPEAT` (compile time) | cf 60–148 | 1–2 control items | raise `-4` after compiling 2–6 bytes into the open definition | ok — they do raise `-4`; the stray bytes belong to a definition that is being abandoned. No structure-tag checking (`?PAIRS`) exists; out of scope |
| `THEN` `LOOP` `+LOOP` | | | checked before compiling | ok |

**`src/compiler.asm`, `src/dictionary.asm`, `src/strings.asm`, `src/outer_interpreter.asm`, `src/wordlists.asm`, `src/system.asm`, `src/exception.asm`**

| Word | Line | Needs | Before | Action |
|---|---|---|---|---|
| `>BODY` | comp 11 | 1 | none | +1 |
| `COMPILE,` | comp 541 | 1 | none (writes the phantom at HERE) | +1 |
| `LITERAL` | comp 833 | 1 | none | +1 |
| `CONSTANT` `VALUE` | comp 948, 1009 | 1 | none (header built, then phantom stored) | +1 before `EXX` / `build_header`. Also covers assembler `EQU`, which `JP`s to `CONSTANT` |
| `(TO)` | comp 1091 | 2 | none | +2 — fixes `TO` in interpret mode too (`'` supplies the xt, so `(TO)` stored the phantom) |
| `TO` | comp 1066 | 1 | none | inh once `(TO)` is checked |
| `COUNT` `FIND` | dict 9, 26 | 1 | none | +1 |
| `WORD` | str 11 | 1 | none (parses with a junk delimiter) | +1 |
| `NUMBER?` | str 448 | 1 | none | +1 |
| `>NUMBER` | str 342 | 4 | `_4` | ok (cell-order bug, see below — fixed, AC14) |
| `RESTORE-INPUT` | outer 717 | 1 or 5 | none on count ≠ 4; `_4` (one short) on count = 4 | fix (Task 2.1) |
| `(SAVE-INPUT)` `EVALUATE` | outer 563, 781 | 2 | `_2` / inh | ok |
| `SET-ORDER` | wl 189 | 1+n (+1 for the new TOS) | `_1` then variable check one cell short | fix (Task 2.2) |
| `SEARCH-WORDLIST` `SET-CURRENT` | wl 90, 283 | 3 / 1 | checked | ok |
| `(ABORT")` | sys 226 | 1 | none | +1 — consumes the user's flag |
| `ENVIRONMENT?` | sys 438 | 2 | `_2` | ok |
| `CATCH` `THROW` | exc 115, 358 | 1 | `_1` | ok |
| `COMP-ERROR` | comp 644 | 1 | none | exempt — internal error path called only by `INTERPRET`/`POSTPONE` with a value; executing it by hand hangs whatever the stack holds |

**`src/pictured.asm`, `src/formatting.asm`** — all checked or inherit before any side effect (`HOLD`, `#`, `#>`, `SIGN` checked; `#S`, `HOLDS`, `D.R`, `D.`, `.`, `U.`, `.R`, `U.R`, `UD.`, `?` inherit). `D.R`/`U.R` header comments name the wrong trapping word (Task 10.4).

**`src/io.asm`, `src/multitasker.asm`, `src/banking.asm`, `src/file_access.asm`, `src/timer.asm`**

| Word | Line | Needs | Before | Action |
|---|---|---|---|---|
| `EMIT` | io 13 | 1 | none | +1 |
| `TYPE` | io 28 | 2 | none (prints up to 64 KB from a junk address) | +2 |
| `SPACES` | io 90 | 1 | none | +1 |
| `ACCEPT` | io 422 | 2 | none in effect: `(EDIT)` writes the keystroke to a junk buffer; with 1 item it never raises | prefix `(?2)` |
| `IN` `OUT` | io 441, 455 | 1 / 2 | checked | ok |
| `ACTIVATE` | mt 308 | 2 | none (writes a TCB at a junk address; clears `break_pending` first) | +2, before the `break_pending` clear |
| `SLEEP` | mt 385 | 1 | none | +1 |
| `WAKE` | mt 403 | 1 | none (clears `break_pending` first) | +1, before the clear |
| `>TASK` | mt 523 | 1 | `_1` | ok |
| `SEMAPHORE` | mt 559 | 1 | none (`CREATE` lays a header, then `,` stores the phantom) | prefix `DUP DROP` |
| `SIGNAL` | mt 572 | 1 | none in effect: body starts `DUP @` — unchecked `DUP` copies the phantom, `@` reads it as an address, `!` writes there (dev pass: draft row said "inh (`SWAP`)") | inh once `DUP` is checked |
| `UNLOCK` | mt 662 | 1 | inh (`LIT 1 SWAP`) | ok |
| `WAIT` `LOCK` | mt 600, 649 | 1 | `PAUSE` then unchecked `DUP @ ?BRANCH` — can spin forever on the phantom address | inh once `DUP` is checked (`PAUSE` runs first; a yield is harmless) |
| `POST` | mt 721 | 2 | with 1 item, `WAIT` takes the free slot before `!` fails → mailbox left empty=0 full=0, next `POST`/`FETCH` blocks forever | prefix `(?2)` |
| `FETCH` | mt 744 | 1 | unchecked `DUP` first | inh once `DUP` is checked |
| `BANK!` | bank 256 | 1 | range check only (a small phantom switches bank) | +1, before the range check |
| `+BANK` `-BANK` | bank 456, 567 | 1 | none (probes or removes a junk page) | +1 |
| `(stub-allocate)` | bank 1140 | 2 | none (writes a junk stub, advances the tail) | +2 |
| `BANK-OF` | bank 1173 | 1 | none (in place) | +1 |
| `PROMPT-SHOW-BANK` | bank 76 | 1 | `_1` | ok |
| `IN-BANK` | bank 1263 | 2 | inh (`SWAP`; `BANK@ >R` first is R-stack only) | ok |
| `BIN` | fa 1486 | 1 | none (in place) | +1 |
| all other file words | fa 1501–3035 | 1–3 | checked or inh | ok |
| `(DELAY)` `DELAY` `MS` | tm 136–174 | 1–2 | `(DELAY)`: `PAUSE` before the `2OVER` check; `DELAY`/`MS` inh via `UM*` | ok |

**Exempt (AC8)**

- Headerless, fixed caller supplies the cells: `LC!` (cf 187), `(EDIT)` (io 243; only `(LINE)`; uses EXX), `(LINE)` (io 399; guarded by `ACCEPT`'s prefix and `QUERY`'s own pushes), `(QUERY-FINISH)` (outer 124), `to_verify` (comp 1116).
- `COMP-ERROR` (above).
- `TEST-BRIDGE` (antforth 769): `TEST_MODE` build only.
- Assembler register/condition-code tokens: not dictionary words, consume nothing.

**Not changed, noted:** `DUP`, `?DUP`, `TUCK`, `OVER` etc. have no overflow (`-3`) check; that is a separate question and out of scope.

### `check_underflow_u` (for `PICK` / `ROLL`)

`u PICK` and `u ROLL` need u+2 items (u itself plus x0..xu). With the CALL's return address that is `sp_base − SP ≥ 2u + 6`. BC = u on entry.

```asm
; -----------------------------------------------
; check_underflow_u — Internal subroutine (not a Forth word)
;   Verify DEPTH >= u+2 for u PICK / u ROLL, with u in BC.
;   Threshold: sp_base - SP_measured >= 2u + 6 (2 ret addr + 2(u+2)).
;   On underflow: JP do_underflow_error (-4 THROW).
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_u:
        LD      HL, (sp_base)
        OR      A
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow_u
        SBC     HL, BC          ; carry clear here
        JR      C, .underflow_u
        SBC     HL, BC          ; HL = sp_base - SP - 2u
        JR      C, .underflow_u
        LD      A, H
        OR      A
        RET     NZ
        LD      A, L
        CP      6
        RET     NC
.underflow_u:
        JP      do_underflow_error
```

- Subtracting BC twice avoids `ADD HL,HL` overflow for large u: any u > 129 borrows on the first `SBC` (HL ≤ 258).
- Bytes: 3+1+2+2+2+2+2+2+1+1+1+1+2+1+3 = 27.
- If the lead prefers bytes, `CALL check_underflow_2` (catches `PICK`/`ROLL` on an empty or 1-item stack, not an oversized u) saves 27 B. It leaves the `ROLL` memory corruption for large u.

### Assembler

Findings (`src/assembler.asm`, 81 DEFCODE words): no word checks depth; there is no shared operand-pop helper with a check. `check_asm_mode` (:500, raises `-270`) is the first call in each word, including zero-operand ones. `RET,` (:2775-2788) already tests depth inline to tell `RET` from `cc RET,`; leave it. Hazards today: `DS,` on an empty stack zero-fills a phantom-sized block from HERE (up to 32 KB); six `DB,` in a row on an empty stack walk SP up until a `CALL` writes over the BDOS entry vector.

Tier 2 (≈ 18 B): three entries next to `check_asm_mode`:

```asm
asm_need1:
        CALL    check_asm_mode
        JP      check_underflow
asm_need2:
        CALL    check_asm_mode
        JP      check_underflow_2
asm_need3:
        CALL    check_asm_mode
        JP      check_underflow_3
```

The `JP` leaves exactly the caller's one return address on SP, so the 4/6/8 thresholds stay right, and `-270` still wins. Swap `CALL check_asm_mode` → `CALL asm_needN` at the operand-taking prologues (0 B per site): `asm_need2` for `LD,` (:1547), `+D` (:1201), 16-bit `ADD,` (:2208), `ADC,`/`SBC,` 16-bit (:3785, :3835), `IN,` (:3331), `OUT,` (:3392), `EX,` (:3605); `asm_need3` for `BIT,`/`RES,`/`SET,` (:3190); `asm_need1` for `()` (:1080), `PUSH,`/`POP,` (:1449), arith (:2146), `FIX` (:2484), `JR,` (:2530), `JP (IX)` (:2651), `JP,`/`CALL,` (:2675), `DB,` (:2818), `DW,` (:2838), `DS,` (:2903), `INC,`/`DEC,` (:2949), CB shifts (:3072), `DJNZ,` (:3877), `RST,` (:3942). Verify at each site that A/HL are not live across the call (the audit found none: dispatchers pass parameters in `asm_tmp`).

Remaining forms that need more than the prologue's minimum (≈ +46 B if each gets its own check, less if shared): `(IX+d)` forms of arith, `INC,`/`DEC,`, CB shifts and `BIT,`/`RES,`/`SET,`; `n #` forms of arith, `IN,`, `OUT,`; `LD,` `r,(IX+d)`, `r,n #`, `r,nn ()`, `nn (),rr`, `(IX+d),r`, `(IX+d),n #`; `#` in asm mode (`:1094`, its inline mode test). One `CALL check_underflow_N` at the top of `asm_pop_indexed_disp` (:1183) covers the three `(IX+d)` displacement pops for 3 B, but fires after the prefix/opcode bytes are written; on an uncaught THROW `asm_cleanup` (:416) rolls HERE back to `asm_saved_here`, so those bytes only survive under `CATCH`. That trade is acceptable. Itemise what you build.

Not an underflow, out of scope: with a condition, `JR,`/`JP,`/`CALL,` peek NOS to decide; `NZ JR,` with no target uses the condition tag as the target (bad operand, not underflow).

### Hot-path cost (AC7)

`CALL check_underflow` with H = 0 (always, since `PS_SIZE` = 256): `CALL` 17 + `LD HL,(nn)` 16 + `OR A` 4 + `SBC HL,SP` 15 + `JR C` not taken 7 + `LD A,H` 4 + `OR A` 4 + `RET NZ` not taken 5 + `LD A,L` 4 + `CP n` 7 + `RET NC` 11 = **94 T-states**. The dev-journal entry's "about 50" is wrong. `NEXT` is 38 T.

| Word | Before (body + NEXT) | After | Ratio |
|---|---|---|---|
| `DUP` | 11 + 38 = 49 | 143 | 2.9× |
| `1+` / `1-` | 6 + 38 = 44 | 138 | 3.1× |
| `0=` | ≈ 30 + 38 ≈ 68 | ≈ 162 | 2.4× |
| `C@` | 4+4+7+7 + 38 = 60 | 154 | 2.6× |
| `>R` | 10+10+19+19+10 + 38 = 106 | 200 | 1.9× |
| `?BRANCH` not taken / taken | 75 / 105 | 169 / 199 | 2.3× / 1.9× |
| `EXECUTE` (to the target's code field, no NEXT) | 22 | 116 | 5.3× |
| `(+LOOP)` looping | 375 | 469 | 1.25× |
| `0=` (measured from the body) | 68 (false) / 69 (true) | 162 / 163 | 2.4× |

`INTERPRET`: count the newly checked words executed per found word and per number (`DUP`, `C@`, `?BRANCH`, `EXECUTE`, `FIND`, `WORD`, `NUMBER?`, `,` when compiling) and multiply by 94. Compare with the per-token work already there (`WORD` scan, hash, bucket walk, BDOS echo, typically thousands of T). Expectation: well under 10%, so no unchecked kernel entry points. If you decide otherwise, the AC7 mechanism is a second label after the `CALL` (e.g. `w_QBRANCH_cf.unchecked`) used only in kernel `DW` threads; `?BRANCH` (41 kernel thread uses) is the only plausible candidate.

The real cost lands on user programs: a tight `BEGIN … 1+ DUP … UNTIL` loop gets roughly 2–3× slower per checked primitive. That trade was accepted when FR-P7-14 was added; record the measured numbers.

### Byte budget (itemised, est. +263 B before options)

| Item | Components | Bytes |
|---|---|---|
| `CALL check_underflow` × 44 | `?DUP DUP SP! RP! >R` 5 · `1+ 1- 2* 2/` 4 · `INVERT 0= 0<` 3 · `CELL+ CHAR+ CHARS C@ ALLOT , C, ALIGNED CELLS` 9 · `?BRANCH EXECUTE (+LOOP)` 3 · `>BODY COMPILE, LITERAL CONSTANT VALUE` 5 · `COUNT FIND WORD NUMBER? (ABORT")` 5 · `EMIT SPACES SLEEP WAKE` 4 · `BANK! +BANK -BANK BANK-OF BIN` 5 · `RESTORE-INPUT` entry 1 = 44 × 3 | 132 |
| `CALL check_underflow_2` × 6 | `TYPE ACTIVATE (stub-allocate) (TO) (DO) (?DO)` | 18 |
| `CALL check_underflow_3` × 2 | `FILL MOVE` | 6 |
| `PICK`/`ROLL` | 2 × `CALL` 3 + `check_underflow_u` 27 | 33 |
| `RESTORE-INPUT` count = 4 | move existing `CALL` | 0 |
| `SET-ORDER` | `INC HL` × 2 | 2 |
| Colon prefixes | `ACCEPT` `(?2)` 2 · `POST` `(?2)` 2 · `SEMAPHORE` `DUP DROP` 4 | 8 |
| Assembler Tier 2 | 3 entries × (`CALL` 3 + `JP` 3) | 18 |
| Assembler remaining forms | ≈ 15 sites × 3 B, ±2 × 5 B with `PUSH HL/POP HL`; itemise as built | ≈ 46 |
| **Total** | | **≈ 263** |

Epic running total before this story: 76 (27.1) + 179 (27.2) + 8 (27.3) + 60 (27.4) = 323 B. 323 + 263 = 586 B, which is 86 B over the 500 B envelope, with 27.7 still unknown. NFR-P7-2 allows growth past the envelope with a stated reason. The reason here is that the audit found ≈ 55 sites against the ≈ 20 the estimate assumed. The `>NUMBER` fix adds 0 B.

**Decided 2026-10-11: overage accepted, no options taken.** The options below are kept as a record of what was considered:

- **(M) Merge the four helpers, −42 B.** One shared body with the threshold in A (`check_underflow` falls through, the others `JR` in). `check_underflow` stays 94 T; `_2`/`_3`/`_4` get +12 T each, a tax on every existing 2-, 3- and 4-operand word (`SWAP`, `+`, `!`, …). Code:

  ```asm
  check_underflow_4:  LD A, 9  /  JR check_underflow_n
  check_underflow_3:  LD A, 7  /  JR check_underflow_n
  check_underflow_2:  LD A, 5  /  JR check_underflow_n
  check_underflow:    LD A, 3                      ; falls through
  check_underflow_n:  LD HL,(sp_base) / OR A / SBC HL,SP / JR C,.uf
                      INC H / DEC H / RET NZ       ; HL >= 256: fine
                      CP L / RET C                 ; L > threshold-1: fine
  .uf:                JP do_underflow_error
  ```

  30 B against 72 B today. `OR A` with A = threshold clears carry and keeps A; `INC H / DEC H` tests H without touching A.
- **(P) `PICK`/`ROLL` with `check_underflow_2` only, −27 B.** Loses the oversized-u check.
- **(A) Assembler Tier 2 only, −≈ 46 B.** `(IX+d)`, `n #` and `nn ()` forms with operands missing keep failing with the wrong error (-258/-267) or a silent emit. That falls short of AC6 as written.

The dev pass does full coverage with none of these.

### Probe file (`tests/underflow_tests.fth`) — pattern

Every case runs a word through `CATCH` so the stack is empty (or one short) when it runs, and prints the code and the depth after. Tags print with `.`, so each number has a trailing space.

```forth
DECIMAL

\ --- Pre-flight: checked words already give -4 0 ---
." u0=" ' DROP CATCH . DEPTH . CR

\ --- 1-cell CODE words, interpret level: each prints -4 0 ---
." uA=" ' DUP CATCH . DEPTH . ' ?DUP CATCH . DEPTH . ' 1+ CATCH . DEPTH . CR
\ ... one tag line per small group; keep each line <= 128 chars

\ --- Same words inside a colon body ---
: _a1 DUP ;  : _a2 ?DUP ;  : _a3 1+ ;
." uB=" ' _a1 CATCH . DEPTH . ' _a2 CATCH . DEPTH . ' _a3 CATCH . DEPTH . CR

\ --- 2/3-cell words one short: -4, then the one item left, then depth 0 ---
." uC=" 1 ' TYPE CATCH . . DEPTH . 1 2 ' FILL CATCH . . . DEPTH . CR

\ --- Control-flow runtimes consume user values ---
: _cf1 IF 1 THEN ;  : _cf2 DO LOOP ;  : _cf3 2 0 DO +LOOP ;  : _cf4 ABORT" x" ;
." uD=" ' _cf1 CATCH . ' _cf2 CATCH . ' _cf3 CATCH . ' _cf4 CATCH . DEPTH . CR
```

Cases to include beyond one per word:

- AC3: `' DUP CATCH . DEPTH .` → `-4 0`.
- AC4: `SET-ORDER` — `1 ' SET-ORDER CATCH .` → `-4 1`, then `' DUP` still found (search order unchanged; any `-13` trips the fail line). `RESTORE-INPUT` — empty, and `1 2 3 4 ' RESTORE-INPUT CATCH` → `-4` with the four cells back.
- `PICK`/`ROLL` — empty; `1 ' PICK CATCH`; `1 2 5 ' PICK CATCH` (oversized u); `0 PICK` on 1 item (one short); a passing `1 2 3 2 PICK` → `1` and `1 2 3 2 ROLL` → `2 3 1` so the range check isn't too strict.
- `SET-ORDER` pass case: `FORTH-WORDLIST 1 SET-ORDER` still works.
- Words with side effects, run where the side effect would show: `' EMIT CATCH` (no junk char), `' BANK! CATCH` then `BANK@ .` → unchanged; `1 ' ACTIVATE CATCH` with a top-level `TASK CONSTANT _TT` (never define a TASK inside `:` — `project_defining_word_mid_colon_splice`); `MAILBOX _MB  _MB ' POST CATCH .` → `-4`, then `42 _MB POST  _MB FETCH .` → `42` (mailbox not deadlocked; without the fix this line hangs — the target's timeout turns that into FAIL).
- Parsing words (`CONSTANT`, `VALUE`, `SEMAPHORE`): the check must fire before the parse, so the rest of the line is still interpreted normally. `." uK=" ' CONSTANT CATCH . DEPTH . CR` prints `uK=-4 0` when fixed; unfixed, `CONSTANT` takes `.` as its name and the tag line comes out wrong. Same shape for `VALUE` and `SEMAPHORE`. `WORD` takes its delimiter from the stack and parses only after the check, so the same line shape works.
- `WAIT` on an empty stack in the operator would spin forever today (`project_operator_wait_wedge`); with `DUP` checked it raises `-4` after one `PAUSE`. Include it — the timeout covers the old hang.
- Assembler sample: `CODE _X1 DS, END-CODE` → `-4` (not a zero-fill), `CODE _X2 B LD, END-CODE` → `-4`, `CODE _X3 NOP, RET, END-CODE` still assembles (zero-operand on an empty stack). Look at `tests/` assembler probes for how `CODE` errors are counted and cleaned up (`asm_cleanup`).
- Witness: `." u-alive=" 6 7 * . CR` → `42`, and `DEPTH 0= IF ." PASS: u-depth" …`.

Makefile assertions (shape): `--fail-line '^FAIL: u-|^error -13|^error -274'` (adjust if a deliberate `-13` is counted), `--count N '^error -4: stack underflow'` only if some cases run without `CATCH`, one `'uX=… $$'` line per tag, `'PASS: u-depth$$'`, `'u-alive=42 $$'`. Config flags before assertions; keep `$` out of the label.

### `>NUMBER` fix (found during the audit; folded in by the project lead)

`>NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )`. A double is pushed low cell first, high cell second (§3.1.4.1), so on entry BC = u1, SP+0 = c-addr1, SP+2 = ud1-**high**, SP+4 = ud1-low. The code (`src/strings.asm` `w_TO_NUMBER_cf`) labels SP+2 as low and stores it in `.tonum_ud_lo`:

```asm
        POP     HL
        LD      (.tonum_ptr), HL        ; c-addr1
        POP     HL
        LD      (.tonum_ud_lo), HL      ; wrong: this is ud1-high
        POP     HL
        LD      (.tonum_ud_hi), HL      ; wrong: this is ud1-low
```

Fix: store the second pop in `.tonum_ud_hi` and the third in `.tonum_ud_lo`, and correct the entry comment. The pushes at `.tonum_done` (low, high, c-addr2) are already in the right order, which is why the bug only shows with a nonzero ud1.

Reproduced at draft time on the 31,077 B binary:

| Input | Expected | Today |
|---|---|---|
| `DECIMAL 1 0 S" 0" >NUMBER 2DROP D.` | `10` | `655360` |
| `0 1 S" 0" >NUMBER 2DROP D.` | `655360` | `10` |
| `65535 0 S" 0" >NUMBER 2DROP D.` | `655350` | `-655360` |

No kernel word calls `>NUMBER` (`NUMBER?` has its own loop), and every existing test passes `0 0` (`tests/double_tests.fth:103-125`, Makefile REPL tests 439–442), so nothing else changes. The third case also checks that the low-cell carry into the high cell still works once the cells are the right way round. Probe lines: `." uN=" 1 0 S" 0" >NUMBER 2DROP D. 0 1 S" 0" >NUMBER 2DROP D. 65535 0 S" 0" >NUMBER 2DROP D. CR` → `uN=10 655360 655350 ` (each `D.` prints a trailing space; confirm the exact spacing from a run). Also add the case this bug breaks in practice, accumulating across two calls: `0 0 S" 12" >NUMBER 2DROP S" 34" >NUMBER 2DROP D.` → `1234`.

The `docs/ans-forth-core-compliance.md:271` row's line number moves with the edit; re-point it.

### Testing standards

- Through the Forth threading model, REPL-piped (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Verdict greps column-0 anchored; echoed source starts with `."`, `:` or a word name.
- `IZCPM` is `iz-cpm-banking` (Makefile:19), so `BANK!`/`+BANK` work in a plain `test-repl` target.
- Lines ≤ 128 chars (`feedback_tib_size_inline_comments`).
- If a number looks wrong, check BASE first (`project_hex_base_leak_literal_truncation`).
- Bank-0 colon bodies stay below `$8000`; probe `HERE` starts ≈ 31,330 + the kernel delta.

### Previous story (27.4) — what carries over

- Header/byte estimates have matched exactly in 27.1–27.4 (76/76, 179/179, 8/8, 60/60). This story is mostly 3-byte `CALL`s, so the per-site count is what matters; recount from the built code.
- Probe/Makefile template: `tests/qdo_tests.fth` + `test-repl-qdo` (Makefile:693-703).
- 27.4 found the bank-lookup bug again (now Story 27.7). If a banked probe name raises `-13`, rename it; don't chase it here.
- 27.4 noted "No underflow check, matching `(DO)` … Story 27.6's audit decides that for both" — decided: both get `_2`.

### Git intelligence

Recent commits: `09b3c00 feat: add ?DO (Story 27.4)`, `3b50b0c feat: add AGAIN (Story 27.3)`, `35c096d feat: add <>, 0<>, 0>, U>, <= and >= (Story 27.2)`. Suggested message: `fix: raise -4 on stack underflow in every consuming word (Story 27.6)`. No Claude co-author trailer (`feedback_no_claude_coauthor`).

### S9 recipe (draft)

At the MicroBeast prompt (fresh boot):

1. `' DUP CATCH . DEPTH .` → `-4 0`; same for `1+`, `0=`, `C@`, `EMIT` (no junk character printed), `TYPE`.
2. `DUP` alone → `error -4: stack underflow`; then `DEPTH .` → `0`.
3. `: _cf1 IF 1 THEN ;  ' _cf1 CATCH .` → `-4`.
4. `BANK@ .  ' BANK! CATCH .  BANK@ .` → same bank both times, `-4` between.
5. `MAILBOX _MB  _MB ' POST CATCH .` → `-4`; `42 _MB POST  _MB FETCH .` → `42` (no hang).
6. `1 2 3 2 ROLL .S` → `2 3 1`; `1 2 5 ' ROLL CATCH .` → `-4`.
7. `CODE _X1 DS, END-CODE` → `-4`, nothing zero-filled; `1 2 + .` → `3`.
8. `DECIMAL 1 0 S" 0" >NUMBER 2DROP D.` → `10`; `0 0 S" 12" >NUMBER 2DROP S" 34" >NUMBER 2DROP D.` → `1234`.

### Project Structure Notes

- Files touched: `src/stack_ops.asm`, `src/arithmetic.asm`, `src/logic.asm`, `src/memory.asm`, `src/inner_interpreter.asm`, `src/control_flow.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/strings.asm`, `src/outer_interpreter.asm`, `src/wordlists.asm`, `src/system.asm`, `src/io.asm`, `src/multitasker.asm`, `src/banking.asm`, `src/file_access.asm`, `src/assembler.asm`, `src/pictured.asm` (comment), `src/formatting.asm` (comments), `tests/underflow_tests.fth` (new), `Makefile`, `docs/dev_journal.md`, `docs/ans-forth-core-compliance.md`, this story file, `sprint-status.yaml`.
- Source comments say what and why, not story/date provenance (`feedback_source_comment_discipline`). A one-line stack comment change where a word gains a check is enough; don't add "added by 27.6".
- Line insertions shift `DEFCODE` lines in every file; after the edit, `grep -rn "\.asm:[0-9]" docs/ README.md` for citations that moved and re-point the ones in `docs/ans-forth-core-compliance.md` and `docs/register-conventions.md` (leave dated survey/history docs alone). `make check-doc-sync` must pass.
- No architecture doc covers Phase 7; no external libraries; no web research needed.

### References

- Epic: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — FR-P7-14, NFR-P7-1..7, Story 27.6 ACs.
- `docs/dev_journal.md` — "2026-10-08 (OPEN, Story 27.6) — one-operand words don't check for underflow".
- `src/system.asm:627-727` (helpers), `:794` (`do_underflow_error`); `src/antforth.asm:22` and `src/constants.asm:95` (`SP_GUARD`); `src/structures.asm:89-93` (`t_sp_base`).
- `src/pictured.asm:176-186` (`(?2)`), `src/double.asm:680-690` (`(?3)`).
- `src/assembler.asm:416` (`asm_cleanup`), `:500` (`check_asm_mode`), `:1183` (`asm_pop_indexed_disp`), `:2775-2788` (`RET,` depth test).
- `tests/qdo_tests.fth`, Makefile:56, :203, :693-703, :1976; `tests/assert_verdicts.sh`.
- ANS Forth 1994 §9.3.5 (`-4` stack underflow), §6.1.2.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Pre-edit baseline (re-measured, HEAD `09b3c00`): `wc -c build/antforth.com` = **31,077 B**; `make test-repl` = **1074 PASS / 0 FAIL / 2 SKIP**.
- Red: `make test-repl-underflow` on the unmodified binary failed 50 of 52 verdicts (`uA=0 1 0 1 error -3 …` — `DUP` copied the phantom, `SP!` then overflowed).
- Probe bugs found and fixed while going green: `BANK@ ' BANK! CATCH` (BANK@ fed BANK! a cell; now stashes the bank in a VARIABLE); `S" TO _v" ' EVALUATE CATCH` left EVALUATE's `c-addr u` (ANS CATCH restores the pre-call depth; added `2DROP`); oversized-u `PICK`/`ROLL` cases needed one more `.` for the restored u; `_XA` was first executed, which ran `(IX+d)` code against the return stack (-274) — now only its length is checked.
- Own bug caught by REPL test 961: the first `RESTORE-INPUT` edit popped x1 into HL and then called `check_underflow_4`, which clobbers HL. Fixed by popping x1 into BC (the spent count) and comparing against B/C; 0 B.
- Existing tests that relied on the old behaviour (Task 11.3 — both were probes, not kernel threads): REPL test 732 ran `' DUP CATCH .` on an empty stack as its "positive control" → now `7 ' DUP CATCH . . .` expecting `0 7 7`. REPL test 792 built `-267` as `5 BIT,` (one cell where BIT, takes three; `-4` now wins) → `0 # 5 BIT,`; same line in `tests/throw_migration_tests.fth:292`.
- Multitasker probes (not `test-repl` prerequisites): `-multitasker-bank` and `-mailbox` were **already failing on HEAD** (second `TASK` → `-8`); 27.6 broke `-multitasker-throw`, `-semaphore`, `-multitasker-demo` the same way. Cause: TCBs must sit below `$8000`; boot `HERE` 31,333 → 31,592, room 1,435 → 1,176 B, TCB 535 B. Fixed by carving TCBs before other definitions (see Completion Notes). Recorded as an OPEN dev-journal entry.
- Hot-path measurement: iz-cpm `-z` trace, `Cycle:` field at BYE, Z80 cycles only (BDOS runs on the host). Per-check attribution via a symbol file (`sjasmplus --sym`) and counting `CALL check_underflow*` by caller.

### Completion Notes List

**What was built (AC1–AC6, AC14)**

- Audit re-verified against the source (Task 1): every row held except `SIGNAL` (its body starts with `DUP`, not `SWAP`, so it inherits only once `DUP` is checked) — row corrected above. No consuming word missing; headerless `LC@`/`(QMARK-BANK)` consume nothing. Exempt rows hold.
- 51 CODE words got a check as their first instruction (44 × `check_underflow` incl. `RESTORE-INPUT`'s count cell, 6 × `_2`, 2 × `_3`), each before any side effect — for `ACTIVATE` before the IP save and `break_pending` clear, `CONSTANT`/`VALUE` before `EXX`/`build_header`, `WORD` before the delimiter store, `BANK!` before the range check. Stale "No underflow check" label comments on `>R`, `ALLOT`, `,`, `C,`, `FILL`, `MOVE` removed.
- `check_underflow_u` in `src/system.asm` after `check_underflow_4`; `PICK`/`ROLL` call it first. It is **26 B**, not the 27 in the draft (the draft's own term list sums to 26).
- `RESTORE-INPUT`: entry check; on count = 4, x1 is popped into BC and `check_underflow_4` runs after the pop (5 cells in all). `SET-ORDER`: threshold `2n + 2`.
- `ACCEPT`, `POST`: `(?2)` as the first cell; `SEMAPHORE`: `DUP DROP`. `(?2)`'s header comment now describes it as the shared 2-cell guard.
- Assembler: `asm_need1/2/3` next to `check_asm_mode`, swapped in at 23 operand-taking prologues (14 × need1, 8 × need2, 1 × need3), 0 B each; A/HL checked dead at every site. Per-form checks, all before any byte is emitted except the shared `(IX+d)` pop: `#` in asm mode (_1); `LD,` `r,(IX+d)` (_2 after the dst pop, preserving L in B), `(IX+d),r` (_3), `n #` (_3), `(IX+d),n #` (_3 around `PUSH HL`), `r,(nn)` (_3), `(nn),A` (_2), `(nn),rr` (_3); arith `n #` (_2); `asm_pop_indexed_disp` (_3, covers arith/INC/DEC/CB-shift `(IX+d)`, after the prefix bytes, as the story allows); `BIT,`/`RES,`/`SET,` `(IX+d)` (_4); `IN,` `n #` (_3); `OUT,` `n #` (_2). `-270` still wins (`ut=-270 -270 0`). Underflow is now checked before operand type, so a short `BIT,` gives `-4`, not `-267`.
- `>NUMBER`: second/third pops swapped (ud1-high is the cell under c-addr1); entry comment corrected. 0 B. `ur=10 655360 655350`, `us=1234`.

**Hot-path cost (AC7)** — table in Dev Notes. `CALL check_underflow` = 94 T. Measured per token (Z80 cycles, BDOS excluded):

| Path | Before | After | Change |
|---|---|---|---|
| `INCLUDE` from disk, found word (`CHARS`) | 9,824 T | 10,774 T | +9.7% |
| `INCLUDE` a file of 10 colon definitions (total) | 1,229,915 T | 1,405,665 T | +14.3% |
| typed line, found word | 12,287 T | 14,859 T | +20.9% |
| typed line, number + `DROP` | 16,803 T | 20,316 T | +20.9% |

`INTERPRET` adds 9 checks per found word in interpret state (`WORD DUP C@ ?BRANCH FIND DUP ?BRANCH ?BRANCH EXECUTE` = 846 T) and 10 when compiling (`,` instead of `EXECUTE`, plus the IMMEDIATE `?BRANCH`). The typed-input figure is higher because the line reader runs three new checks per character (`KEY`'s `KEY? 0= ?BRANCH` poll and `(LINE)`'s `?BRANCH`); on hardware that loop waits on the serial line anyway. The `INCLUDE` figures are at or just over the story's "well under 10%" expectation. **No unchecked entry points were added** — the trade was accepted with FR-P7-14, and real disk I/O (not counted here) lowers the percentage on hardware. If the lead wants compile speed back: `DW w_X_cf + 3` (skip the 3-byte CALL) in the `INTERPRET` thread for `WORD DUP C@ ?BRANCH FIND EXECUTE ,` costs 0 B and is safe there because the thread itself produces each cell; the line reader's `0=`/`?BRANCH` likewise.

**Exemptions (AC8)** — as the audit's Exempt list: `LC!`, `(EDIT)`, `(LINE)`, `(QUERY-FINISH)`, `to_verify` (headerless, fixed caller); `COMP-ERROR` (internal error path); `TEST-BRIDGE` (test build only).

**Fixed RAM for TCBs (found during regression)** — see Debug Log. Probes changed to carve TCBs before other definitions: `multitasker_throw` (BMT2 carved before BMT so BMT stays ring index 1 for its asserted `task 1:` / `1 SUSPENDED` rows), `semaphore`, `mailbox`, `multitasker_bank` (BG/APP/TAPE must also be below `$8000` since BG runs with bank 1 paged, so order is BG's words → both TCBs → rest; **14 B to spare**), `multitasker_demo` (BG's TCB before the INCLUDE). Per the project lead's decision (2026-10-11), `disk/a/TRAFFIC.FTH` now carves `TASK CONSTANT LIGHTS` before its other definitions (0x1A EOF kept); the demo assertion moved from `^   2   AWAKE` to `^   1   AWAKE` (still pins LIGHTS). Stale "~3 KB" comment in `TASK` and "~2 KB" budget notes in the semaphore/mailbox/mutex probes corrected. Dev-journal entry "2026-10-11 (OPEN) — fixed RAM below `$8000` now holds only two TCBs" records the trend and options.

**Docs (AC11)** — dev-journal 27.6 entry resolved (94 T, measured costs, +259 B); new `>NUMBER` entry (RESOLVED); new TCB-room entry (OPEN). `ans-forth-core-compliance.md`: `0<>`/`0>` "no check" notes removed, `>NUMBER` row notes the fix; 93 + 11 `src/*.asm:N` citations in `ans-forth-core-compliance.md` / `register-conventions.md` re-pointed after the line shifts, plus three that were already pointing at blank lines on HEAD (`[']`, `[CHAR]`, `S"` interpret tail). `D.R`/`.R`/`U.R` comments now name the trapping words. `docs/throw-codes.md` left as a historical record.

**Byte budget (AC12)** — 31,077 → **31,336 B (+259)** vs estimate +263:

| Item | Estimate | Actual |
|---|---|---|
| `CALL check_underflow` × 44 | 132 | 132 |
| `CALL check_underflow_2` × 6 | 18 | 18 |
| `CALL check_underflow_3` × 2 | 6 | 6 |
| `PICK`/`ROLL` (2 × CALL + `check_underflow_u`) | 33 | 32 (helper 26, not 27) |
| `RESTORE-INPUT` count = 4 | 0 | 0 |
| `SET-ORDER` | 2 | 2 |
| Colon prefixes | 8 | 8 |
| Assembler Tier 2 (`asm_need1/2/3`) | 18 | 18 |
| Assembler remaining forms | ≈46 | 43 (`#` 3, `LD,` 25, arith `n #` 3, `(IX+d)` pop 3, `BIT,` 3, `IN,` 3, `OUT,` 3) |
| **Total** | **≈263** | **259** |

Epic 27 running total: 76 + 179 + 8 + 60 + 259 = **582 B**, 82 B over the 500 B envelope (NFR-P7-2), 27.7 still to come. Reason: the audit found ≈55 sites (plus the assembler) against the ≈20 the estimate assumed; overage accepted by the project lead on 2026-10-11.

**Regression (AC9, AC10)** — `make test` PASS; `make test-repl` **1126 PASS / 0 FAIL / 2 SKIP** (1074 + 52 new, none removed); `test-repl-underflow` 52/52 and seen failing on a broken expectation (Task 9.4); banking targets (`-banking` 57, `-23-6` 7, `-23-7` 4, `-23-9` 9, all 14 isolated targets), `test-straddle-regression`, `lint-banking-probes`, `test-file-sanity`, timer, all multitasker/semaphore/mutex/mailbox targets green; `make check-doc-sync` 0 drift. Probe lines ≤ 128 chars.

**S9 hardware recipe (AC13, Task 11.4)** — **PASS on real MicroBeast, 2026-10-11** (31,336 B binary, 22,680 bytes free, 12 banks): all nine steps gave the expected output; step 7 run twice gave `-4` both times (no leftover `_X1` after the first error); TRAFFIC.FTH loaded, `.TASKS` showed `0 * AWAKE` / `1   AWAKE`, and `LIGHTS SLEEP TIMER-OFF` returned to `ok`. Copy `build/antforth.com` and the updated `disk/a/TRAFFIC.FTH` (0x1A-terminated) to the board. At a fresh prompt:

1. `' DUP CATCH . DEPTH .` → `-4 0`; same for `1+`, `0=`, `C@`, `EMIT` (no junk character), `TYPE`.
2. `DUP` alone → `error -4: stack underflow`; then `DEPTH .` → `0`.
3. `: _cf1 IF 1 THEN ;  ' _cf1 CATCH .` → `-4`.
4. `VARIABLE _bk BANK@ _bk !  ' BANK! CATCH .  BANK@ _bk @ = .` → `-4 -1`.
5. `MAILBOX _MB  _MB ' POST CATCH . DROP` → `-4` (the `DROP` takes back the `_MB` that CATCH restores; the draft recipe in Dev Notes leaves it on the stack, and step 7's `DS,` then zero-fills from HERE using it as the count); `42 _MB POST  _MB FETCH .` → `42` (no hang).
6. `1 2 3 2 ROLL . . .` → `1 3 2`; `1 2 5 ' ROLL CATCH . . . . DEPTH .` → `-4 5 2 1 0`.
7. `CODE _X1 DS, END-CODE` → `error -4`, nothing zero-filled; `1 2 + .` → `3`.
8. `DECIMAL 1 0 S" 0" >NUMBER 2DROP D.` → `10`; `0 0 S" 12" >NUMBER 2DROP S" 34" >NUMBER 2DROP D.` → `1234`.
9. Fresh boot: `INCLUDE TRAFFIC.FTH  TIMER-ON  ' RUN-LIGHTS LIGHTS ACTIVATE` → lights cycle, prompt live; `.TASKS` → `0 * AWAKE`, `1   AWAKE`; `LIGHTS SLEEP TIMER-OFF`. (Steps 1–8 and the `.TASKS` rows checked on iz-cpm-banking.)

**After-edit line numbers of the new checks** (kernel): arithmetic 15/26/37/49; banking 258 (BANK!), 459, 571, 1145, 1179; compiler 13, 544, 837, 953, 1015, 1098; control_flow 201, 223, 284; dictionary 11, 29; file_access 1488; inner_interpreter 301, 338; io 15, 31, 94, 428 (ACCEPT guard); logic 71, 271, 304; memory 15, 27, 38, 81, 202, 242, 269, 304, 318, 330, 370; multitasker 312, 390, 409, 567 (SEMAPHORE guard), 730 (POST guard); outer_interpreter 719 (+ moved `_4` after the x1 pop); stack_ops 15, 30, 139, 158, 259, 285, 298; strings 13, 451; system 228; `check_underflow_u` in system.asm after `check_underflow_4`.

### File List

- `src/stack_ops.asm`, `src/arithmetic.asm`, `src/logic.asm`, `src/memory.asm`, `src/inner_interpreter.asm`, `src/control_flow.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/strings.asm`, `src/system.asm`, `src/io.asm`, `src/multitasker.asm`, `src/banking.asm`, `src/file_access.asm`, `src/outer_interpreter.asm`, `src/wordlists.asm`, `src/assembler.asm` — checks
- `src/pictured.asm`, `src/formatting.asm` — comments
- `tests/underflow_tests.fth` — new probe
- `Makefile` — `UNDERFLOW_PROBE`, `test-repl-underflow` (+ `.PHONY`, `test-repl` prerequisite); REPL tests 732 and 792 adjusted; demo assertion `^   1   AWAKE`
- `tests/throw_migration_tests.fth` — T267 line (`0 # 5 BIT,`)
- `tests/multitasker_throw_tests.fth`, `tests/multitasker_bank_tests.fth`, `tests/multitasker_demo_tests.fth`, `tests/semaphore_tests.fth`, `tests/mailbox_tests.fth`, `tests/mutex_tests.fth` — TCBs carved first / budget comments
- `disk/a/TRAFFIC.FTH` — `TASK CONSTANT LIGHTS` moved before the other definitions
- `docs/dev_journal.md`, `docs/ans-forth-core-compliance.md`, `docs/register-conventions.md`
- `_bmad-output/implementation-artifacts/27-6-one-operand-underflow-checks.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-10-11 — Story 27.6 implemented: `-4` on underflow in every consuming kernel word and assembler mnemonic, `check_underflow_u`, `SET-ORDER`/`RESTORE-INPUT` thresholds, `>NUMBER` cell order; new `test-repl-underflow` probe (52 verdicts). Multitasker probes and `TRAFFIC.FTH` carve TCBs first (fixed RAM below `$8000` now holds two TCBs). +259 B (31,077 → 31,336). Status → review. S9 hardware recipe passed on MicroBeast the same day.
- 2026-10-11 — Code review: one finding, fixed. The `(IX+d)`/`(IY+d)` branches of the arithmetic group, `INC,`/`DEC,` and the CB-prefixed group checked depth inside `asm_pop_indexed_disp`, after emitting the prefix and opcode, so a caught `-4` left those bytes in the open CODE body (AC2). Each branch now runs `check_underflow_2` before emitting; the helper's check is removed. Probe verdicts `uw`/`ux`/`uy` assert HERE does not move (old code: 2/4/6 bytes). +12 B (31,336 → 31,348; story total +271). The S9 run above used the 31,336 B binary; the change is assembler-only and covered by the emulator probe. Status → done.
