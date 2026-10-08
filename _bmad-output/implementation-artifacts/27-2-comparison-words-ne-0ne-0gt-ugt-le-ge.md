# Story 27.2: Comparison words `<>`, `0<>`, `0>`, `U>`, `<=`, `>=`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer,
I want the common comparison words as fast CODE words,
so that I can write conditions directly instead of `= 0=` or `SWAP U<`.

**Covers:** FR-P7-4, FR-P7-5, FR-P7-6, FR-P7-7, FR-P7-8, FR-P7-9, FR-P7-13 (part). Source: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` § "Story 27.2".

## Acceptance Criteria

1. **Behaviour.** Each word returns TRUE = -1 or FALSE = 0 at these boundary values (all literals below are signed decimal or `$`-hex, which the REPL accepts):
   - `<>` (§6.2.0500): `5 5` → 0, `5 6` → -1, `-1 -1` → 0, `0 -1` → -1.
   - `0<>` (§6.2.0260): `0` → 0, `1` → -1, `-1` → -1, `$8000` → -1.
   - `0>` (§6.2.0280): `0` → 0, `1` → -1, `-1` → 0, `$7FFF` → -1, `$8000` → 0, `128` → -1 (low byte has bit 7 set; catches a sign test on the wrong byte).
   - `U>` (§6.2.2350): `$FFFF 1` → -1, `1 $FFFF` → 0, `7 7` → 0, `1 0` → -1, `0 0` → 0.
   - `<=` (extension): `3 3` → -1, `2 3` → -1, `3 2` → 0, `-1 0` → -1, `$7FFF $8000` → 0, `$8000 $7FFF` → -1, `$8000 0` → -1, `0 $8000` → 0, `$8000 $8000` → -1, `$7FFF $7FFF` → -1.
   - `>=` (extension): `3 3` → -1, `2 3` → 0, `3 2` → -1, `-1 0` → 0, `$7FFF $8000` → -1, `$8000 $7FFF` → 0, `$8000 0` → 0, `0 $8000` → -1, `$8000 $8000` → -1.
2. **CODE words in `src/logic.asm`.** Each is a DEFCODE word placed next to its sibling (`<>` after `=`, `<=`/`>=` after `>`, `0<>` after `0=`, `0>` after `0<`, `U>` after `U<`), building the flag with the existing idiom `LD BC,0` / `DEC BC`. No threaded wrappers.
3. **Underflow.** `<>`, `U>`, `<=`, `>=` call `check_underflow_2`, as `=`, `<`, `U<` do. `0<>` and `0>` call `check_underflow` (see Dev Notes, "One-operand words don't check underflow"; this differs from the epic text, which asked for `0=`/`0<` parity). Every underflow raises `-4` through an existing helper; no new checking scheme.
4. **Register contract.** Each new word preserves DE = IP, leaves BC = TOS, uses no `EXX` and no IX/IY.
5. **Extension flag.** `<=` and `>=` carry a `; antforth extension` source comment.
6. **`examples/batnball.fth`.** Its local `>=` / `<=` definitions (lines 84–86, "utility words") are removed. The file still INCLUDEs without error and its call sites (lines 139–140) resolve to the kernel words.
7. **Tests.** A new REPL-piped probe file `tests/comparison_tests.fth` plus Makefile target `test-repl-comparisons`, added as a prerequisite of `test-repl`, covers every AC1 case at interpret level and inside a colon body, and every AC3 underflow case at interpret level and inside a colon body. Probe lines stay ≤ 128 chars.
8. **Docs.** In `docs/ans-forth-core-compliance.md`: the `0<>` (§6.2.0260), `0>` (§6.2.0280), `<>` (§6.2.0500), `U>` (§6.2.2350) rows move from "§6.2 Deliberately Omitted" to "§6.2 Implemented" in § order, verdict `Implemented`, source `src/logic.asm:LINE`, Closure `Story 27.2`. `<=` and `>=` are added to "Non-standard words" as `Non-standard (antforth extension)`. Every count that quotes the §6.2 tables is recounted from the rows (expected 21 implemented / 25 omitted — count `^| §6.2` rows, don't trust this arithmetic). In `docs/dev_journal.md`, the ` - <=, >=, <> ` and ` - 0>, 0<>` entries get `— RESOLVED 2026-MM-DD, Story 27.2`; the ` - U.R, U>` entry is split so `U>` is marked resolved and `U.R` stays as written (see Dev Notes). A new open entry records the one-operand underflow gap. `README.md`'s 6.2 row matches the recount.
9. **Regression.** `make test` passes; `make test-repl` passes at 0 FAIL with the baseline count plus the new probes; none removed. `ENVIRONMENT? CORE-EXT` still answers false.
10. **Budget.** The real byte delta against the pre-edit baseline is recorded in Dev Notes and compared word by word against the itemised estimate (179 B).
11. **Hardware.** The S9 hardware-smoke recipe is posted in the closing review chat message.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 30,830 B (2026-10-08, after Story 27.1) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (27.1 recorded 1027 PASS / 0 FAIL / 2 SKIP — re-measure)

### Story tasks

- [x] **Task 1 — two-operand words in `src/logic.asm`** (AC: 1, 2, 3, 4, 5)
  - [x] 1.1 `<>` directly after `=` (`w_NOT_EQUALS` / `w_NOT_EQUALS_cf`, local label `.ne_done`). Sequence in Dev Notes.
  - [x] 1.2 `<=` and `>=` directly after `>` (`w_LESS_EQUALS`, `w_GREATER_EQUALS`; locals `.le_no_ov`/`.le_done`, `.ge_no_ov`/`.ge_done`), each header line ending `; antforth extension`. Sequences in Dev Notes.
  - [x] 1.3 `U>` directly after `U<` (`w_U_GREATER` / `w_U_GREATER_cf`, local `.ugt_done`). Sequence in Dev Notes.
  - [x] 1.4 Header comments in the existing shape: `; NAME ( stack -- flag )` + one-line description + any non-obvious flag logic (the `SCF` borrow trick needs one line saying why it works). Add the ANS § line for the four Core-Ext words as `stack_ops.asm` does for `NIP`/`TUCK`.
- [x] **Task 2 — one-operand words in `src/logic.asm`** (AC: 1, 2, 3, 4)
  - [x] 2.1 `0<>` directly after `0=` (`w_ZERO_NOT_EQUALS`, local `.zne_done`).
  - [x] 2.2 `0>` directly after `0<` (`w_ZERO_GREATER`, local `.zgt_done`).
  - [x] 2.3 Both start with `CALL check_underflow` (confirmed by the project lead 2026-10-08).
- [x] **Task 3 — file header** (AC: 2): update `src/logic.asm:5` to `; Comparison: =, <>, <, >, <=, >=, 0=, 0<>, 0<, 0>, U<, U>`.
- [x] **Task 4 — `examples/batnball.fth`** (AC: 6)
  - [x] 4.1 Delete lines 85–86 (`: >= …` / `: <= …`) and the `\ utility words` comment above them if nothing else sits under it (line 88 starts `\ change the sign of a VARIABLE`, so the comment goes too). Leave the file's line endings and terminator as they are (it ends `;\n`, no 0x1A; it is not in `disk/a/`).
  - [x] 4.2 Load check under the emulator without touching `disk/a/`: copy the file into a scratch directory as `BATNBALL.FTH`, run `iz-cpm-banking --disk-a <scratch> build/antforth.com` with `INCLUDE BATNBALL.FTH` then `' >= U. ' <= U.` then `BYE`. Expect no error lines, and both xts below `$8000` (kernel fixed memory). Don't run the game loop under the emulator; it needs a VT52 terminal and live keys. Record the output in Debug Log.
- [x] **Task 5 — probe file `tests/comparison_tests.fth`** (AC: 1, 3, 7)
  - [x] 5.1 Header comment in the style of `tests/stack_words_tests.fth`: what it pins, column-0 anchoring, the underflow count. Start with `DECIMAL`.
  - [x] 5.2 Pre-flight: `' <> DROP  ' 0<> DROP  ' 0> DROP  ' U> DROP  ' <= DROP  ' >= DROP`.
  - [x] 5.3 Interpret level: one tagged line per word printing its AC1 results with `.`, e.g. `." neA=" 5 5 <> . 5 6 <> . -1 -1 <> . 0 -1 <> . CR` → Makefile asserts `'neA=0 -1 0 -1 $$'`. Split `<=`/`>=` across two lines each if a line would pass 128 chars.
  - [x] 5.4 Colon body: one word per comparison that runs the same cases and prints them the same way under a second tag (e.g. `: _ne 5 5 <> . 5 6 <> . -1 -1 <> . 0 -1 <> . ;` then `." neB=" _ne CR`). Same expected strings, different tag. This also proves the words compile as ordinary CFAs.
  - [x] 5.5 Depth checks: after the result lines, a column-0 `PASS: cmp-depth` / `FAIL: cmp-depth` line computed with `DEPTH 0=`, so a word that leaves an extra cell or eats one is caught.
  - [x] 5.6 Underflow at interpret level, one case per line on an empty stack: `<>`, `1 <>`, `U>`, `1 U>`, `<=`, `1 <=`, `>=`, `1 >=`, `0<>`, `0>` (10 lines). Then the same 10 inside colon bodies (`: _u1 <> ;  _u1` style, one invocation per line). Then a column-0 `PASS: cmp-survives` line via `DEPTH 0=`. Makefile: `--count 20 '^error -4: stack underflow'`.
  - [x] 5.7 Every line ≤ 128 chars including any `\` annotation (`feedback_tib_size_inline_comments`). No `BANK!`. Match how `tests/stack_words_tests.fth` ends (plain `\n`, no 0x1A).
- [x] **Task 6 — Makefile** (AC: 7, 9)
  - [x] 6.1 `COMPARISON_PROBE = tests/comparison_tests.fth` beside `STACK_WORDS_PROBE`.
  - [x] 6.2 Target `test-repl-comparisons` copying the `test-repl-stack-words` recipe (timeout + straddle message, `sed 's/$$/\r/'`, `BYE`, `tests/assert_verdicts.sh --label "REPL comparisons probe" --fail-line '^FAIL: cmp-'`, the `--count`, every tagged line, the PASS lines).
  - [x] 6.3 Add to `.PHONY` and to the `test-repl:` prerequisite list after `test-repl-stack-words`.
  - [x] 6.4 Run the target alone; then break one expectation (e.g. `'neA=0 -1 0 0 $$'`) to see it fail; restore.
- [x] **Task 7 — docs** (AC: 8)
  - [x] 7.1 `docs/ans-forth-core-compliance.md`: move the four rows (currently lines 433, 434, 439, 457) into "§6.2 Implemented" in § order (`0<>` and `0>` go after `.R` §6.2.0210; `<>` after them; `U>` after `TUCK` §6.2.2300). Notes column: `DEFCODE; check_underflow_2 as for =/U<` (or `check_underflow` for the 1-operand pair).
  - [x] 7.2 Recount and fix every place quoting §6.2 counts: summary table line 78, paragraph line 387 (also extend its "added by" list with `0<>`, `0>`, `<>`, `U>` added by Story 27.2), headings lines 391 and 419.
  - [x] 7.3 "Non-standard words" table (~line 858): add `<=` and `>=` rows (`logic.asm:LINE`, `Non-standard (antforth extension)`), next to `-ROT`.
  - [x] 7.4 Inserting words into `logic.asm` shifts later line numbers. The §6.1 rows for `=`, `<`, `>`, `0=`, `0<`, `U<` (`docs/ans-forth-core-compliance.md:189-194`) cite the exact DEFCODE lines today (127, 147, 172, 201, 216, 231); update them to the new lines. Re-run `grep -rn "logic.asm:" docs/ README.md` for any others.
  - [x] 7.5 `docs/dev_journal.md`: mark ` - <=, >=, <> ` and ` - 0>, 0<>` resolved with the existing suffix. Mark ` - U.R, U>` resolved as a whole: `U>` by this story, and `U.R` was already in the kernel (Story 10.8; `' U.R U.` → `9277` on the 30,830 B binary, 2026-10-08), so the entry reads ` - U.R, U> — RESOLVED 2026-MM-DD, Story 27.2 (U.R already present since Story 10.8)`.
  - [x] 7.6 `docs/dev_journal.md`: add an open dated section for the one-operand underflow gap, with the verified repro table from Dev Notes and the list of affected words. Don't mark it resolved; Story 27.6 fixes it, so name 27.6 in the entry.
  - [x] 7.7 `README.md` line 49: `21 / 46 (+ HOLDS) | ~46%` (or whatever the recount gives).
  - [x] 7.8 Leave `src/system.asm` `env_table` CORE-EXT comment for Story 27.5. Run `make check-doc-sync`; it must pass.
