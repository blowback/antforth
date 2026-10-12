# Story 27.7: Cross-bank lookup hides or hangs on kernel words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer using banks,
I want a word I define in one bank never to hide or hang a kernel word in another,
so that `CR`, `BANK!` and the rest are always found, whatever I name my words and wherever their headers land.

**Covers:** FR-P7-15; NFR-P7-1, NFR-P7-6. Source: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` § "Story 27.7".

**Draft-time trace (2026-10-12, HEAD `bfb9a48`, 31,348 B).** FIND is not at fault. All three repros in the dev-journal entry use `BANKS-CLEAR $22 +BANK $22 +BANK …`. `$22` is bank 0's own portal page, and `+BANK` doesn't dedup, so every logical bank is the same physical RAM. Bank N's `$8000` is bank M's `$8000`. The next `WORD` parse at one bank's `HERE` writes over another bank's header, and the bucket walk follows a corrupted fat link. The same three repros with distinct pages (`$22 $35 $36 … +BANK`) all pass. Separately, the trace found one real defect that has nothing to do with aliasing: a bank-N `HERE` near `$C000` makes the parse buffer and `PAD` write past `$C000` into fixed RAM, over bank 0's dictionary. Details in Dev Notes "Root cause".

**Project-lead decisions (2026-10-12):** (1) `+BANK` refuses a page that is already in the active list, and every `$22 +BANK $22 +BANK …` use in tests and `disk/a/` fixtures moves to distinct pages; (2) the spill is fixed by lowering the banked ceiling. `check_banked_headroom` refuses growth that would leave less than the parse buffer + `PAD` reserve (168 B) below `$C000`. The buffers are not moved to fixed RAM.

## Acceptance Criteria

1. **Root cause recorded.** Dev Notes "Root cause" states the cause of each of the three repros with code locations, why the name matters (shared hash bucket) and why the address matters (overlap with the other bank's parse buffer at `HERE`), and that all three share one cause (page aliasing). It also states the separate spill defect. The dev pass re-runs the draft-time experiments (Dev Notes "Experiments") on the pre-edit binary and corrects anything that doesn't reproduce.
2. **`+BANK` refuses duplicates.** `+BANK` with a page already in `active_pages[0..bank_count-1]` prints `dup?` and raises `-2` (ABORT" convention, like `cap?`/`probe?`), before any probe or MMU write, leaving `BANKS` and the active list unchanged. After `BANKS-CLEAR`, `$22 +BANK` is accepted (empty list). The boot command-line parser still prints `dup? NN` and skips the page, now through the same shared scan.
3. **Banked ceiling.** On a bank N > 0, any dictionary growth whose one-past-end exceeds `$BF58` (`$C000` − 168) raises `-8`. One-past-end exactly `$BF58` is accepted. Bank 0 is unchanged (strict no-op). The 168 comes from an EQU derived from `PAD_OFFSET` and the `/PAD` size, not a bare literal. `.BANKS` FREE for banks N > 0 is computed against the same ceiling, so an empty bank shows 16,216, not 16,384.
4. **No spill.** With distinct pages: bank 0 `$C000 HERE - 3 - ALLOT  42 VALUE B0` (header straddling `$C000`), then `6 BANK!` driven to the new brink, then a line with a 31-character token and a `PAD` write (`PAD 84 66 FILL`). Back in bank 0, `B0 .` prints `42`. On the pre-edit binary this case gives `-13` (Dev Notes, experiment s1).
5. **Repros pass.** Under iz-cpm-banking with distinct pages, `_by`/`BANK!`, `_qk`/`CR` and `B0`/`CR` all find the kernel word, with no `-13` and no hang. The same three with the original `$22 +BANK $22 +BANK …` setup stop at the second `+BANK` with `dup?` / `-2`.
6. **Original names restored.** `tests/banking_tests_23_6.fth` case F goes back to `B0`, and `tests/qdo_tests.fth`'s banked word goes back to `_qk`. Both run on distinct pages, and the "names avoid the open bank-lookup bug" comments are removed (also in `tests/again_tests.fth`).
7. **New probe.** `tests/bank_lookup_tests.fth` plus Makefile target `test-repl-bank-lookup`, a prerequisite of `test-repl` after `test-repl-underflow`. It covers AC2 (dup refused, list unchanged, accepted after `BANKS-CLEAR`), AC3 (accept at `$BF58`, `-8` one byte over, bank-0 no-op), AC4 and AC5. Lines ≤ 128 chars. It was seen to fail on the unmodified binary.
8. **Timeouts.** Every Makefile recipe line that pipes into `$(IZCPM)`/`$(IZCPM_BANKING)` inside a bank-driving target (`test-repl-banking`, every `test-repl-banking-isolated-*`, `test-repl-banking-23-6`, `-23-7`, `-23-9`, `test-repl-cr-21-3`, and `test-straddle-regression` if it pipes directly) runs under `timeout $(PROBE_TIMEOUT)`, with an rc 124 `FAIL:` branch that exits 1. A hang reports FAIL instead of stalling `make test`.
9. **Probes moved to the new ceiling and to distinct pages.** Every probe that drives a bank to `$C000 HERE - k -` is re-based to `$BF58 HERE - k -`, keeping what each case is testing (cross by one → `-8`; end exactly at the ceiling → accepted; 23-6 case G wrap). Assertions on printed `HERE` values move with them (e.g. `^49152 error -8` → `^48984 error -8`). Every `$22 +BANK` that would now hit `dup?` moves to a distinct page from the boot list (`$35`–`$3F`). `banking_tests.fth` probes 6 and 8, which append `$22` to the boot-populated list, are changed so they still test what they say.
10. **Regression.** `make test` passes. `make test-repl` is 0 FAIL with the re-measured baseline plus the new probe, none removed. All banking targets, `test-straddle-regression`, `lint-banking-probes`, `test-file-sanity`, `check-doc-sync` and **every multitasker/semaphore/mutex/mailbox target** pass (they are not `test-repl` prerequisites; `test-repl-multitasker-bank` has 14 B of TCB room to spare, see Dev Notes "Byte budget").
11. **Docs.** The `docs/dev_journal.md` entry "2026-10-08 (OPEN, Story 27.7)" is retitled RESOLVED with the real cause (aliasing + the separate spill) and the fix. `docs/throw-codes.md` `-8` row and the banking docs that state the `$C000` banked limit name the new ceiling. Source comments on `+BANK` ("No dedup at this surface") and `-BANK` ("leaving subsequent duplicates intact") are corrected. `disk/a/` fixtures that change stay 0x1A-terminated.
12. **Budget.** The real byte delta is recorded and compared item by item with "Byte budget" (est. ≈ +12 B), with the Epic 27 running total.
13. **Hardware.** S9 smoke recipe (Dev Notes, includes the original `B0`/`CR` hang repro) run on real MicroBeast and posted in the closing review chat message.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 31,348 B (2026-10-12, HEAD `bfb9a48`) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (27.6 close reported 1126 PASS / 0 FAIL / 2 SKIP before its review fix added `uw`/`ux`/`uy` — re-measure).
- [x] Run the multitasker targets on the unmodified binary and record that they pass (`test-repl-multitasker-bank` especially), so a later failure is known to be this story's.
- [x] Re-run experiments r1–r3, dr1–dr3, v1–v3, s1 (Dev Notes "Experiments") on the unmodified binary; record results (AC1).

### Story tasks

- [x] **Task 1 — confirm the trace** (AC: 1)
  - [x] 1.1 Re-run the experiments; fill in "Root cause" with anything that differs.
  - [x] 1.2 Grep for other transient writers above `HERE` in a bank: everything that writes at `HERE`+n without advancing `HERE` (`WORD` in `src/strings.asm`, `PAD` users, interpret-mode `S"`/`C"` buffers if any, `INCLUDE`/file-name staging, `NUMBER?`/`>NUMBER` scratch). If any writes past `HERE+167`, raise the reserve and say why.
- [x] **Task 2 — banked ceiling** (AC: 3)
  - [x] 2.1 Add the EQUs (e.g. in `src/constants.asm` next to `PAD_OFFSET`): `PAD_SIZE EQU 84`, `BANKED_TRANSIENT_RESERVE EQU PAD_OFFSET + PAD_SIZE`, `BANKED_CEILING EQU SLOT2_WINDOW_BASE + 0x4000 - BANKED_TRANSIENT_RESERVE` (= `$BF58`). Point the `/PAD` row in `env_table` (`src/system.asm`, `/PAD` → `PAD_OFFSET` today) at `PAD_SIZE` so the reported size and the reserve can't drift. Value unchanged (84).
  - [x] 2.2 `src/banking.asm:176` `check_banked_headroom`: `LD HL, BANKED_CEILING`. Rewrite the header comment (`:149-168`) to say the ceiling is `$C000` less the parse-buffer/`PAD` reserve, and why (bank-N transient buffers above `HERE` would otherwise write into fixed RAM at `$C000+`, which is bank 0's dictionary space once bank 0 grows past `$C000`).
  - [x] 2.3 `src/banking.asm:917` (`dot_banks_row_usedfree`): FREE against `BANKED_CEILING` for N > 0. Check the bank-0 row and the TOTAL line still add up.
  - [x] 2.4 Grep `src/` for other `0x4000`/`$C000` window-top uses that mean "banked dictionary limit" (`grep -n "0x4000\|C000" src/*.asm`) and switch only those. Leave MMU/slot-geometry uses alone.
- [x] **Task 3 — `+BANK` dedup** (AC: 2) — design in Dev Notes "`+BANK` dedup".
  - [x] 3.1 Add `page_in_active_list` next to `cl_probe_and_add` in `src/banking.asm` (resident; `+BANK` calls it at run time).
  - [x] 3.2 `cl_process_page` (`src/antforth.asm:551-569`): replace the inline `.dscan` with `CALL page_in_active_list / JR C, .dup`. Boot output unchanged.
  - [x] 3.3 `w_PLUS_BANK_cf`: after the cap check, `CALL page_in_active_list / JR C, .abort_dup`. Share the print+THROW tail between `.abort_dup`, `.abort_probe` and `.abort_cap`.
  - [x] 3.4 Fix the `+BANK` header comment ("No dedup at this surface …") and the `-BANK` comment about duplicates.
- [x] **Task 4 — probe conversions** (AC: 6, 9) — conversion rules in Dev Notes "Probe conversions".
  - [x] 4.1 `tests/*.fth`, `tests/straddle_repro.fth.in`: `$22 +BANK` repeats → distinct pages; `$C000 HERE -` brinks → `$BF58 HERE -`.
  - [x] 4.2 `tests/banking_tests.fth` probes 6 and 8.
  - [x] 4.3 `disk/a/P193BKN.FTH`, `P193BNK2.FTH`, `P193IRON.FTH`, `STRADH.FTH`, `STRADP.FTH`, `STRADG.FTH`: same conversion, 0x1A EOF kept (`feedback_cpm_0x1a_eof_marker`). Check `xxd | tail -1` after editing.
  - [x] 4.4 23-6 case F → `B0`; add a witness after case G that `0 BANK! B0 .` prints `42` (AC4 in the existing probe). 27.4 banked word → `_qk`. Remove the "names avoid the open bug" comments (23-6, qdo, again).
  - [x] 4.5 Makefile assertions on printed brink `HERE` values (`^49152 error -8` in `test-repl-qdo` and the AGAIN target, any `.BANKS` FREE figure, `straddle_repro_sweep.sh` calibration) updated.
- [x] **Task 5 — new probe `tests/bank_lookup_tests.fth`** (AC: 7) — sketch in Dev Notes "Probe file". Starts with `DECIMAL`; plain `\n` end, no 0x1A. Write it first and see it fail on the unmodified binary.
- [x] **Task 6 — Makefile** (AC: 7, 8)
  - [x] 6.1 `BANK_LOOKUP_PROBE = tests/bank_lookup_tests.fth` after `UNDERFLOW_PROBE`; target `test-repl-bank-lookup` after `test-repl-underflow`, same recipe shape as `test-repl-qdo` (Makefile:694-704); add to `.PHONY` (line 56) and to the `test-repl:` prerequisites (Makefile:1996) after `test-repl-underflow`.
  - [x] 6.2 Add `timeout $(PROBE_TIMEOUT)` + rc 124 FAIL branch to every untimed bank-driving recipe line (list in Dev Notes "Untimed recipe lines"). Keep each target's existing verdict logic; only the pipeline and the rc check change.
  - [x] 6.3 Break one expectation in the new target to see it fail; restore.
- [x] **Task 7 — docs** (AC: 11)
  - [x] 7.1 `docs/dev_journal.md`: retitle the 27.7 entry `(RESOLVED <date>, Story 27.7)`, add a resolution paragraph: aliasing via `$22 +BANK` repeats, shared buckets 1 and 41, `+BANK` now refuses duplicates, the separate spill and the `$BF58` ceiling, byte delta.
  - [x] 7.2 `docs/throw-codes.md:184` `-8` row; `docs/antforth-banking-design.md`, `docs/phase4-memory-map.md`: where they state the banked limit as `$C000`, add the ceiling. Leave dated blog posts and history alone.
  - [x] 7.3 Line insertions in `src/banking.asm`/`src/antforth.asm` shift citations: `grep -rn "banking.asm:[0-9]\|antforth.asm:[0-9]" docs/ README.md`, re-point live docs, then `make check-doc-sync`.
- [x] **Task 8 — verify and record** (AC: 10, 12, 13)
  - [x] 8.1 `make`, `wc -c`; record the delta item by item against "Byte budget".
  - [x] 8.2 Full regression list from AC10. If `test-repl-multitasker-bank` fails with `-8` on the second `TASK`, the kernel growth used up its 14 B; stop and raise it with the project lead (options are in the dev-journal entry "2026-10-11 (OPEN) — fixed RAM below `$8000` now holds only two TCBs"). Don't reshuffle that probe again without a decision.
  - [x] 8.3 Write the S9 recipe into Dev Notes and post it in the review close message.

## Dev Notes

### Root cause (draft 2026-10-12, HEAD `bfb9a48`, 31,348 B — re-verify, AC1)

**Shared buckets** (hash in `src/hash.asm`: per char `A ^= upper(c); RLC A`, then `AND 63`):

| Name | Bucket | | Name | Bucket |
|---|---|---|---|---|
| `BANK!` | 1 | | `CR` | 41 |
| `_by` | 1 | | `_qk` | 41 |
| `_zz` | 39 | | `B0` | 41 |
| `BANK@` | 3 | | `ZZ` / `Q7` / `F0` | 29 / 43 / 57 |

Every "works" name in the journal is in a different bucket from its victim; every "fails" name shares it. So the victim is reached only through the user word's header, and a bad header breaks the chain.

**Why the header is bad: page aliasing.** `+BANK` appends without a dup check (`src/banking.asm` `+BANK` comment: "No dedup at this surface: duplicate pages append"). `BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK` builds `active_pages[] = 22 22 22 22`. `$22` is the boot slot-2 page = bank 0's portal page (`docs/antforth-banking-redesign.md:85`, `docs/adr-19-5-cross-bank-dispatch.md:81`). Every logical bank is the same physical RAM. Bank-N `HERE` starts at `$8000` (`src/antforth.asm:206-216`), and `WORD` stages its counted string at `HERE` (`src/memory.asm:168-176`).

- **`_by`/`BANK!`:** `_by` is built at bank 2's `$8000`: fat link `$8000-$8002`, count_flags `$8003`, name `$8004`. After `3 BANK!` the next token (`0`) is parsed at bank 3's `HERE` = `$8000`, the same RAM. That overwrites `_by`'s fat link. The walk for `BANK!` (`src/dictionary.asm` `search_wid_for_name`, `.sw_skip`) reads the clobbered link and never reaches the kernel `BANK!` → miss → `-13`. `_by` at `$8014` (v3) or `$BF9C` survives because the parse buffer only covers `$8000..$8000+n`.
- **`_qk`/`CR`:** same mechanism: `_qk` at bank 1's `$8000`, then the `CR` token is parsed at bank 2's `$8000`.
- **`B0`/`CR` hang:** bank 0 `B0` at `$BFFD`: fat link `$BFFD-$BFFF` in page `$22`, the rest at `$C000+` (fixed RAM; bank 0 has no ceiling). Bank 6 is also page `$22`; driven to `HERE` = `$BFFE`, its parse buffer overwrites `B0`'s link bytes at `$BFFE-$BFFF` (link high byte + bank byte) *and* `B0`'s count_flags/name at `$C000+`. The walk follows a garbage fat pointer. Depending on layout it loops (hang, the 31,077 B binary and hardware) or ends (`-13`, today's 31,348 B binary).
- **"`_by` aborted by `-8`, then any `:` in bank 3"** (journal row 4): not reproduced at draft; with aliasing, bank 3's header at `$8000` lands on bank 2's RAM, so expect the same class. The dev pass may re-run it on distinct pages to confirm it passes.
- **Hardware matches:** the journal's hardware runs used the same `$22 +BANK` setup, so they alias too.

**The real defect: transient buffers spill past `$C000`.** This is independent of aliasing. Bank N > 0 may grow `HERE` to `$C000` (`check_banked_headroom`, `src/banking.asm:169-181`). `WORD` writes `HERE..HERE+32` and `PAD` is `HERE+84..HERE+167` (`/PAD` = 84, `src/system.asm:568-569`). Near the top, these writes land at `$C000+`, which is fixed RAM shared by every bank, and bank 0's dictionary continues there. Experiment s1 (distinct pages): bank-0 `B0` straddling `$C000`, bank 6 at `$BFFE`, one long token → back in bank 0, `B0` is `-13`. The `pic_buf` (`<# #>`) is in the UserArea (fixed), and `num_buf` is a fixed kernel buffer, so neither is affected.

**FIND itself:** the walk's page-in (`sw_map_bank`) snapshots the search name to `sw_name_buf` before the first switch and restores slot 2 on exit. Nothing in the trace points at it. No change.

### Dev-pass verification and corrections (2026-10-12, AC1)

Pre-edit baseline: 31,348 B (confirmed, not copied); `make test-repl` 1129 PASS / 0 FAIL / 2 SKIP; all 11 multitasker/semaphore/mutex/mailbox targets green; every banking target, `test-straddle-regression`, `lint-banking-probes`, `test-file-sanity`, `check-doc-sync`, `make test` green.

Experiments r1–r3, dr1–dr3, v1–v3 and s1 re-run on the pre-edit binary: every result matches the draft table (v2 prints `HERE` signed: -32750 / -32768 = 32786 / 32768). Journal row 4 (`_by` aborted by `-8`, then a `:` in bank 3) re-run on distinct pages after the fix: `0 BANK!` works, `BANK@` = 0. Bucket numbers re-computed from `src/hash.asm`: all as in the table above. The root cause stands as drafted. Corrections to the rest of the draft:

- **`WORD` is not capped at 31 characters** (`src/strings.asm` `.word_copy` has no length limit; the count byte just wraps). It writes `HERE+1..HERE+len`. Every input source bounds a token to 128 bytes (TIB, `include_line_pool` lines are `TIB_SIZE`), so the 168 B reserve still covers it and is not raised. Only an `EVALUATE`d token longer than 167 chars at a bank's ceiling could still write past `$C000`; the review follow-up caps `WORD` at 128 chars (`-18`), see Completion Notes. Other transient users are fixed RAM: interpret-mode `S"` (`s_quote_buf`), `sw_name_buf`, `pic_buf`, `num_buf`.
- **`banking_tests.fth` probes 6 and 8 did not need changing.** Probe 4's `BANKS-CLEAR` runs first, so both append `$22` to an empty list. The probe that did append to the boot list was `banking_tests_dot_banks.fth` probe 7 (`$22 +BANK $23 +BANK` onto the 12-entry boot list); it now starts with `BANKS-CLEAR` and uses `$35` instead of `$23`.
- **The `+BANK` cap probe needed distinct pages** (not in the draft list): `_do-29-+bank` was `29 0 DO $22 +BANK LOOP`; it is now `$22`, then `$24..$3F`. The 30th `+BANK` still hits `cap?` first (cap check precedes the dup check).
- **No `disk/a/` fixture changed.** `P193BKN`, `P193BNK2`, `P193IRON`, `STRADH`, `STRADP`, `STRADG` and `tests/straddle_repro.fth.in` already used distinct pages and no `$C000 HERE -` brink.
- **Abort tails were 14 B each, not 13** (`LD HL` 3 + `LD B` 2 + `CALL` 3 + `LD BC` 3 + `JP` 3). New: `.abort_dup` 7 + `.abort_probe` 7 + `.abort_cap` 14 = 28, same as before, so that row is 0, not +1. Total +11 B.
- **23-6 case H passes on the pre-edit binary** because the re-based case G parks bank 6 at `$BF56`, below where the old spill happened. It is kept as a regression witness. The pre-edit failure shows in `tests/bank_lookup_tests.fth`, where bank 6 first tries the old brink `$BFFE` (`-8` now; accepted before, and the next token parsed there overwrote B0).
- **`.BANKS` assertions** (`test-repl-banking-isolated-dot-banks`): banked rows match page `3[5-9A-F]` and FREE 16216; the totals invariant moved from `R0F + 180224` (11 × 16384) to `R0F + 178376` (11 × 16216); probe Y's row-1 page is `35`; M1 checks `16216`, not `3F58`.

### Experiments (scripts were in the draft session's scratchpad; recreate)

Run each as `{ sed 's/$/\r/' X.fth; printf 'BYE\r\n'; } | timeout 15 iz-cpm-banking --disk-a disk/a --disk-b disk/b build/antforth.com`.

| Id | Setup | Draft result (31,348 B) |
|---|---|---|
| r1 | journal repro 1 (`$22` ×4, `_by` in bank 2, `3 BANK!`, `0 BANK!`) | `BANK! ?` `-13` |
| r2 | journal repro 2 (`_qk` in bank 1, `2 BANK!`, `CR`) | `CR ?` `-13` |
| r3 | journal repro 3 (`$22` ×7, `B0` at `$BFFD`, bank 6 to `$BFFE`, `1 2 + . CR`) | `3` then `CR ?` `-13` (hung on 31,077 B) |
| dr1–dr3 | r1–r3 with `BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK $3A +BANK` | all pass |
| v1 | r1 plus `100 ALLOT` in bank 3 before `0 BANK!` | `-13` (the parse that clobbers happens before the ALLOT) |
| v2 | r1 printing `HERE`: bank 2 after `_by` = 32786, bank 3 = 32768 | `-13` |
| v3 | r1 with `20 ALLOT` before `: _by` in bank 2 | works |
| s1 | dr3 plus `WORDS-ARE-LONG-TOKENS-HERE` in bank 6, then `0 BANK! B0 .` | `B0 ?` `-13` (spill defect) |

### `+BANK` dedup

Shared scan, placed next to `cl_probe_and_add` (`src/banking.asm:506`, resident; `cl_process_page` in `src/antforth.asm` is the boot-time caller):

```
; page_in_active_list: C = page -> CY set if C is in active_pages[0..bank_count-1].
;   Preserves C, DE, IX, IY. Clobbers A, B, HL.
page_in_active_list:
        LD      A, (IY+UserArea.bank_count)     ; 3
        OR      A                               ; 1  CY clear
        RET     Z                               ; 1  empty list -> not present
        LD      B, A                            ; 1
        LD      HL, ACTIVE_PAGES_BASE           ; 3
.pial_scan:
        LD      A, (HL)                         ; 1
        CP      C                               ; 1
        SCF                                     ; 1  CY set; Z untouched
        RET     Z                               ; 1  found
        INC     HL                              ; 1
        DJNZ    .pial_scan                      ; 2
        OR      A                               ; 1  CY clear (A is the last byte read; OR A only clears CY)
        RET                                     ; 1
```

In `+BANK`, TOS is in BC, so the page is already in C. B is TOS-high, which is dead because `POP BC` reloads TOS on the success path. DE = IP is untouched. Order: underflow check → cap check → dup check → probe. The cap check stays first, as today.

Abort tails: today `.abort_probe` and `.abort_cap` each do `LD HL,str / LD B,len / CALL bdos_print_str / LD BC,THROW_ABORT_QUOTE / JP w_THROW_cf.kernel_entry` (13 B each). Give the shared part a label (e.g. `.abort_msg` at `.abort_cap`'s `CALL`), and make `.abort_probe` and the new `.abort_dup` `LD HL,str / LD B,len / JR .abort_msg` (7 B each). `str_dup_q` / `str_dup_q_len` already exist (`src/antforth.asm:718-719`).

### Byte budget (itemised, est. ≈ +12 B)

| Item | Bytes |
|---|---|
| EQUs `PAD_SIZE`, `BANKED_TRANSIENT_RESERVE`, `BANKED_CEILING`; `/PAD` row → `PAD_SIZE` | 0 |
| `check_banked_headroom`: `LD HL, BANKED_CEILING` (operand change) | 0 |
| `.BANKS` FREE: `LD BC, BANKED_CEILING` (operand change) | 0 |
| `page_in_active_list` (3+1+1+1+3 + 1+1+1+1+1+2 + 1+1) | +18 |
| `cl_process_page`: remove inline scan (`LD A,(IY+d)` 3, `OR A` 1, `JR Z` 2, `LD B,A` 1, `LD HL,nn` 3, `LD A,(HL)` 1, `CP C` 1, `JR Z` 2, `INC HL` 1, `DJNZ` 2 = 17); add `CALL` 3 + `JR C` 2 | −12 |
| `+BANK` call site: `CALL` 3 + `JR C` 2 | +5 |
| Abort tails: `.abort_dup` 7, `.abort_probe` 13 → 7, `.abort_cap` 13 unchanged | +1 |
| **Total** | **≈ +12** |

If `cl_process_page` jumps to `.nodup` from elsewhere, or a `JR` falls out of range, recount. Epic 27 running total before this story: 76 + 179 + 8 + 60 + 271 = 594 B (27.6's 259 B plus 12 B from its review fix). That is already 94 B over the 500 B envelope, which the project lead accepted on 2026-10-11.

**TCB room:** `test-repl-multitasker-bank` had 14 B to spare after 27.6 (dev journal, 2026-10-11 OPEN entry). +12 B fits with 2 B left; anything over 14 B breaks it (second `TASK` → `-8`). See Task 8.2.

**Actual (dev pass): +11 B, 31,348 → 31,359.** `page_in_active_list` +18, `cl_process_page` −12, `+BANK` call site +5, abort tails 0 (see corrections), EQUs/operands 0. Epic 27 running total: 594 + 11 = 605 B. `test-repl-multitasker-bank` still passes (3 B of TCB room left).

### Probe conversions

- **Pages.** The boot list is `22 35-3F` (`src/antforth.asm:361-366`): bank 0 = `$22`, then 11 RAM pages. Keep `$22` as the first page after `BANKS-CLEAR` (bank 0 = portal) and use `$35 $36 $37 …` for the rest. Lines have at most 7 `+BANK`s, so `$35`–`$3A` are enough. `$35 +BANK` is the same length as `$22 +BANK`, so no line grows past 128 chars. Don't use `$20`–`$23` for N > 0: they are the CP/M TPA/slot pages (`$23` maps `$C000-$FFFF`). `banking_tests.fth` probe D's `$22 +BANK $23 +BANK` only probes and clears, so leave it.
- **Where `$22 +BANK` appears** (draft grep, 112 occurrences in `tests/*.fth`): `tests/banking_tests.fth`, `banking_tests_19_5_1.fth`, `banking_tests_23_6.fth`, `banking_tests_23_7.fth`, `banking_tests_23_9.fth`, `banking_tests_dot_banks.fth`, `again_tests.fth`, `qdo_tests.fth`, `straddle_repro.fth.in`; `disk/a/P193BKN.FTH`, `P193BNK2.FTH`, `P193IRON.FTH`, `STRADH.FTH`, `STRADP.FTH`, `STRADG.FTH`. Re-grep: `grep -rn '\$22 +BANK' tests/ disk/a/`.
- **`banking_tests.fth` probes 6 and 8** (`:165-195`) append `$22 +BANK` to the boot-populated list, which already holds `$22` → `dup?`. Start each with `BANKS-CLEAR` (probe 8 already ends with one), or switch to asserting the refusal. Probe A (`$22 +BANK BANKS 1 =`) runs after probe 8's `BANKS-CLEAR`, so it stays valid; check the order. Probe C's `$22 -BANK` absent case is unchanged.
- **Ceiling re-base** (draft counts of `$C000 HERE -`): `again_tests.fth` 3, `banking_tests_23_6.fth` 8, `banking_tests_23_7.fth` 4, `banking_tests_23_9.fth` 17, `qdo_tests.fth` 3. Replace `$C000` with `$BF58` in each brink expression, then check every comment that states a byte address (23-6 case E's "$BFF4 … ends at $BFFF" etc.) and every Makefile assertion on a printed `HERE` (`^49152` → `^48984`).
- **23-6 case F/G.** F stays bank 0 at `$C000 HERE - 3 - ALLOT` (bank 0 has no ceiling, so it still straddles `$C000`), renamed `B0`. G: `6 BANK! $BF58 HERE - 2 - ALLOT` then `$7000 ALLOT` still wraps (`$BF56 + $7000` = `$12F56` → `$2F56`) and must raise `-8`. Add an `H`-style witness after G: `0 BANK! ." B0=" B0 . CR` → `B0=42`. That is AC4 in the existing regression.
- **TCB order.** Don't touch the multitasker probes unless Task 8.2 says so.

### Untimed recipe lines (draft scan)

`awk '/^[a-zA-Z0-9_-]+:/{t=$1} /\$\(IZCPM[_A-Z]*\) \$\(IZCPM_DISKS\)/ && !/timeout/{print NR": "t}' Makefile` lists the recipe lines with no timeout. The bank-driving ones are in `test-repl-banking` (37 lines, Makefile:782-1244), `test-repl-banking-isolated` and every `-isolated-*` target (Makefile:1281-1816), `test-repl-banking-23-6` (:219), `-23-7` (:529), `-23-9` (:574) and `test-repl-cr-21-3` (:1867). The many plain `test-repl:` inline lines don't use `BANK` (draft grep found none) and are out of scope. Pattern (from `test-repl-qdo`):

```make
@OUTPUT=$$({ sed 's/$$/\r/' $(P); printf 'BYE\r\n'; } | timeout $(PROBE_TIMEOUT) $(IZCPM_BANKING) $(IZCPM_DISKS) $(TARGET) 2>/dev/null); rc=$$?; \
if [ $$rc -eq 124 ]; then echo "FAIL: <label> — timed out after $(PROBE_TIMEOUT)s (bank-lookup hang?)"; exit 1; fi; \
```

The 23-6/23-7/23-9 recipes end their pipeline with `| tr -d '\r' || true`. Moving `tr` after the rc capture (or using `$${PIPESTATUS}`, but recipes run under `sh`) needs care. The simplest is to capture raw output and rc first, then `OUTPUT=$$(printf '%s' "$$OUTPUT" | tr -d '\r')`.

### Probe file (`tests/bank_lookup_tests.fth`) — sketch

```forth
\ bank_lookup_tests.fth — cross-bank lookup, +BANK dup refusal, banked ceiling.
DECIMAL
\ --- AC2: duplicate page refused, list unchanged; accepted after BANKS-CLEAR ---
0 BANK!  BANKS-CLEAR $22 +BANK $35 +BANK
: _dup2 $35 +BANK ;  ." blA=" ' _dup2 CATCH . BANKS . CR
\ expect: dup? then blA=-2 2
\ --- AC5: the three journal repros on distinct pages ---
BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK $3A +BANK
2 BANK!  : _by 1 ;
3 BANK!
0 BANK!  ." blB=" BANK@ . CR
1 BANK!  : _qk 1 ;
2 BANK!  ." blC=" 1 2 + . CR
0 BANK!
\ --- AC3: ceiling (one-past-end $BF58 accepted; one over -> -8; bank 0 no-op) ---
4 BANK!  $BF58 HERE - ALLOT  ." blD=" HERE U. CR
5 BANK!  $BF58 HERE - 1- ALLOT 2 ALLOT
\ --- AC4: B0 straddling $C000 in bank 0 survives bank 6 at the brink ---
0 BANK!  $C000 HERE - 3 - ALLOT  42 VALUE B0
6 BANK!  $BF58 HERE - ALLOT  ABCDEFGHIJKLMNOPQRSTUVWXYZ01234
PAD 84 66 FILL  ." blE=" CR
0 BANK!  ." blF=" B0 . CR
." bl-alive=" 6 7 * . CR
```

Expected verdicts: `blA=-2 2`, `blB=0`, `blC=3`, `blD=48984`, one `^error -8: dictionary overflow` (the `2 ALLOT` in bank 5), one `^ABCDEF… ?` / `-13` for the long token (expected; it is only there to be parsed), `blF=42`, `bl-alive=42`. `--fail-line '^FAIL: bl-|^error -274|^BANK! ?|^CR ?|^B0 ?'`. Notes:

- Line 3's `$35 +BANK` at interpret level would abort the line, so the refusal is tested through `CATCH` in a colon word. `CATCH` restores the depth, which leaves the page under the `-2`; add a `DROP` if `.` order shows it. Use `BANKS` to show the list is unchanged.
- `$BF58 HERE - 1- ALLOT` then `2 ALLOT` crosses by one. Use whatever shape gives exactly one `-8` and no other side effect.
- A bank-0 colon body must stay below `$8000` (`feedback_banking_probe_straddle_halt`); this sketch defines bank-0 words only at interpret level. Check `HERE` before any bank-0 `:`.
- After the AC4 block, bank 0's `HERE` is past `$C000`. Keep that block last apart from the witness, or put it in its own target if it disturbs later cases.
- If a number looks wrong, check BASE first (`project_hex_base_leak_literal_truncation`).

### S9 recipe (post in the review close message)

Copy `build/antforth.com` (31,395 B). No `disk/a/` fixture changed. Fresh boot, then:

1. `.BANKS` → banks 1..N show FREE 16216 (not 16384).
2. Original hang repro, now refused: `BANKS-CLEAR $22 +BANK $22 +BANK` → `dup?` and `error -2`; `BANKS .` → `1`.
3. Original `B0`/`CR` repro on distinct pages: `0 BANK! BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK $3A +BANK`, then `0 BANK!  $C000 HERE - 3 - ALLOT`, `42 VALUE B0`, `6 BANK!  $C000 HERE - 2 - ALLOT` → now `error -8` (ceiling), then `$BF58 HERE - ALLOT`, `HERE U.` → `48984`, `ABCDEFGHIJKLMNOPQRSTUVWXYZ01234` → `?` / `error -13` (expected), `1 2 + . CR` → `3`, newline, prompt (no hang), `0 BANK! B0 .` → `42`.
4. `_by`/`BANK!`: after `BANKS-CLEAR` + distinct pages as in 3 (fresh boot or a different session): `2 BANK! : _by 1 ;  3 BANK!  0 BANK!  BANK@ .` → `0`.
5. `_qk`/`CR`: `1 BANK! : _qk 1 ;  2 BANK!  CR` → newline, no error; `0 BANK!`.
6. `INCLUDE P193IRON.FTH` → its usual sentinel (fixture unchanged; confirms the boot list and `+BANK` still accept distinct pages).
7. `WORD` cap, after step 3's setup (bank 6 at `$BF58`, `B0` straddling `$C000`): `0 BANK!  CREATE _LT 220 ALLOT  _LT 220 65 FILL`, `6 BANK!  _LT 220 ' EVALUATE CATCH . 2DROP` → `-18`, `0 BANK! B0 .` → `42`.

### Testing standards

- Through the Forth threading model, REPL-piped (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Verdict greps are column-0 anchored via `tests/assert_verdicts.sh`; the REPL echoes piped source.
- `IZCPM` is `iz-cpm-banking` (Makefile:19), so banks work in a plain `test-repl` target.
- Lines ≤ 128 chars (`feedback_tib_size_inline_comments`).
- Pages `$35`–`$3F` are RAM on iz-cpm-banking (verified at draft: `.BANKS` lists them with FREE 16384).
- Kernel growth moves bank-0 `HERE`. If a banking probe halts after the edit, read `feedback_banking_probe_straddle_halt` before blaming the change: a bank-0 colon body may now cross `$8000`.
- The draft did not find `_bmad/core/tasks/validate-workflow.xml`, so the create-story checklist was applied by hand at draft time.

### Previous story (27.6) — what carries over

- Byte estimates have matched closely (27.6: 259 vs 263; the per-component itemisation works). Recount from the built code.
- 27.6 broke four multitasker targets that are not `test-repl` prerequisites, and nobody noticed until the regression sweep. Run them all here (AC10).
- `make check-doc-sync` failed on line-number citations after 27.6's insertions; budget time for re-pointing (Task 7.3).
- 27.4/27.3 renamed probe words to dodge this bug (`F0`, `_bq`, `_wx/_wy/_wz`). Only `F0` → `B0` and `_bq` → `_qk` are required by the AC; leave `_wx/_wy/_wz`.

### Git intelligence

Recent: `bfb9a48 feat: underflow checks on one-operand words (Story 27.6)`, `09b3c00 feat: add ?DO (Story 27.4)`, `3b50b0c feat: add AGAIN (Story 27.3)`. Suggested message: `fix: refuse duplicate +BANK pages and keep banked HERE clear of $C000 (Story 27.7)`. No Claude co-author trailer (`feedback_no_claude_coauthor`).

### Project Structure Notes

- Files touched: `src/banking.asm`, `src/antforth.asm` (`cl_process_page`), `src/constants.asm` (EQUs), `src/system.asm` (`/PAD` row), `tests/bank_lookup_tests.fth` (new), the probe files and `disk/a/` fixtures listed above, `Makefile`, `docs/dev_journal.md`, `docs/throw-codes.md`, banking docs, this story file, `sprint-status.yaml`.
- Source comments say what and why, not story/date provenance (`feedback_source_comment_discipline`).
- No architecture doc covers Phase 7; no external libraries; no web research needed.

### References

- Epic: `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — FR-P7-15, NFR-P7-1/2/6/7, Story 27.7.
- `docs/dev_journal.md` — "2026-10-08 (OPEN, Story 27.7)" and "2026-10-11 (OPEN) — fixed RAM below `$8000` now holds only two TCBs".
- `src/dictionary.asm:96-300` (`search_wid_for_name`, `sw_map_bank`, `sw_restore_slot2`); `src/compiler.asm:149-440` (`build_header`, fat link + bucket head); `src/hash.asm`.
- `src/banking.asm:149-191` (`check_banked_headroom`, `dict_overflow_throw`), `:432-475` (`+BANK` and its abort tails), `:506` (`cl_probe_and_add`), `:917` (`.BANKS` FREE), `BANKS-CLEAR`/`-BANK` comments.
- `src/antforth.asm:206-216` (bank-N `HERE` = `$8000`), `:361-366` (boot list), `:551-590` (`cl_process_page`), `:718-719` (`str_dup_q`).
- `src/memory.asm:168-176` (PAD/WORD layout); `src/constants.asm:138` (`PAD_OFFSET`); `src/system.asm:565-569` (`/HOLD`, `/PAD`).
- `docs/adr-19-5-cross-bank-dispatch.md:81` (boot map `[20,21,22,23]`, `$22` = bank 0); `docs/antforth-banking-redesign.md:85`.
- Makefile:19, :56, :135 (`PROBE_TIMEOUT`), :694-704 (`test-repl-qdo`), :751-763 (`lint-banking-probes`), :1996 (`test-repl`).

## Dev Agent Record

### Agent Model Used

claude-opus-5-5 (Claude Code, dev-story workflow)

### Debug Log References

- Pre-edit binary kept at the session scratchpad as `antforth-pre.com`; experiments r1–s1 and the new probe were run against it (see "Dev-pass verification and corrections").
- `tests/bank_lookup_tests.fth` on the pre-edit binary: `blA=0 3` (dup accepted), `blB=4`, no `-8` for bank 5 (`blG=48985`), `blK=B0 ?` / `-13` (spill). Breaking `blK=42` → `blK=43` in the Makefile gave `FAIL … expected 'blK=43 $'` / `Error 1`; restored.
- First full banking sweep after the edits: `test-repl-banking-isolated-dot-banks` failed (probe 7 witness missing: `+BANK` refused `$22` already in the boot list). Fixed with `BANKS-CLEAR` at the head of probe 7.

### Completion Notes List

- **Dedup:** new resident `page_in_active_list` (`src/banking.asm`), called by `+BANK` after the cap check and before the probe (`dup?`, `-2`, list unchanged) and by the boot CL parser `cl_process_page` (inline scan removed; `dup? NN` output unchanged, `cl-probe-dup` still passes). `+BANK`'s three abort tails share one print+THROW tail.
- **Ceiling:** `PAD_SIZE`, `BANKED_TRANSIENT_RESERVE` (= `PAD_OFFSET` + `PAD_SIZE` = 168) and `BANKED_CEILING` (= `$BF58`) EQUs in `src/constants.asm`; `/PAD` reports `PAD_SIZE`. `check_banked_headroom` and the `.BANKS` FREE column use `BANKED_CEILING`; bank 0 unchanged. Guard-site comments that said "$C000" now say `BANKED_CEILING`. No other `0x4000`/`$C000` use in `src/` meant the banked limit (the rest are MMU/slot geometry or fixed-memory tests).
- **Probes:** 23-6/23-7/23-9/AGAIN/?DO brinks re-based to `$BF58` (bank-0 cases 23-7 C and 23-9 H keep `$C000`); every repeated `$22 +BANK` moved to `$35…`; 23-6 case F back to `B0` plus a new case H witness `---H-B0=42`; ?DO's banked word back to `_qk`; the "names avoid the bug" comments removed (23-6, qdo, again). Makefile assertions `^49152` → `^48984`, `.BANKS` figures as listed in the corrections.
- **New probe** `tests/bank_lookup_tests.fth` + `test-repl-bank-lookup` (15 verdicts), prerequisite of `test-repl` after `test-repl-underflow`. Seen to fail on the pre-edit binary.
- **Timeouts:** 56 recipe lines across `test-repl-banking`, every `test-repl-banking-isolated*`, `-23-6`, `-23-7`, `-23-9` and `test-repl-cr-21-3` now pipe through `timeout $(PROBE_TIMEOUT)` with an rc 124 `FAIL:` + `exit 1`; the `tr -d '\r'` step moved after the rc capture. `19-5-1` and `22-1` already had `timeout` but no rc check; they have one now. `test-straddle-regression` goes through `straddle_repro_sweep.sh`, which already uses `timeout 15` by design; unchanged.
- **Regression (post-edit):** `make test` PASS; `make test-repl` 1144 PASS / 0 FAIL / 2 SKIP (baseline 1129 + 15 new, none removed); `test-repl-banking` 57/0, `-isolated` 6/0, every `-isolated-*` target 0 FAIL (dot-banks 7/0), `-23-6` 8/0 (+H), `-23-7` 4/0, `-23-9` 9/0, `cr-21-3` 4/0, `test-straddle-regression` 3/0, `lint-banking-probes`, `test-file-sanity`, `check-doc-sync` green; all 11 multitasker/semaphore/mutex/mailbox targets + `test-repl-timer` 0 FAIL.
- **Docs:** dev-journal entry retitled RESOLVED with cause + fix; `throw-codes.md` `-8` row, `antforth-banking-design.md`, `phase4-memory-map.md` name the `$BF58` ceiling; `ans-forth-core-compliance.md` `+BANK` (`dup?`) and `.BANKS` rows updated. Citation sweep: the compliance table's `banking.asm:N` citations were already stale at HEAD and now point at each word's `w_` label; two `banking.asm:170..193` citations in `tests/banking_tests.fth` now name `bank_triple_save`/`bank_triple_load`. ADR 19.5 citations left as dated history.
- **Budget:** +11 B vs est. ≈ +12 B (itemised in "Byte budget"); Epic 27 total 605 B.
- **Hardware (AC13):** S9 recipe run on real MicroBeast 2026-10-12 (31,359 B, fresh boot), steps 1–5 PASS: `.BANKS` banks 1–11 FREE 16216; `$22 +BANK $22 +BANK` → `dup?error -2`, `BANKS .` → 1; bank 6 `$C000 HERE - 2 - ALLOT` → `-8`, `$BF58 HERE - ALLOT` → `HERE U.` 48984; 31-char token → `-13` (expected); `1 2 + . CR` → `3`, no hang; `0 BANK! B0 .` → 42; `_by`/`BANK!` → `BANK@ .` 0; `_qk`/`CR` → newline, no error. Step 6 (`INCLUDE P193IRON.FTH`, unchanged fixture) not in the transcript.
- **Review follow-up (2026-10-12): `WORD` length cap.** Code review reproduced a 220-char `EVALUATE` token at bank `$BF58` writing `$C000`/`$C010`. `WORD` now throws `-18` (parsed string overflow) once a token passes `WORD_MAX_LEN` (= `TIB_SIZE` = 128, `src/constants.asm`, with an `ASSERT` that the counted string plus the one byte stored before the check fits inside `BANKED_TRANSIENT_RESERVE`). The 129th char is written to `HERE+129` before the check, inside the reserve. New `THROW_PARSED_OVERFLOW` and its `throw_desc_table` entry. Probe cases L/M/N in `bank_lookup_tests.fth`: a 128-char token → `-13`, a 220-char token → `-18`, `B0` → 42; with the check removed blM and blN fail (B0 overwritten). +36 B (31,359 → 31,395); Epic 27 total 641 B. `make test` PASS; `make test-repl` 1147 PASS / 0 FAIL; `test-repl-banking`, `-isolated`, `-isolated-dot-banks`, `-23-6`, `-23-7`, `-23-9`, `test-straddle-regression`, `lint-banking-probes`, `check-doc-sync` green. The AC13 hardware run above was on 31,359 B; the cap is not hardware-run yet (S9 step 7).
- **Seen, not fixed (outside scope):** `tests/banking_tests.fth:374` is a 229-char `." INFO: …"` line, over the 128-char TIB limit at HEAD already.

### File List

- `src/constants.asm` — `PAD_SIZE`, `BANKED_TRANSIENT_RESERVE`, `BANKED_CEILING`, `WORD_MAX_LEN`, `THROW_PARSED_OVERFLOW`
- `src/banking.asm` — `check_banked_headroom` ceiling + comment, `+BANK` dup check + shared abort tail + comments, `page_in_active_list`, `.BANKS` FREE ceiling + comments
- `src/antforth.asm` — `cl_process_page` uses `page_in_active_list`
- `src/system.asm` — `/PAD` → `PAD_SIZE`; guard comments
- `src/compiler.asm`, `src/memory.asm`, `src/macros.asm` — guard comments name `BANKED_CEILING`
- `src/strings.asm` — guard comments name `BANKED_CEILING`; `WORD` length cap (`-18`)
- `src/exception.asm` — `-18` description entry
- `tests/bank_lookup_tests.fth` — new
- `tests/banking_tests.fth` — cap helper uses distinct pages; two citations
- `tests/banking_tests_dot_banks.fth` — distinct pages; probe 7 `BANKS-CLEAR`; comments
- `tests/banking_tests_23_6.fth`, `tests/banking_tests_23_7.fth`, `tests/banking_tests_23_9.fth`, `tests/again_tests.fth`, `tests/qdo_tests.fth` — distinct pages, `$BF58` brinks, names restored
- `Makefile` — `test-repl-bank-lookup`, `.PHONY`, `test-repl` prereq, timeouts, re-based assertions, 23-6 case H
- `docs/dev_journal.md`, `docs/throw-codes.md`, `docs/antforth-banking-design.md`, `docs/phase4-memory-map.md`, `docs/ans-forth-core-compliance.md`
- `_bmad-output/implementation-artifacts/27-7-cross-bank-lookup-hides-or-hangs-on-kernel-words.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-10-12 — Dev pass: `+BANK` refuses duplicate pages (shared scan with the boot parser); banked ceiling `$BF58` keeps WORD/PAD below `$C000`; probes moved to distinct pages and the new ceiling; new `test-repl-bank-lookup`; timeouts on every bank-driving recipe line; docs. +11 B (31,348 → 31,359). Status → review.
- 2026-10-12 — Review follow-up: `WORD` throws `-18` past 128 chars so an `EVALUATE` token can't write past `$C000`; probe cases L/M/N; S9 step 7. +36 B (31,359 → 31,395).
- 2026-10-12 — Code review closed; status → done.
