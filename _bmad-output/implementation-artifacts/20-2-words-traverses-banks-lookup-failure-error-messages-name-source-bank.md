# Story 20.2: Bank-aware `WORDS` verification + FR-P4-30 (source-bank error attribution) retired

Status: review

<!-- Scope re-spec (2026-06-10): the planning artifact
     (epics-phase4-epics-16-22.md §"Story 20.2") was written against the
     SUPERSEDED "per-wordlist bank field" design. Story 20.1's dev pass replaced
     that with a single global wordlist + inline 24-bit fat dictionary pointers,
     and 20.1's CR pass (commit d078548 "bank-aware WORDS + fat-bank-byte error
     recovery") ALREADY landed the bank-aware WORDS traversal. The original
     FR-P4-30 "error messages name source bank" attribution lost its referent
     (no per-bank wordlists) and most of its purpose (bank-aware FIND already
     resolves a word in any bank). Project-lead decision 2026-06-10: retire
     FR-P4-30 with a recorded rationale; scope 20.2 to *verifying* the
     already-shipped bank-aware WORDS and reconciling the spec. See
     "Why this is a verification + retirement story". -->

## Story

As Marc (OG user) listing words after defining them across several banks,
I want `WORDS` to produce one flat, coherent listing that includes words whose headers physically live in other banks — with the bank switches invisible — and I want a confirmation that a typo at the REPL still gives me the plain `<word> ?` error,
so that I trust the dictionary view is complete regardless of which bank I'm parked in, and the error surface is unchanged by banking.

## Why this is a verification + retirement story (read this first)

The planning artifact (`epics-phase4-epics-16-22.md` §"Story 20.2", lines 946–966) specified two FRs against the **per-wordlist `bank` field** design that Story 20.1 was *meant* to ship. That design was superseded mid-flight (project-lead-steered) by a **single global wordlist + inline 24-bit fat dictionary pointers** (`[addr:2][bank:1]`). Two consequences reshape this story:

1. **FR-P4-29 (`WORDS` traverses banks) already shipped — in Story 20.1's CR pass.** Commit `d078548` ("Story 20.1 CR fixes: bank-aware WORDS + fat-bank-byte error recovery") added `words_deref` and the page-in/restore bracket to `w_WORDS_cf`. The committed `WORDS` already derefs each fat bucket head / hash_link, pages a window-resident entry's bank into slot 2, prints the name, and restores the caller's slot-2 page on exit. 20.1's own "Known limitations" note ("WORDS does not page-in to display bank-N names yet — Story 20.2") is **stale relative to its own CR fixes**. There is therefore **no new kernel `WORDS` code** to write — 20.2 makes the shipped behaviour *observable, probed, and hardware-verified* (which the CR add-on did without dedicated WORDS probes).

2. **FR-P4-30 (error messages name source bank) is retired as obsolete.** The planned AC4 said: "when a FIND failure occurs and the failed lookup walked a *non-default-bank wordlist* (`bank != BANK@` and `bank != -1`), include the bank context." Under the fat-pointer mechanism there are **no per-bank wordlists** to attribute — there is one global wordlist whose entries are scattered across banks — and bank-aware FIND now resolves a word *regardless of the current bank*, so the disambiguation FR-P4-30 was meant to provide ("did I forget to switch banks, or never define it?") has evaporated: a FIND miss now means the word is genuinely absent from every wordlist in the search order, in every bank. The `<word> ?` error stays exactly as Phase-3 shipped. (Project-lead decision, 2026-06-10.)

Net scope: **no kernel behaviour change** (expected binary delta ~0 B). The deliverables are (a) dedicated emulator + hardware probes proving the bank-aware `WORDS`; (b) a recorded FR-P4-30 retirement rationale; (c) reconciliation of the stale 20.1/doc notes.

## Acceptance Criteria