- [x] **Task 8 — verify and record** (AC: 9, 10, 11)
  - [x] 8.1 `make`, `wc -c build/antforth.com`; record the delta and compare per word with the budget table.
  - [x] 8.2 `make test` and `make test-repl` green; record the new PASS count.
  - [x] 8.3 If a banking probe now halts or times out, read `feedback_banking_probe_straddle_halt` first: +~180 B of kernel growth can push a probe body across `$8000`; fix the probe, not the kernel.
  - [x] 8.4 Write the S9 recipe into Dev Notes and post it in the review close message: type the AC1 tagged lines and the AC3 underflow lines at the MicroBeast prompt, plus the batnball check (Task 4.2 on hardware: `INCLUDE BATNBALL.FTH` after copying it to the CP/M disk **with a 0x1A terminator**, per `feedback_cpm_0x1a_eof_marker`, then play briefly and quit with `q`). The `<=` overflow cases are the ones most worth seeing on real silicon (see "The `SCF` borrow trick").

## Dev Notes

### Design: register-level sequences

Stack model: BC = TOS; `(SP)` = second (`project_tos_in_register`). Each word touches only HL and AF. `check_underflow*` clobbers AF, HL and preserves BC, DE, IX, IY, SP (`src/system.asm:639-740`). `LD r,r'`, `LD BC,nn` and `DEC BC` don't change flags, which every sequence below relies on.

```asm
; <> ( x1 x2 -- flag )
        CALL    check_underflow_2
        POP     HL              ; HL = x1
        OR      A
        SBC     HL, BC          ; Z iff x1 = x2
        LD      BC, 0
        LD      A, H
        OR      L
        JR      Z, .ne_done
        DEC     BC
.ne_done:
        NEXT

; 0<> ( x -- flag )
        CALL    check_underflow
        LD      A, B
        OR      C               ; Z iff x = 0
        LD      BC, 0
        JR      Z, .zne_done
        DEC     BC
.zne_done:
        NEXT

; 0> ( n -- flag )   true iff n is nonzero and bit 15 is clear
        CALL    check_underflow
        LD      A, B
        OR      C               ; Z iff n = 0
        LD      A, B            ; sign byte; flags unchanged
        LD      BC, 0
        JR      Z, .zgt_done
        RLA                     ; bit 15 -> carry
        JR      C, .zgt_done    ; negative
        DEC     BC
.zgt_done:
        NEXT

; U> ( u1 u2 -- flag )
        CALL    check_underflow_2
        POP     HL              ; HL = u1
        SCF
        SBC     HL, BC          ; u1 - u2 - 1: borrow iff u1 <= u2
        LD      BC, 0
        JR      C, .ugt_done
        DEC     BC
.ugt_done:
        NEXT

; <= ( n1 n2 -- flag )   ; antforth extension
        CALL    check_underflow_2
        POP     HL              ; HL = n1
        SCF
        SBC     HL, BC          ; n1 - n2 - 1 < 0 iff n1 <= n2; less iff S XOR V
        LD      BC, 0
        JP      PO, .le_no_ov
        JP      M, .le_done     ; S=1, V=1 -> not less
        DEC     BC              ; S=0, V=1 -> less
        JR      .le_done
.le_no_ov:
        JP      P, .le_done     ; S=0, V=0 -> not less
        DEC     BC              ; S=1, V=0 -> less
.le_done:
        NEXT

; >= ( n1 n2 -- flag )   ; antforth extension
        CALL    check_underflow_2
        POP     HL              ; HL = n1
        OR      A
        SBC     HL, BC          ; n1 - n2; n1 >= n2 iff NOT (S XOR V)
        LD      BC, 0
        JP      PO, .ge_no_ov
        JP      P, .ge_done     ; S=0, V=1 -> less -> false
        DEC     BC              ; S=1, V=1 -> not less -> true
        JR      .ge_done
.ge_no_ov:
        JP      M, .ge_done     ; S=1, V=0 -> less -> false
        DEC     BC              ; S=0, V=0 -> not less -> true
.ge_done:
        NEXT
```