> Re-spec of `epics-phase4-epics-16-22.md` §"Story 20.2" against the implemented mechanism. FRs: FR-P4-29 (`WORDS` traverses banks — verified), FR-P4-30 (source-bank error attribution — **retired**). NFRs: NFR-P4-6 (batch/traversal envelope), NFR-P4-12 (ANS compliance unaffected), NFR-P4-20 (CCD-3 source citation).

**Given** Story 20.1 has shipped (single global wordlist + inline 24-bit fat dictionary pointers; bank-aware `FIND`; bank-aware `WORDS` landed in the 20.1 CR pass `d078548`),
**When** Story 20.2 is dev-passed,

**Then AC1** (FR-P4-29 — `WORDS` bank traversal, verify-not-build) — confirm by probe that `w_WORDS_cf` (`src/dictionary.asm:361-449`) lists words whose headers live in a non-zero bank: a word defined in bank 5 appears in `WORDS` output typed from bank 0. The mechanism under verification is the per-entry fat-pointer deref + page-in via `words_deref` (`src/dictionary.asm:312-350`) and `sw_restore_slot2`. No kernel code change is expected; if the probes expose a defect, fix it (bug-fix bytes only) and record it in Dev Notes.

**And AC2** (FR-P4-29 — bank switches invisible) — `WORDS` output is a single flat stream of space-separated names with no per-bank annotation, banner, or reordering (per-bank annotation is explicitly out of MVP scope, a future option). The caller's current bank and slot-2 page are restored after the listing completes: `BANK@` and the slot-2 mapping (`MBB-GET-2`) read identically before and after a `WORDS` call that paged in foreign banks.

**And AC3** (FR-P4-30 — **retired**) — the undefined-word error path is unchanged from Phase-3: the interpret-mode formatter (`src/outer_interpreter.asm:303-316`) and compile-mode formatter (`src/compiler.asm:614-628` → `bdos_print_q_crlf`, `src/io.asm`) still emit `<word> ?` + CR/LF + `-13 THROW` with **no** bank suffix. A negative-control probe (AC6-d) witnesses that an undefined word produces the plain `<word> ?` message. The retirement rationale (bank-aware FIND moots source-bank attribution; no per-bank wordlists exist under the fat-pointer mechanism) is recorded in Dev Notes; the planning artifact's FR-P4-30 AC is annotated as retired (not implemented).

**And AC4** (stale-note reconciliation) — the stale "WORDS does not page-in yet — Story 20.2" line in the Story 20.1 file's "Known limitations" is corrected to "resolved in 20.1 CR pass `d078548`; verified by Story 20.2 probes"; any kernel source comment that defers WORDS bank-awareness to "Story 20.2" is reconciled to reflect that it shipped in 20.1. (Comment-only edits — no assembled bytes; per `[[feedback_source_comment_discipline]]` keep it to what+why, no provenance bloat.)

**And AC5** (NFR-P4-20 / CCD-3 source citation) — the WORDS verification probes and the FR-P4-30 retirement note cite `docs/antforth-banking-redesign.md §5.5` (bank-aware FIND / the INTERIM GOTCHA that the fat-pointer mechanism closed) and `§5.4` (per-bank state). Dev Notes flag that §5.5's *resolution* text still describes the superseded per-wordlist-bank-field design — broader doc-sync reconciliation is deferred to Story 20.3 close-out / `make check-doc-sync` (B.5), not owned here.