`>=` is `<` (`src/logic.asm:146-164`) with the two sign tests swapped. `<=` is `<` with `SCF` in place of `OR A`. Both keep the `LD BC,0` / `DEC BC` idiom the epic asks for.

Use unique local labels; sjasmplus scopes `.label` to the last non-local label, so collisions with `.eq_done` etc. aren't possible, but distinct names keep listings readable.

### The `SCF` borrow trick (used by `U>` and `<=`)

With carry set, `SBC HL,BC` computes `HL - BC - 1`. On the Z80 the C, S and P/V flags describe that whole operation, so:

- Unsigned: borrow iff `u1 - u2 - 1 < 0` iff `u1 ≤ u2`. So no borrow ⇔ `u1 > u2`. One conditional jump instead of the two (`JR C` + `JR Z`) a plain `OR A` version needs; 2 B smaller.
- Signed: `S XOR V` is the sign of the true (17-bit) result. `n1 - n2 - 1 < 0` iff `n1 ≤ n2`.

Traces for the cases where the carry-in itself changes the overflow result:

| n1 n2 | true result | 16-bit | S | V | S⊕V | `<=` |
|---|---|---|---|---|---|---|
| `$8000 $7FFF` | -65536 | `$0000` | 0 | 1 | 1 | -1 ✓ |
| `$7FFF $8000` | 65534 | `$FFFE` | 1 | 1 | 0 | 0 ✓ |
| `$8000 0` | -32769 | `$7FFF` | 0 | 1 | 1 | -1 ✓ |
| `0 $8000` | 32767 | `$7FFF` | 0 | 0 | 0 | 0 ✓ |
| `$8000 $8000` | -1 | `$FFFF` | 1 | 0 | 1 | -1 ✓ |

`$8000 0 <=` is the case that only overflows because of the carry-in. If the emulator or the hardware got SBC-with-carry overflow wrong, that line is where it would show. That's why AC1 includes it and why the S9 recipe should include it.

If the `SCF` version misbehaves anywhere, the fallback for `<=` is "`>` with the sign tests swapped" (6 B larger: `>`'s register swap). Record which one shipped.

### One-operand words don't check underflow (found while drafting)

The epic asks `0<>`/`0>` to copy the underflow check of `0=`/`0<`. Those two have none. Verified on iz-cpm-banking 2026-10-08 against the 30,830 B binary, typing `DEPTH . <word> DEPTH .` on an empty stack:

| Word | Output |
|---|---|
| `0=` `0<` `1+` `1-` `2*` `2/` `INVERT` `ABS` `?DUP` `C@` `CELLS` `CELL+` `CHAR+` | `0 0  ok` — no error; the word ran on the phantom BC |
| `DUP` | `0 1  ok` — no error; a phantom cell is now on the stack |
| `NEGATE` `DROP` `@` `S>D` | `0 error -4: stack underflow` |

So "same check as `0=`" means "no check", and copying it would add two more words to a list that is already inconsistent (`NEGATE` checks, `INVERT` doesn't). This story takes the same line as Story 27.1 took with `-ROT` vs `ROT`: new words don't copy a known defect. `0<>` and `0>` call `check_underflow` (+3 B each, existing helper, same `-4`).

Fixing the existing words is not in scope: it touches about 14 words across several files, and some (`0=`, `1+`, `DUP`) are on hot paths where a `CALL` costs ~50 T-states per use. Task 7.6 records it in `docs/dev_journal.md` with the table above; Story 27.6 fixes it. Per `feedback_no_preexisting_discharge` it is filed, not accepted.

### Byte budget (itemised, est. 179 B)

Header (DEFCODE, `src/macros.asm:66+`): fat link 3 B + count/flags 1 B + name bytes. 27.1 measured exactly this formula (+76 B estimated, +76 B measured). `NEXT` = 7 B. Opcode sizes: `CALL nn` 3, `LD BC,nn` 3, `JP cc,nn` 3, `JR`/`JR cc` 2, `SBC HL,BC` 2, and 1 B each for `POP HL`, `OR A`, `SCF`, `LD r,r'`, `OR r`, `DEC BC`, `RLA`.

| Word | Header | Body | Total |
|---|---|---|---|
| `<>` | 3+1+2 = 6 | CALL 3 + POP 1 + OR 1 + SBC 2 + LD BC 3 + LD 1 + OR 1 + JR 2 + DEC 1 + NEXT 7 = 22 | 28 |
| `0<>` | 3+1+3 = 7 | CALL 3 + LD 1 + OR 1 + LD BC 3 + JR 2 + DEC 1 + NEXT 7 = 18 | 25 |
| `0>` | 3+1+2 = 6 | CALL 3 + LD 1 + OR 1 + LD 1 + LD BC 3 + JR 2 + RLA 1 + JR 2 + DEC 1 + NEXT 7 = 22 | 28 |
| `U>` | 3+1+2 = 6 | CALL 3 + POP 1 + SCF 1 + SBC 2 + LD BC 3 + JR 2 + DEC 1 + NEXT 7 = 20 | 26 |
| `<=` | 3+1+2 = 6 | CALL 3 + POP 1 + SCF 1 + SBC 2 + LD BC 3 + JP 3 + JP 3 + DEC 1 + JR 2 + JP 3 + DEC 1 + NEXT 7 = 30 | 36 |
| `>=` | 3+1+2 = 6 | same opcodes as `<=` with `OR A` for `SCF` = 30 | 36 |
| **Total** | | | **179** |

The epic allocated ≈ 150 B to this story. The 29 B over comes from: the epic's figure predates the per-word itemisation (it assumed shorter `<=`/`>=`), plus 6 B for the underflow checks on `0<>`/`0>`. Epic running total after this story: 76 (27.1) + 179 = 255 B, leaving 245 B of the 500 B envelope for 27.3 (≈30) and 27.4 (≈70). If the measured delta differs from 179 B, explain it word by word.

Not done, to keep the words independent: sharing a tail between `<`, `>`, `<=`, `>=` (would save ~20 B but makes `<`/`>` jump into shared code, and touches existing hot words).

### `examples/batnball.fth`

Lines 84–86 today:

```forth
\ utility words 
: >= ( n1 n2 -- flag ) < 0= ;
: <= ( n1 n2 -- flag ) > 0= ;
```

Uses at lines 139–140 (`batleftx @ >=`, `batrightx @ <=`) need no change; the kernel words have the same stack effect and result. The file isn't in `disk/a/`, no Makefile target loads it, and nothing in `tests/` references it, so the load check in Task 4.2 is a manual one recorded in Debug Log, not a new Makefile target.

No other in-tree definitions of the six names exist (`grep -rn ": <>\|: 0<>\|: 0>\|: U>\|: <=\|: >=" disk/ examples/ tests/` → only batnball, 2026-10-08). No test asserts any of the six is undefined.

### Placement and names

| Word | After | Labels |
|---|---|---|
| `<>` | `=` | `w_NOT_EQUALS` / `w_NOT_EQUALS_cf` |
| `<=` | `>` | `w_LESS_EQUALS` / `w_LESS_EQUALS_cf` |
| `>=` | `<=` | `w_GREATER_EQUALS` / `w_GREATER_EQUALS_cf` |
| `0<>` | `0=` | `w_ZERO_NOT_EQUALS` / `w_ZERO_NOT_EQUALS_cf` |
| `0>` | `0<` | `w_ZERO_GREATER` / `w_ZERO_GREATER_cf` |
| `U>` | `U<` | `w_U_GREATER` / `w_U_GREATER_cf` |

Names follow the file's existing `w_EQUALS`, `w_ZERO_EQUALS`, `w_U_LESS`, `w_GREATER`. `logic.asm` indents with 4 spaces (unlike `stack_ops.asm`'s 8); match it. Kernel words land in fixed memory below `$8000`, findable from every bank; no banking change.

### Testing standards

- Test through the Forth threading model, REPL-piped (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Verdict greps are column-0 anchored; echoed source starts with `."` or `:` so it can't false-green (header of `tests/stack_words_tests.fth`).
- `.` prints signed with a trailing space, so a TRUE prints `-1 `. Assert the whole tagged line ending in `$$`.
- `$`-prefixed hex literals work in DECIMAL (checked: `$8000 .` → `-32768`). Keep the probe in DECIMAL; if a number looks wrong, check BASE first (`project_hex_base_leak_literal_truncation`).
- `assert_verdicts.sh` options: `--label`, `--mode`, `--fail-line`, `--count N REGEX LABEL`, `--present REGEX LABEL`; config flags before assertions (`tests/assert_verdicts.sh:17-36`).
- Underflow text: `error -4: stack underflow`.

### Previous story (27.1) — what carries over

- The header-size formula and NEXT = 7 B gave an exact estimate; trust it, but measure.
- Probe/Makefile shape: `tests/stack_words_tests.fth` + `test-repl-stack-words` (Makefile:656) is the template to copy. Its red run (words undefined) failed loudly through the pre-flight `'` line; do the same red run here before writing the words.
- 27.1 fixed `ROT`'s depth check at 0 B on the same reasoning this story applies to `0<>`/`0>`; the lead accepted it.
- Inserting words shifted line citations in the compliance doc and `register-conventions.md`; 27.1 had to chase them. Do the same for `logic.asm:` citations (Task 7.4).
- 27.1's S9 smoke left one unexplained anomaly (a stray `5` on the emulator but not hardware after `variable v 5 42 v ! v ?`). Unrelated to comparisons; don't chase it here.

### Git intelligence

Last commit `2868649 feat: add NIP, TUCK, -ROT and ? (Story 27.1)` touched `Makefile`, `README.md`, compliance doc, dev journal, `register-conventions.md`, `src/formatting.asm`, `src/stack_ops.asm`, `tests/stack_words_tests.fth`. Commit message style: `feat: add <words> (Story 27.N)` plus a body line for any side change. No Claude co-author trailer (`feedback_no_claude_coauthor`).

### Project Structure Notes

- Files touched: `src/logic.asm`, `examples/batnball.fth`, `tests/comparison_tests.fth` (new), `Makefile`, `docs/ans-forth-core-compliance.md`, `docs/dev_journal.md`, `README.md`, this story file, `sprint-status.yaml`.
- Source comments say what and why, never story/date provenance (`feedback_source_comment_discipline`).
- No architecture doc covers Phase 7; the epic's "Additional Requirements" are the constraints. No external libraries; no web research needed.

### References

- Epic: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — FR-P7-4..9, FR-P7-13, NFR-P7-1..7, Story 27.2 ACs, "Comparisons are CODE words" decision.
- Sibling words: `src/logic.asm:122-241` (`=`, `<`, `>`, `0=`, `0<`, `U<`).
- Underflow helpers: `src/system.asm:639` (`check_underflow`), `:664` (`_2`), `:794` (`do_underflow_error`).
- DEFCODE macro and `NEXT`: `src/macros.asm:30-70`.
- Probe/Makefile template: `tests/stack_words_tests.fth`, Makefile:656-664, `test-repl:` prerequisites (Makefile ~1937).
- Compliance doc: `docs/ans-forth-core-compliance.md:78, 387, 391-417, 419-460, 858-870`.
- `README.md:49`; `docs/dev_journal.md:16-17, 25`.
- ANS Forth 1994 §6.2.0260 `0<>`, §6.2.0280 `0>`, §6.2.0500 `<>`, §6.2.2350 `U>`.

### Project-lead decisions (2026-10-08)

1. **`0<>`/`0>` call `check_underflow`.** Confirmed. Task 2.3's overrule path does not apply.
2. **The one-operand gap is Story 27.6** (`27-6-one-operand-underflow-checks`, Phase 7, before the 27.5 close-out). Task 7.6's dev-journal entry should point at Story 27.6. Don't fix `0=`/`0<` or any other existing word in this story.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Pre-edit baseline: `wc -c build/antforth.com` = 30,830 B (matches draft-time reading). `make test-repl` = 1027 PASS / 0 FAIL / 2 SKIP.
- Red run: `make test-repl-comparisons` before any source edit failed with `-13: undefined word` on the pre-flight `'` line and on every probe line; the verdict assertions went missing.
- Mutation check (Task 6.4): changed `'neA=0 -1 0 -1 $$'` to `'neA=0 -1 0 0 $$'`; target failed with `expected 'neA=0 -1 0 0 $' at column 0 in output`. Restored.
- batnball load check (Task 4.2), file copied to a scratch dir as `BATNBALL.FTH`:

  ```
  INCLUDE BATNBALL.FTH
   ok
   ok
  ' >= U. ' <= U.
  3403 3367  ok
  ```

  No error lines; both xts are below `$8000` (kernel fixed memory), so the call sites resolve to the kernel words.
- `S" CORE-EXT" ENVIRONMENT? .S` → `<2> 0 -1` (known, value false).
- `DEPTH . 0<> DEPTH .` and `DEPTH . 0> DEPTH .` on an empty stack → `0 error -4: stack underflow`.

### Completion Notes List

- Six DEFCODE words added to `src/logic.asm` next to their siblings, using the register sequences from Dev Notes unchanged. `<=` shipped as the `SCF` version (not the `>`-swap fallback); all five overflow trace cases pass on the emulator.
- `0<>` and `0>` call `check_underflow`; the four two-operand words call `check_underflow_2`. All 20 underflow cases (10 interpret, 10 compiled) raise `-4`.
- Byte delta: 30,830 → 31,009 B = **+179 B**, equal to the itemised estimate. Per word from the symbol table: `<>` 28, `<=` 36, `>=` 36, `0<>` 25, `0>` 28, `U>` 26, each matching its row in the budget table. Epic running total 76 + 179 = 255 B of 500 B.
- Regression: `make test` passes. `make test-repl` = 1046 PASS / 0 FAIL / 2 SKIP (baseline 1027; +19 from the new target: 18 tagged/PASS lines + 1 underflow count). No banking probe halted or timed out.
- `make check-doc-sync`: 0 drift (15 advisory items, unrelated).
- §6.2 recount from the table rows: 21 implemented / 25 omitted. Updated in the summary table, the §6.2 paragraph, both headings and README (`21 / 46 (+ HOLDS) | ~46%`). The §6.1 rows for `<`, `>`, `0=`, `0<`, `U<` now cite lines 167, 192, 268, 300, 335 (`=` stays at 127). No other `logic.asm:` citations exist in `docs/` or `README.md`.
- Dev journal: three backlog entries marked resolved; new OPEN entry for the one-operand underflow gap, pointing at Story 27.6.
- `src/system.asm` env_table CORE-EXT comment left for Story 27.5, as specified.

#### S9 hardware-smoke recipe

At the MicroBeast prompt (fresh boot, `DECIMAL`):

1. Type the eight interpret-level lines from `tests/comparison_tests.fth` (`." neA=" …` through `." ge2A=" …`). Expected:
   - `neA=0 -1 0 -1`
   - `zneA=0 -1 -1 -1`
   - `zgtA=0 -1 0 -1 0 -1`
   - `ugtA=-1 0 0 -1 0`
   - `leA=-1 -1 0 -1 0`
   - `le2A=-1 -1 0 -1 -1` ← the SBC-with-carry overflow cases; `$8000 0 <=` must print `-1`
   - `geA=-1 0 -1 0 -1`
   - `ge2A=0 0 -1 -1`
2. Underflow, one per line on an empty stack: `<>`, `1 <>`, `U>`, `1 U>`, `<=`, `1 <=`, `>=`, `1 >=`, `0<>`, `0>` → each prints `error -4: stack underflow`. Then `DEPTH .` → `0`.
3. batnball: copy `examples/batnball.fth` to the CP/M disk as `BATNBALL.FTH` **with a 0x1A terminator** (`feedback_cpm_0x1a_eof_marker`). `INCLUDE BATNBALL.FTH` → no errors; `' >= U. ' <= U.` → two numbers below 32768. Play briefly (bat-edge collisions use `>=`/`<=`), quit with `q`.

#### S9 hardware result (2026-10-08)

- All eight result lines matched, including `le2A=-1 -1 0 -1 -1`. All ten underflow lines raised `-4` (`0>` was typed in a second session); `DEPTH` was 0 afterwards. Transcript: `~/Downloads/beastty-20261008-125822.txt`.
- batnball loaded, and `' >= U. ' <= U.` → `3403 3367`, the same as on the emulator. `play` then hung on the first frame. Cause (not 27.2): the game read its tick double from fixed firmware RAM at `0xff04`/`0xff06`. On the current firmware `0xff04` is constant (513) and the counter starts at `0xff06` (it rose by 1317 between two reads, the same as `TICKS`). The low cell never changed, so `delta` was always 0, the ball never moved, and `key?` (only checked inside the bat-timer branch) was never reached.
- Fixed in `examples/batnball.fth`: `update_delta` reads the kernel `TICKS` (same `( lo hi )` order) and the `ticks_lo`/`ticks_hi` constants are gone. A second, older bug is also fixed: the bat edges were computed once at load from `batx` = 0, so the bat sat at x = -2..2. New `set_batedges` recomputes them in `init_game` and `batmove`, and `batmove` now also clamps to `batmaxx`. Emulator check: `init_game` → batx 40, edges 38/42; `100 batright` → 78, 76/80; `100 batleft` → 3, 1/5. `play` itself needs a hardware re-test (the emulator never fires the tick interrupt).
- Hardware re-test of the fixed batnball: PASS (ball moves, bat moves and clamps at both edges, scoring and speed-up work, game over and `q` quit work).

### File List

- `src/logic.asm` (modified — six new words, file header)
- `tests/comparison_tests.fth` (new)
- `Makefile` (modified — `COMPARISON_PROBE`, `test-repl-comparisons`, `.PHONY`, `test-repl` prerequisites)
- `examples/batnball.fth` (modified — local `>=`/`<=` removed)
- `docs/ans-forth-core-compliance.md` (modified)
- `docs/dev_journal.md` (modified)
- `README.md` (modified)
- `_bmad-output/implementation-artifacts/27-2-comparison-words-ne-0ne-0gt-ugt-le-ge.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

### Change Log

- 2026-10-08: Added `<>`, `0<>`, `0>`, `U>` (Core Ext) and `<=`, `>=` (extension) as CODE words; probe + Makefile target; batnball uses kernel words; compliance doc, dev journal, README updated. +179 B.
- 2026-10-08: S9 hardware pass for the six words. batnball: tick source switched to `TICKS` (firmware counter moved) and bat-edge tracking fixed.