**And AC6** (REPL probes — new `tests/banking_tests_20_2.fth`, isolated fixture, sentinel-delimited `result=-1` verdicts mirroring `tests/banking_tests_20_1.fth`):
  - **(a)** WORDS-lists-bank-N: `5 BANK! : _w52a ; : _w52b ; 0 BANK!` then capture `WORDS` output; assert both `_w52a` and `_w52b` appear in the flat listing (a bank-5-resident name is printed from bank 0). Emit `result=-1` on success.
  - **(b)** WORDS-restores-bank: capture `BANK@` and `MBB-GET-2` before and after a `WORDS` call that paged in a foreign bank; assert both unchanged (caller's bank + slot-2 page restored on exit).
  - **(c)** mixed-chain: a bucket chain containing both fixed (kernel) and bank-N entries prints all names with none missing or garbled (proves per-entry page-in, not a one-shot switch). Practically: confirm a known kernel word *and* a bank-N user word both appear in one `WORDS` run.
  - **(d)** FR-P4-30-retired negative control: an undefined word (e.g. `?NOSUCH?`) at the REPL produces the standard `<word> ?` error with no bank suffix; the kernel recovers and the suite end-sentinel is reached. (Matches the existing `make test-repl` "XYZZY ?" assertion — banking adds no attribution.)

**And AC7** (probe surfaces + hardware smoke) — `tests/banking_tests_20_2.fth` passes under the banking-capable emulator (`make test-repl-banking-isolated-20-2`, new Makefile recipe + `.PHONY` mirroring the 20-1 target); one hardware-typed probe batch covering AC6 (a)–(d) runs on real MicroBeast per S9 / NFR-P4-11. CP/M copy at `disk/a/P202WRDS.FTH` (8.3 name, `0x1A`-terminated per `[[feedback_cpm_0x1a_eof_marker]]`).

**And AC8** (binary delta) — `wc -c build/antforth.com` is **expected to be unchanged at the re-captured pre-edit baseline** (no kernel code change; WORDS already shipped, comment/doc edits don't assemble). Any non-zero delta is bug-fix bytes only and must be ≤ ~80 B (the Epic-20 story budget) with a per-component itemisation in Dev Notes. Re-`wc -c` from the actual current artifact — do NOT inherit 20.1's reported 27516 B (stale; the 20.1 CR pass grew it — see Pre-edit baseline).

**And AC9** (gates) — `make test-repl` ≥ 974 PASS / 0 FAIL on iz-cpm (the undefined-word "XYZZY ?" assertion holds, proving FR-P4-30 retirement leaves the error surface intact); `make test-repl-banking` 61 PASS / 0 + the new `test-repl-banking-isolated-20-2` probes PASS; `make test-repl-banking-isolated-20-1` 6/6 and 19.2/19.3/19.4/19.5.1 = 6/15/2/2 unchanged; straddle 3/3.

**FRs covered:** FR-P4-29 (`WORDS` traverses banks — verified; shipped in 20.1 CR). FR-P4-30 (source-bank error attribution — **retired**, rationale recorded).
**NFRs:** NFR-P4-6, NFR-P4-12, NFR-P4-20.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
  - Do NOT inherit 20.1's reported number. 20.1's story body says 27516 B, but its CR pass (`d078548`, bank-aware WORDS) grew the artifact; the actual current build is ~27622 B (committed HEAD `7ee97fd`, clean tree). Re-`wc -c` from the artifact (B.3 / `[[feedback_kernel_ldir_estimate_overshoot]]`; cf. the 20.1 story-text drift this very story corrects).
- [x] Capture current `make test-repl` baseline pass count (20.1 reported 975 PASS / 0 FAIL; re-capture, expect ≥ 974).
- [x] Capture current `make test-repl-banking` count (expect 61 PASS / 0) and `make test-repl-banking-isolated-20-1` (expect 6/6).
- [x] Read `w_WORDS_cf` (`src/dictionary.asm:361-449`) and `words_deref` (`:312-350`) end-to-end and confirm the page-in/restore bracket before writing probes.

### Task 1 — Verify bank-aware WORDS by probe (AC1, AC2)

- [x] Author `tests/banking_tests_20_2.fth` probes (a)/(b)/(c) — see AC6. Use the sentinel-delimited `result=-1` pattern from `tests/banking_tests_20_1.fth` (per-probe `---probe-20.2-<id>-start---`/`-end---`, suite `---probe-20.2-suite-end---`, `BYE`).
- [x] For (b), reuse the `MBB-GET-2` CODE-word probe pattern from `tests/banking_tests.fth` to witness slot-2 restore; assert `BANK@` unchanged across the `WORDS` call.
- [x] Run under iz-cpm-banking; confirm all probes `result=-1`. If any defect surfaces, root-cause and fix in `src/dictionary.asm` (bug-fix only); record in Debug Log.

### Task 2 — Retire FR-P4-30 + negative control (AC3, AC6-d)

- [x] Confirm (by reading) the undefined-word formatter is unchanged: interpret path `src/outer_interpreter.asm:303-316`; compile path `src/compiler.asm:614-628` + `bdos_print_q_crlf` (`src/io.asm`). Make **no** code change.
- [x] Add probe (d): undefined word → standard `<word> ?`, no bank suffix, kernel recovers, suite end-sentinel reached.
- [x] Write the FR-P4-30 retirement rationale into Dev Notes (and annotate the planning artifact's FR-P4-30 AC as retired-not-implemented, mirroring how 20.1 annotated its re-spec).

### Task 3 — Stale-note + comment reconciliation (AC4)

- [x] Correct the Story 20.1 file's "Known limitations" WORDS line ("does not page-in yet — Story 20.2" → "resolved in 20.1 CR pass d078548; verified by 20.2 probes").
- [x] Grep `src/` for any comment deferring WORDS bank-awareness to "Story 20.2" / "not yet" and reconcile (comment-only; per `[[feedback_source_comment_discipline]]` — what+why, no provenance).

### Task 4 — Makefile target + CP/M hardware copy (AC7)

- [x] Add `test-repl-banking-isolated-20-2` recipe to `Makefile` mirroring `test-repl-banking-isolated-20-1` (lines ~839-857); add to `.PHONY`.
- [x] Create `disk/a/P202WRDS.FTH` — CP/M 8.3 name, `0x1A`-terminated, mirroring `disk/a/P201FIND.FTH`.

### Task 5 — Gates + binary delta (AC8, AC9)

- [x] Run the full gate set: `make test-repl` (≥974/0), `make test-repl-banking` (61/0), `test-repl-banking-isolated-20-2` (new), `-20-1` (6/6), 19.2/19.3/19.4/19.5.1 (6/15/2/2), straddle (3/3).
- [x] Re-`wc -c build/antforth.com`; assert delta vs pre-edit baseline (expected 0 B; any delta itemised, ≤ ~80 B).

### Task 6 — Hardware smoke (AC7)

- [x] **HW smoke PASS on real MicroBeast** (transcript `beastty-20260611-231019.bin`, AntForth v3.0.4, 12 banks). `INCLUDE P202WRDS.FTH`: (a) WORDS dump lists `_w52a` + `_w52b` (bank-5 names from bank 0); (b) `result=-1` (BANK@ + slot-2 restored); (c) one WORDS run lists `DUP` (fixed) + `_w52c` (bank-5); suite-end sentinel printed; (d) `?NOSUCH? ?` plain — **no bank suffix** — then `error -13: undefined word` (INCLUDE abort) and the prompt returned (kernel recovered). FR-P4-30 retirement confirmed on silicon.

## Dev Notes

### The mechanism under verification (what already shipped in 20.1)

`w_WORDS_cf` (`src/dictionary.asm:361-449`) walks all 64 fat bucket heads of the single global `forth_wordlist` (`WORDLIST_BUCKET_STRIDE = 3`). For each bucket head and each entry `hash_link` it calls `words_deref` (`:312-350`): read the 3-byte fat pointer `[addr:2][bank:1]`; if the address is window-resident (`$8000..$BFFF`) page `active_pages[bank]` into slot 2 via the blessed `mbb_set_slot2`/`mbb_get_slot2` (BIOS `MBB_*`, `src/banking.asm:78-101`), saving the caller's page on the *first* switch of the walk (`sw_switched`/`sw_saved_page` shared with FIND). count_flags is read at `entry+3` (past the 3-byte fat link); smudged entries (`F_SMUDGE`, bit 6) are skipped; the name is printed via `bdos_putchar`. On exit `sw_restore_slot2` (`:286-295`) puts the caller's slot-2 page back. Fixed addresses (`< $8000`, `>= $C000`) read directly — no MMU op. Because the bank travels *with each pointer*, a single chain mixing fixed and bank-N entries is fully walkable, and the listing is a flat stream with bank switches invisible — exactly AC1/AC2.

This story writes **no kernel WORDS code**. It proves the above by probe and hardware smoke, and corrects the stale "not yet" notes.

### FR-P4-30 retirement rationale (record verbatim in Completion Notes)

The planned source-bank error attribution assumed per-bank wordlists, each tagged with one `bank`, so a FIND miss could name "the bank-5 wordlist FOO you didn't switch to." The 20.1 re-spec deleted that model: there is one global wordlist whose entries are scattered across banks, and bank-aware FIND resolves a name in *any* bank that is reachable through the search order. A FIND miss therefore no longer carries a "wrong bank" hypothesis to attribute — the word is simply absent everywhere the search order reaches. Adding current-bank echo or traversed-bank lists was considered (project-lead question, 2026-06-10) and declined as low-value noise on the hot error path. The `<word> ?` surface stays Phase-3-identical; AC6-d is the standing witness.

### Project Structure Notes

- No new kernel surface. Touch points are test/doc only: `tests/banking_tests_20_2.fth` (new), `Makefile` (new isolated target + `.PHONY`), `disk/a/P202WRDS.FTH` (new HW copy), the Story 20.1 file (stale-note fix), possibly 1–2 source *comments*.
- `WORDS` lives in `src/dictionary.asm` (not `src/wordlists.asm` as the epics goal text loosely says); the deref helpers it reuses are local to `dictionary.asm`.
- Probe-author hazards: keep each REPL probe line ≤ TIB_SIZE 128 (`[[feedback_tib_size_inline_comments]]`); behavioural per-bank probes work only via the isolated-fixture discipline (`[[feedback_phase4_probe_bank_switch_limitation]]`) — the 20-1 isolated harness is the template.

### References

- [Source: `src/dictionary.asm:361-449`] — `w_WORDS_cf` bank-aware traversal (shipped 20.1 CR `d078548`).
- [Source: `src/dictionary.asm:312-350`] — `words_deref`; `:286-295` `sw_restore_slot2`; `:240-284` `sw_map_bank`; `:297-304` `sw_*` shared state.
- [Source: `src/outer_interpreter.asm:303-316`] — undefined-word formatter, interpret path (`<word> ?` + `-13 THROW`), unchanged.
- [Source: `src/compiler.asm:614-628`] + [`src/io.asm` `bdos_print_q_crlf`] — undefined-word formatter, compile path, unchanged.
- [Source: `src/banking.asm:78-101`] — `mbb_set_slot2`/`mbb_get_slot2`; `:29` `ACTIVE_PAGES_BASE`; `:820-843` `BANK-OF`; `:108-114` `BANK@`.
- [Source: `docs/antforth-banking-redesign.md §5.5`] — bank-aware FIND + INTERIM GOTCHA (closed by the fat-pointer mechanism; §5.5 *resolution* text is itself superseded — flag for 20.3 doc-sync). `§5.4` — per-bank state / portal-window guard.
- [Source: `tests/banking_tests_20_1.fth`] + [`Makefile:839-857`] — isolated-probe + sentinel pattern to mirror.
- Git: commit `d078548` (bank-aware WORDS shipped in 20.1 CR); HEAD `7ee97fd` (clean tree, ~27622 B).
- Memory: `[[project_story20_1_fat_pointers]]`, `[[project_banking_bios_pivot]]`, `[[feedback_post_hw_smoke_steps_at_review]]`, `[[feedback_cpm_0x1a_eof_marker]]`, `[[feedback_phase4_probe_bank_switch_limitation]]`, `[[feedback_source_comment_discipline]]`, `[[feedback_no_accept_disposition_for_bugs]]`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8)

### Debug Log References

- `make test-repl-banking-isolated-20-2` — all 5 probes (a/b/c/d + suite-end) PASS on first run; no kernel defect surfaced, so no `src/dictionary.asm` change was needed (AC1 "fix only if a defect appears" → no fix).
- Probe (d) recovery: under the piped-stdin emulator REPL, QUIT catches the `?NOSUCH?` `-13 THROW` line-by-line and continues, so the suite-end sentinel after (d) prints (recovery witness). The HW copy `disk/a/P202WRDS.FTH` is reordered (suite-end BEFORE (d), no `BYE`) because on real hardware `INCLUDE` aborts at the undefined word — there the abort + returned prompt is the recovery witness.

### Completion Notes List

**Pre-edit baseline (captured at dev-pass start, clean tree HEAD `7ee97fd`):**
- Binary: `wc -c build/antforth.com` = **27622 B** (NOT 20.1's stale story-text 27516 B; the 20.1 CR pass `d078548` grew it — exactly the drift this story's AC8 warns about).
- `make test-repl` = 975 PASS / 0 FAIL; `make test-repl-banking` = 61 PASS / 0; `make test-repl-banking-isolated-20-1` = 6/6.

**Post-edit gates (AC8/AC9 — all green):**
- Binary unchanged: **27622 B (0 B delta)** — verification + test/doc/Makefile only; no kernel code assembled (AC8 satisfied: 0 B, well under the ≤ ~80 B ceiling).
- `make test-repl` = 975/0 (the `XYZZY ?` undefined-word assertion holds → FR-P4-30 retirement leaves the error surface intact).
- `make test-repl-banking` = 61/0; **new `test-repl-banking-isolated-20-2` = 5/5**; `-20-1` = 6/6; isolated 19-3/19-4/19-5-1 = 15/2/2 (the "6/15/2/2" cohort with 20-1); `test-straddle-regression` = 3/3; `test-file-sanity` = 0 errors (new `P202WRDS.FTH` 0x1A-terminated); `check-doc-sync` = 0 drift.

**AC1/AC2 (FR-P4-29 — verified, not built):** Probe (a) confirms two bank-5 colon words (`_w52a`/`_w52b`) appear in `WORDS` typed from bank 0; probe (c) confirms a fixed/kernel name (`DUP`) and a bank-5 name (`_w52c`) both list in one run (per-entry page-in mixes fixed + banked without drop); probe (b) confirms `BANK@` and the slot-2 page (`MBB-GET-2`) read identically before/after a `WORDS` call that paged bank 5 in (caller state restored). No kernel WORDS code was written — the mechanism shipped in 20.1 CR `d078548`.

**FR-P4-30 retirement rationale (recorded verbatim per Dev Notes directive):**
> The planned source-bank error attribution assumed per-bank wordlists, each tagged with one `bank`, so a FIND miss could name "the bank-5 wordlist FOO you didn't switch to." The 20.1 re-spec deleted that model: there is one global wordlist whose entries are scattered across banks, and bank-aware FIND resolves a name in *any* bank that is reachable through the search order. A FIND miss therefore no longer carries a "wrong bank" hypothesis to attribute — the word is simply absent everywhere the search order reaches. Adding current-bank echo or traversed-bank lists was considered (project-lead question, 2026-06-10) and declined as low-value noise on the hot error path. The `<word> ?` surface stays Phase-3-identical; AC6-d is the standing witness.

The undefined-word formatters were confirmed unchanged by reading: interpret path `src/outer_interpreter.asm:303-316` (TYPE word → space → `?` → CR → `-13 THROW`); compile path `src/compiler.asm:614-628` + `bdos_print_q_crlf`. No code change made. The planning artifact `epics-phase4-epics-16-22.md` §"Story 20.2" is annotated with a RE-SPEC + PARTIAL RETIREMENT banner marking FR-P4-30 retired-not-implemented (and FR-P4-29 verify-not-build).

**AC4 (reconciliation):** Corrected the stale "WORDS does not page-in yet — Story 20.2" line in the 20.1 story's Known limitations. `grep` of `src/` found **no** comment deferring WORDS bank-awareness to "Story 20.2" (the `words_deref`/`w_WORDS_cf` comments already describe the shipped mechanism), so no source-comment edits were needed.

**AC5 (CCD-3):** Probes + retirement note cite `docs/antforth-banking-redesign.md §5.5` (bank-aware FIND / INTERIM GOTCHA closed by fat pointers) and `§5.4` (per-bank state). Flag for Story 20.3 / `make check-doc-sync` (B.5): §5.5's *resolution* prose still describes the superseded per-wordlist-bank-field design — broader doc-sync reconciliation is deferred there, not owned here.

**AC7 — hardware smoke PASS:** `INCLUDE P202WRDS.FTH` typed on real MicroBeast (AntForth v3.0.4, 27063 B free, 12 banks; transcript `beastty-20260611-231019.bin`). Order on silicon matched the HW-file layout (a → b → c → suite-end → d):
- (a) WORDS dump between the a-sentinels lists `_w52a` and `_w52b` (bank-5 headers printed from bank 0).
- (b) `result=-1` (BANK@ + slot-2 page identical before/after the WORDS that paged bank 5 in; `_w52d` also visible in the listing).
- (c) one WORDS run lists both `DUP` (fixed/kernel, addr < $8000) and `_w52c` (bank-5) — mixed fixed/banked chain, none dropped.
- suite-end sentinel printed → a/b/c completed with no mid-suite halt.
- (d) `?NOSUCH? ?` printed with **no bank suffix**, then `error -13: undefined word` (the INCLUDE/uncaught-THROW handler as the -13 aborts the include) and the interactive prompt returned — FR-P4-30 retirement holds on silicon; kernel recovered cleanly (no hang). Operator note: two filename typos preceded the run (`p202words.fth` → `error -38: file not found`); the correct `P202WRDS.FTH` ran clean.

### File List

- `tests/banking_tests_20_2.fth` (new) — isolated WORDS-traversal + FR-P4-30-retired probes (a/b/c/d).
- `Makefile` (modified) — `test-repl-banking-isolated-20-2` recipe + `.PHONY` entry.
- `disk/a/P202WRDS.FTH` (new) — CP/M 8.3, `0x1A`-terminated hardware-smoke copy (HW-ordered: suite-end before the undefined-word abort).
- `_bmad-output/implementation-artifacts/20-1-per-wordlist-bank-field-find-save-switch-walk-restore.md` (modified) — stale "WORDS does not page-in yet" note corrected (AC4).
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` (modified) — Story 20.2 §: FR-P4-30 retired / FR-P4-29 verify-not-build re-spec banner (AC3).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — story status ready-for-dev → in-progress → review.
- `_bmad-output/implementation-artifacts/20-2-…md` (this file) — Dev Agent Record, task checkboxes, status.

### Change Log

- 2026-06-11 — Story 20.2 dev pass: verified bank-aware `WORDS` (FR-P4-29) by new isolated probes + retired FR-P4-30 (source-bank error attribution) with rationale; no kernel code change (0 B binary delta, 27622 B). Reconciled stale 20.1/planning-artifact notes. Gates green (975/0 · 61/0 · 20-2 5/5 · 20-1 6/6 · 15/2/2 · straddle 3/3 · file-sanity 0 · doc-sync 0-drift).
- 2026-06-12 — HW smoke PASS on real MicroBeast (`beastty-20260611-231019.bin`, AntForth v3.0.4, 12 banks): AC6 (a) `_w52a`/`_w52b` listed from bank 0, (b) `result=-1` restore, (c) `DUP`+`_w52c` mixed chain, suite-end reached, (d) plain `?NOSUCH? ?` (no bank suffix) + `error -13` recover. All AC6 items confirmed on silicon; AC7 hardware gate closed.
