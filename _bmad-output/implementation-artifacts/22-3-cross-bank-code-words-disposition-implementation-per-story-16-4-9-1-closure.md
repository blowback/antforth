# Story 22.3: Cross-bank CODE-words disposition implementation (per Story 16.4 §9.1 closure)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Marc (OG user) / Pete (hardware-peripheral developer) who writes `CODE … END-CODE` assembler words while a non-zero bank is active,
I want `CODE` to always place the word body in fixed memory regardless of the current bank, with the word reachable from every bank,
So that user CODE-words match the §9.1/PD-P4-15 contract ("CODE words live in fixed memory only") *literally* — `5 BANK! CODE FOO … END-CODE` defines FOO into fixed memory, `' FOO BANK-OF .` returns `-1`, and `FOO` runs from any bank — instead of silently landing a body in the active bank window where it would be invocable only from its home bank.

## Acceptance Criteria

**Disposition source (binding):** Story 16.4 §9.1 closed as **option (b) — "No, CODE words must live in fixed memory"** (`architecture.md` PD-P4-15, 2026-05-14). The project lead elected the **redirect** implementation of (b) over the doc-only reading (decision recorded 2026-06-14 at story-draft time — see Dev Notes "Disposition-mechanism decision"). All ACs below inherit option (b) verbatim.

**Given** §9.1/PD-P4-15 fixed `CODE`-words-in-banks as "fixed-memory only; cross-bank CODE-word semantics N/A",
**When** Story 22.3 is dev-passed,

1. **AC1 (disposition read verbatim)** — The implementation reads the disposition from `architecture.md` PD-P4-15 (`#### PD-P4-15: CODE-words-in-banks policy (§9.1 closure)`) and the `**Decision:** (b)` / `**Architectural impact:**` paragraphs. The chosen disposition — "CODE words live in fixed memory only" — is inherited verbatim; the redirect mechanism is the *implementation* of that disposition (not a new disposition).

2. **AC2 (redirect `w_CODE_cf` → fixed memory)** — `src/assembler.asm`'s `w_CODE_cf` is extended so that when `CODE` is invoked with a non-zero live bank (`current_bank != 0` / `triple_owner != 0`), the new word's header **and** body are built in the **fixed-memory (bank-0) dictionary**, not the active bank window. Concretely: at `CODE` entry, after the nested/STATE guards, the live `(HERE, LATEST, wordlist_head)` triple is swapped to bank 0 for the duration of the `CODE … END-CODE` sequence; the originating bank index is stashed so `END-CODE` (and the `asm_cleanup` error path) can restore the originating triple. When `CODE` is invoked from bank 0, behaviour is **byte-identical** to the pre-Phase-4 path (the swap is a no-op / skipped).

3. **AC3 (no descriptor stub; direct reachability)** — A CODE word forced into fixed memory is reachable **directly** from its CFA like a kernel word — it does **not** get a banked descriptor stub (per PD-P4-15: "CODE words don't get banked stubs, they are reachable directly from fixed memory"). `EXECUTE` of such a word does **not** route through the Story-18.3 RST-`$28` stub-dispatch path. Slot-2 MMU mapping is **not** changed by the redirect (fixed memory is always accessible regardless of the slot-2 page).

4. **AC4 (cross-bank visibility)** — A CODE word defined while bank N (N≠0) is active is **findable and executable from every bank**, including bank 0 and other non-zero banks, via the bank-aware FIND fat-pointer chain (Story 20.1). The defining session (`5 BANK! CODE FOO … END-CODE`) leaves FOO visible at the very next prompt in bank 5 **and** after `0 BANK!`. (This is the #1 implementation risk — see Dev Notes "Risk 1: cross-bank findability".)

5. **AC5 (FR-P4-42 byte-identical CODE-source compat)** — All existing pre-Phase-4 CODE-word source assembles correctly under the banked build and produces **byte-identical** output when compiled in bank 0 (the same fixed-memory region CODE words always landed in). A verification probe asserts a representative bank-0 `CODE … END-CODE` definition produces the identical body bytes / dictionary layout as the Phase-3 close-out path (no regression to the `asm_mode` / opcode-emitter / `END-CODE` machinery).

6. **AC6 (CCD-3 source citation)** — The redirect implementation cites `architecture.md` PD-P4-15 (§9.1 closure) verbatim in the source comment per NFR-P4-20 / CCD-3, including the disposition string and the redirect-vs-doc-only decision provenance pointer (this story).

7. **AC7 (REPL probes — isolated banking fixture)** — Probes for the redirect disposition land in a new isolated fixture `tests/banking_tests_22_3.fth` + `make test-repl-banking-isolated-22-3` (isolated because every probe switches into a non-zero bank — `feedback_phase4_probe_bank_switch_limitation`):
   - (a) **fixed-memory placement**: `5 BANK! CODE FOO <body> END-CODE` then `' FOO BANK-OF` returns **-1** (fixed memory), anchored between literals.
   - (b) **cross-bank execute**: the same FOO runs and produces its expected result both **in bank 5** (home bank) and **after `0 BANK!`** (cross-bank) — proving direct fixed-memory reachability with no stub-dispatch hang.
   - (c) **bank-0 baseline**: a `CODE … END-CODE` defined in bank 0 behaves exactly as today (control witness for AC5).
   - A suite end-sentinel proves no mid-suite kernel halt.

8. **AC8 (probe surfaces + hardware smoke)** — Probes pass under the banking-capable emulator (`iz-cpm-banking`); one hardware-typed probe batch covering AC7 runs on real MicroBeast per S9 / NFR-P4-11, and the transcript + recipe are posted **in the code-review closing chat message** (`feedback_post_hw_smoke_steps_at_review`).

9. **AC9 (binary delta — re-derived, deviation flagged)** — `wc -c build/antforth.com` grows by **≤ ~50 B** for this story. NOTE: this **supersedes** the architecture's "0 B / no behavioural change" budget line for §9.1 (`architecture.md:461`, `:499`) — that line assumed the doc-only reading of (b); the project lead's redirect election re-opens a non-zero cost. The estimate is **itemised per-component** in Dev Notes "Byte budget (itemised)" (NOT derived by analogy to any prior story — B.2 / Lesson 13-5C). The Epic-22 ~100 B envelope check in Story 22.4 (AC7) must fold in this re-derived figure.

10. **AC10 (regression gates)** — `make test-repl` ≥ **974 PASS / 0 FAIL** on iz-cpm (bank-0 / fixed-memory CODE-word behaviour preserved exactly per AC5; current baseline 975/0). `make test-repl-banking` 62/0 unchanged; `make test-repl-banking-isolated-22-3` reports the new probes PASS. `make test` (assembler thread) PASS. `make test-straddle-regression` 3/3.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `make clean && make && wc -c build/antforth.com` → record in Dev Notes.
  - Do **not** inherit the orientation number below — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F). For orientation only: **28446 B** at HEAD `2b04eb2` (Story 22.2 CR-fix close). Record the absolute size + which HEAD it reflects.
  - **Measured: 28446 B at HEAD `2b04eb2`** (orientation number confirmed by fresh `make clean && make`).
- [x] Capture current `make test-repl` baseline pass count (orientation: **975 PASS / 0 FAIL** at HEAD `2b04eb2`) and `make test-repl-banking` (orientation: **62 / 0**).
  - **Measured: `test-repl` 975 / 0; `test-repl-banking` 62 / 0** (both confirmed at baseline).

### Story tasks

- [x] **Task 1 — Confirm disposition + decision provenance (AC1, AC6)**
  - [x] Re-read `architecture.md` PD-P4-15 (§9.1 closure) at draft-validated location (search `#### PD-P4-15`); confirm `**Decision:** (b)` and the `**Architectural impact:**` paragraph. Quote the disposition string verbatim for the source comment.
  - [x] Record the redirect-vs-doc-only fork resolution (this story, 2026-06-14, project-lead = redirect) so the CCD-3 comment can point at it.

- [x] **Task 2 — Extend `w_CODE_cf` to redirect to fixed memory (AC2, AC3)**
  - [x] At `w_CODE_cf`, after the existing STATE/`asm_mode` nested guards and **after the entry `EXX`** (so the swap runs in the post-EXX scratch main set — TOS/IP/W are parked in shadows, so the swap needs no register preservation; see "Implementation deviations" below), read `current_bank`; if non-zero, stash the originating bank index in the new scratch cell `asm_code_home_bank` ($FF-sentinelled) and swap the live triple to bank 0 via `bank_triple_swap` (A = originating bank to save-target, C = 0 to load), then set `triple_owner = 0` so `build_header` runs against the fixed-memory triple.
  - [x] EXX/IP handling resolved by swapping **after** the entry `EXX` rather than before (see "Implementation deviations"): in that scratch context A/BC/DE/HL are all free, so no `PUSH DE`/`POP DE` IP bracket is needed. Did **not** call `switch_live_bank_to_c` — `current_bank` stays on the user's bank; only the triple + `triple_owner` move.
  - [x] Confirmed **no descriptor stub** is allocated (no `stub_allocate` call) — the redirected word takes the bank-0 legacy CFA layout (verified: probe-a `BANK-OF FOO = -1`, probe-b direct execute with no RST $28 hang).

- [x] **Task 3 — Restore originating triple at `END-CODE` + error path (AC2)**
  - [x] At `END-CODE` (`w_END_CODE_cf`): after the LATEST restore / SMUDGE-clear / `asm_mode`-clear, call the shared leaf `asm_code_restore_home`, which (if a redirect is active) swaps the live triple back to the originating bank and re-points `triple_owner`. Placed AFTER the LATEST restore so `table[0].LATEST` is saved pointing at the new fixed-memory word.
  - [x] Mirrored the restore on the uncaught-THROW cleanup path: `asm_cleanup` (`src/assembler.asm`) calls the same `asm_code_restore_home` leaf at its tail, and the build_header no-name path (`.code_no_name`) calls it before its THROW. Restore is idempotent and guarded by the `$FF` sentinel.

- [x] **Task 4 — Cross-bank findability verification (AC4) — HIGH RISK**
  - [x] Verified against `src/dictionary.asm` (bank-aware FIND) + `src/compiler.asm` (build_header) + `src/banking.asm` (triple model): the hash **bucket array is global/shared** (only HERE/LATEST/`wordlist_head` are per-bank-triple), and FIND's slot-2 page-in is **address-conditioned** (`addr < $8000` → fixed, no paging), independent of the fat bank byte. So a word at a bank-0 address (< $8000) linked into the global bucket chain is findable + executable from **every** bank. The story's speculated "$FF = fixed" link design was unnecessary — bank byte 0 (= a normal bank-0 runtime word) is correct and consistent. Exercised the **other-bank** lookup explicitly: probe-b runs FOO after `0 BANK!` (cross-bank) → 42.

- [x] **Task 5 — Probes (AC7) + gates (AC10)**
  - [x] Authored `tests/banking_tests_22_3.fth` (sentinel-anchored, `DECIMAL`, `BYE`, 0x1A EOF terminator; max line 78 ≤ 128).
  - [x] Added `make test-repl-banking-isolated-22-3` target (awk sentinel extraction + `grep -qF`; added to `.PHONY`).
  - [x] Ran all gates (AC10) — see "Completion Notes". All green.

- [x] **Task 6 — Citation + binary delta (AC6, AC9)**
  - [x] Added the CCD-3 source comments in `w_CODE_cf` + `asm_code_restore_home` citing PD-P4-15 verbatim ("No, CODE words must live in fixed memory ... reachable directly from fixed memory like the existing kernel words") + the redirect-decision provenance (Story 22.3, 2026-06-14, project-lead election; supersedes architecture.md:461,499 "0 B" line).
  - [x] Re-`wc -c`: **28499 B**, delta **+53 B** vs baseline 28446 B. Re-itemised per actual opcodes (NOT by analogy) — see "Byte budget (actual)". +3 B over the ~50 B soft ceiling; project-lead-approved 2026-06-14 (keep the defensive bank-0 disarm-default guard). Story 22.4 AC7 envelope must fold in +53 B.

- [x] **Task 7 — Hardware smoke (AC8)** — **HW UAT PASS on silicon 2026-06-14**
  - [x] Ran the AC7 batch (`banking_tests_22_3.fth`) on real MicroBeast. Transcript `beastty-20260614-164138.bin` is **byte-identical to the iz-cpm-banking run**: `bankof=-1`, `home=42`, `cross=42`, `baseline=7`, `barbank=-1`, `---probe-22.3-suite-end---` present; no `error`, no `?` (undefined word), no mid-suite halt. AntForth v3.0.6, 12 banks available. Recipe + transcript filename posted in the dev-pass closing chat message (`feedback_post_hw_smoke_steps_at_review`).

## Dev Notes

### Disposition-mechanism decision (2026-06-14, project lead)

§9.1/PD-P4-15 chose option **(b) "CODE words live in fixed memory only"** with the prose "zero Epic-22 cost / no behavioural change / Phase-4 design preserved as-is". At story-draft time it was found that the live `w_CODE_cf` (`src/assembler.asm:1251`) builds the header/body against the **current** `(IY+UserArea.here)`, and post-Epic-19/20 that HERE is swapped to the **active bank** when `current_bank != 0`. So `5 BANK! CODE FOO …` would actually land FOO **in bank 5** — making "CODE words live in fixed memory" *not* automatically true, and contradicting the "no behavioural change" prose. Three implementations of (b) were put to the project lead:
- doc-only (no source change; document "define CODE words in bank 0"; doc-and-pray) — matches the "0 B" prose;
- guard (`ABORT" code?"` when bank≠0) — ~20 B;
- **redirect** (force body into fixed memory; `BANK-OF` → -1) — **CHOSEN**.

The redirect makes the disposition string literally true with no footgun. It is a deliberate, project-lead-authorised **deviation** from the architecture's "0 B / no behavioural change" budget line; AC9 re-derives the cost and Story 22.4's Epic-22 envelope check must absorb it. This is a scope election, not a bug-accept — no "accept-with-rationale of a defect" framing applies.

### Mechanism map (read these before editing)

- **CODE flow:** `w_CODE_cf` `src/assembler.asm:1249-1302` (header build under `EXX` shadow; `build_header` → HERE := code field; `asm_mode := 1`). `END-CODE` `src/assembler.asm:1305+` (`w_END_CODE_cf`; SMUDGE-clear + `asm_mode := 0`; "No HERE adjustment — opcode words already advanced HERE"). Error/cleanup path `asm_cleanup` (`src/assembler.asm:833` region + the `exception.asm` asm hook at the THROW preamble).
- **Assembler scratch cells:** `src/assembler.asm:77-88` (`asm_mode`, `asm_saved_here`, `asm_body_start`, `asm_saved_head`, `asm_saved_bucket`, `asm_saved_wid`, `asm_saved_bank`, `asm_smudge_addr`). Add the redirect home-bank cell + flag here (one byte each; or a single $FF-sentinelled `asm_code_home_bank`).
- **Triple swap:** `bank_triple_swap` `src/banking.asm:333-338` (ENTRY: A = save-target bank, C = load-source bank; saves live triple→table[A], loads table[C]→live; clobbers A/BC/DE/HL; IX/IY preserved; transient `PUSH BC`). Use this directly — A = originating bank, C = 0 at CODE; A = 0, C = originating bank at END-CODE. **Do NOT** use `switch_live_bank_to_c` `src/banking.asm:358` (it also remaps slot 2 and overwrites `current_bank`/`triple_owner` — we must leave `current_bank` on the user's bank; only the triple moves to bank 0).
- **`triple_owner` vs `current_bank`:** `src/structures.asm:55-60`. `triple_owner` = bank that owns the live triple; it "diverges from `current_bank` only inside a cross-bank dispatch window". The redirect creates exactly such a divergence (`current_bank` = N, triple = bank 0) for the CODE..END-CODE window — set/restore `triple_owner` accordingly so any THROW caught-path triple-restore stays coherent (`exception.asm` reads frame +9 = triple_owner).
- **`BANK-OF`** `src/banking.asm:1108-1147`: legacy-CFA xt (`xt.high < $D4`, i.e. not in the stub region) → returns **-1**. A fixed-memory CODE word keeps a legacy CFA xt (no stub) → `BANK-OF` = -1. Probe AC7(a) relies on this. Use `' FOO` (not `LATEST @`) to get the CFA xt (`project_banked_marker_no_stub`).
- **Bank-table clone at COLD** (`project_bank_table_clone_at_cold`): bank-table[0]'s triple is LDIR-cloned to [1..28] at COLD. The redirect saves the originating bank's *live* triple before swapping — confirm the save/restore round-trips the originating bank's HERE exactly (no loss of in-progress bank allocations made before the `CODE`).

### Risk 1: cross-bank findability (AC4) — the make-or-break item

Linking the CODE word under the **bank-0 triple** puts it in bank-0's wordlist/bucket chain. Kernel/fixed-memory words are visible from every bank (that is how `BANK!`, `.BANKS`, etc. are callable cross-bank). The dev MUST confirm a *user* fixed-memory CODE word inherits the same cross-bank visibility — i.e. bank-aware FIND from bank N traverses the fixed-memory chain and resolves FOO. Read `src/wordlists.asm` bank-aware FIND + the fat-pointer bucket model (`project_story20_1_fat_pointers`: inline 24-bit `[addr:2][bank:1]` fat pointers; bank byte $FF = fixed). If FIND from bank N does **not** reach bank-0-linked words, the redirect must link FOO into the fixed-memory chain the kernel uses (bank byte $FF), not merely "bank 0's wordlist". AC7(b)'s explicit other-bank execute is the gate; do not pass AC4 on the home-bank probe alone.

### Risk 2: EXX shadow + IP preservation around the swap

`w_CODE_cf` runs `build_header` between `EXX` (line 1264) and `EXX` (line 1297). `bank_triple_swap` clobbers the **main** set and does a transient `PUSH BC`. Place the swap so it does not corrupt the shadow-saved TOS/IP/W, and preserve DE(IP) across it (idiom: `PUSH DE` / … / `POP DE`, cf. `switch_live_bank_to_c:366`). Decide deliberately whether the swap runs before or after the `EXX` — simplest is likely to swap in the **main** context (before `EXX`/after the guards) since the swap is register-heavy.

### Byte budget (itemised — per B.2 / Lesson 13-5C; no analogy-to-prior-story)

Independent per-component estimate for the redirect (opcode bytes):
- CODE-entry bank check: `LD A,(IY+current_bank)` (3) + `OR A` (1) + `JR Z,skip` (2) = **6 B**
- stash originating bank + set flag: `LD (asm_code_home_bank),A` (3) = **3 B**
- swap-to-bank-0 at CODE: `LD C,0` (2) + `CALL bank_triple_swap` (3) + DE preserve `PUSH DE`/`POP DE` (2) = **7 B**
- END-CODE restore guard + swap-back: `LD A,(asm_code_home_bank)` (3) + `OR A`/flag test (1) + `JR Z` (2) + `LD C,A`/`XOR A` set args (2) + `CALL bank_triple_swap` (3) + DE preserve (2) + clear flag (3) = **16 B**
- error-path restore (asm_cleanup) — reuse the same guarded restore via a shared leaf (CALL ~3 B + the leaf counted above) = **~3 B**
- data cells: `asm_code_home_bank DB` (1) (+ optional flag byte if not sentinelled) = **1–2 B**

Per-component sum ≈ **~36 B code + ~2 B data ≈ ~38 B**; envelope **≤ ~50 B** with headroom. Re-measure actual delta at Task 6; if it exceeds ~50 B, HALT and re-itemise before accepting (do not rationalise by analogy).

### Project Structure Notes

- Touch points: `src/assembler.asm` (`w_CODE_cf`, `w_END_CODE_cf`, scratch cells, `asm_cleanup`), possibly `src/exception.asm` (asm THROW-cleanup hook restore), `tests/banking_tests_22_3.fth` (new), `Makefile` (new isolated target), and a user-doc line if the dev judges one warranted (the redirect makes the behaviour self-consistent, so a doc entry is optional — unlike the doc-only reading which would have required one).
- Per `project_assembler_keep_assembly` / `project_assembler_keep_assembly.md`: the assembler stays kernel-resident in `src/assembler.asm`; do not migrate to `ASSEMBLER.FTH`.
- `current_bank` high byte is invariantly 0 (index ≤ 28) — read/compare the low byte (`project_tos_in_register` / banking convention).

### Testing standards summary

- New behavioural per-bank probes go in an **isolated** fixture + Makefile target (not the main suite) because they switch into non-zero banks (`feedback_phase4_probe_bank_switch_limitation`). Model the fixture + target on `tests/banking_tests_22_2.fth` + `test-repl-banking-isolated-22-2` (sentinel-anchored, awk-extracted, `grep -qF`). REPL-piped Forth scripts, not assembly test threads (`feedback_repl_tests_preferred`).
- Probe lines ≤ TIB_SIZE 128 (`feedback_tib_size_inline_comments`); 0x1A-terminate the .FTH (`feedback_cpm_0x1a_eof_marker`).
- Adversarial CR runs separately via the `CR` command after dev-pass close — do **not** enumerate it as an AC (instructions.xml standing rule, PD-1).

### References

- [Source: architecture.md#PD-P4-15: CODE-words-in-banks policy (§9.1 closure)] — Decision (b); `:447-463`; budget lines `:461`, `:499`.
- [Source: epics-phase4-epics-16-22.md#Story 22.3] — `:1212-1233` (AC enumeration; original AC2/AC3/AC4 branch text; superseded here by the redirect election).
- [Source: src/assembler.asm] — `w_CODE_cf` `:1249-1302`; scratch cells `:77-88`; `END-CODE` `:1305+`; `asm_cleanup` `:833`.
- [Source: src/banking.asm] — `bank_triple_swap` `:318-338`; `switch_live_bank_to_c` `:340-369`; `BANK-OF` `:1108-1147`.
- [Source: src/structures.asm] — `triple_owner` / `current_bank` `:55-60`.
- [Source: src/wordlists.asm] — bank-aware FIND (read for Risk 1).
- Memory: `project_banked_marker_no_stub`, `project_story20_1_fat_pointers`, `project_bank_table_clone_at_cold`, `feedback_phase4_probe_bank_switch_limitation`, `feedback_post_hw_smoke_steps_at_review`, `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `project_assembler_keep_assembly`.

### Git intelligence (recent work patterns)

- `2b04eb2` Story 22.2 status → done; `a9208d9` Story 22.2 CR-fix (extracted shared `bdos_emit_dec_byte` leaf — pattern: factor shared leaves, cite source, post HW smoke recipe at CR close); `57e75ee` Story 22.2 (opt-in prompt indicator; isolated-22-2 fixture + Makefile target — the template for AC7 here). Established conventions to follow: isolated banking fixtures for non-zero-bank probes; per-component byte budget; HW UAT on silicon before status→done; no Claude co-author trailer (`feedback_no_claude_coauthor`).

### Latest tech / external dependencies

- N/A — self-contained Z80/CP/M kernel; no external libraries, frameworks, or network APIs. No web research applicable.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Code dev-story workflow), 2026-06-14.

### Debug Log References

- Build: `make` → 0 errors / 0 warnings, 33875 lines, `build/antforth.com` = 28499 B.
- Direct fixture run (`iz-cpm-banking`) confirmed before wiring the Makefile target: `bankof=-1`, `home=42`, `cross=42`, `baseline=7`, `barbank=-1`, suite-end present.

### Completion Notes List

**What was implemented.** Story 22.3 redirect: a `CODE … END-CODE` word defined while a non-zero bank is live now lands in the **fixed-memory (bank-0) dictionary**, with no banked descriptor stub, findable + executable from every bank — making PD-P4-15's "CODE words live in fixed memory only … reachable directly from fixed memory like the existing kernel words" literally true.

**Mechanism (project-lead decision, 2026-06-14).** The story's stated "swap the triple only, keep `current_bank` = N" mechanism was found **insufficient**: `build_header` (`src/compiler.asm`) keyed its header layout (stub-xt cell vs legacy) and the fat dictionary-pointer **bank byte** off `current_bank`, not the triple — so a triple-only swap would have emitted a malformed bank-N-style entry at a bank-0 address and mis-attributed the word to bank N (visible via Story 20.2 `WORDS` source-bank, and a FORGET hazard). Surfaced two correct alternatives; project lead chose **build_header → `triple_owner`** (the bank that owns the live triple = the bank the entry physically lands in). This is a **0-byte, behaviour-preserving** change everywhere (`triple_owner == current_bank` on every ordinary build_header path; they diverge only in this redirect). The redirect then keeps `current_bank` on the user's bank and only swaps the triple + sets `triple_owner = 0`.

**Why findability works (AC4, the load-bearing risk).** The hash **bucket array is global/shared** (only HERE/LATEST/`wordlist_head` swap per bank), and FIND's slot-2 page-in is **address-conditioned** (`addr < $8000` → fixed, no paging), independent of the bank byte. So a word at a bank-0 address linked into the global buckets is reachable from every bank automatically. The story's speculated "$FF = fixed link" design was unnecessary; bank byte 0 (identical to any bank-0 runtime word) is correct.

**THROW coherence.** `current_bank` is never touched, so the THROW caught-path `frame +8` restore is unaffected; `triple_owner` diverges for the CODE window exactly as the caught-path `frame +9` triple-restore (`src/exception.asm`) already handles. Uncaught THROW mid-CODE → `asm_cleanup` calls the shared restore leaf; the no-name parse error → `.code_no_name` calls it before the THROW.

**Byte budget (actual — re-itemised by opcode, NOT by analogy; B.2/Lesson 13-5C).** Baseline 28446 B → 28499 B = **+53 B**:
- `compiler.asm` `current_bank`→`triple_owner` ×2: **0 B** (same `LD A,(IY+d)` encoding).
- `w_CODE_cf` arm block (disarm-default + bank read + arm + swap + `triple_owner`=0): **23 B**.
- 3× `CALL asm_code_restore_home` (END-CODE, `.code_no_name`, `asm_cleanup`): **9 B**.
- `asm_code_restore_home` shared leaf: **20 B**.
- `asm_code_home_bank` data byte: **1 B**.
This is **+3 B over AC9's ~50 B soft ceiling**. Re-itemised and surfaced per Task 6; the +3 B is the 5 B unconditional "disarm-default" guard on the bank-0 path (protects an effectively-unreachable caught-THROW-mid-CODE corner). Project lead elected to **keep the guard / accept +53 B** (2026-06-14), consistent with the pre-authorised "deliberate deviation from the architecture's 0 B / no-behavioural-change budget line" (architecture.md:461,499). **Story 22.4 AC7 must fold +53 B into the Epic-22 ~100 B envelope.**

**Implementation deviations from the story's task text (all toward correctness, project-lead-authorised):**
1. The triple swap runs **after** the entry `EXX` (in the scratch main set), not before — so A/BC/DE/HL are all free and no `PUSH DE`/`POP DE` IP bracket is needed (the story suggested swapping before `EXX`; that would have clobbered the live TOS/IP/W that `EXX` is about to save to shadows).
2. `build_header` (`src/compiler.asm`) was edited (outside the story's stated assembler.asm-only touch points) — the 0-byte `current_bank`→`triple_owner` change is what makes the redirect produce a true kernel-like fixed-memory entry; approved 2026-06-14.

**Gate results (AC10):**
- `make test` (assembler thread): PASS.
- `make test-repl`: **975 / 0** (baseline 975/0 — no regression; AC5/AC10 bank-0 CODE preserved exactly).
- `make test-repl-banking`: **62 / 0**.
- `make test-repl-banking-isolated-22-3`: **4 PASS** (probe a/b/c + suite-end).
- `make test-straddle-regression`: **3 / 3**.
- `make test-file-sanity`: PASS. `make check-doc-sync`: 0 drift.
- Full sweep of all other isolated banking probes (19-3 … 22-2): PASS (no cross-story regression).

**Hardware UAT (AC8): PASS on silicon, 2026-06-14.** Transcript `beastty-20260614-164138.bin` (in `~/Downloads`) — the AC7 batch on real MicroBeast (AntForth v3.0.6, 12 banks) reproduced the emulator output byte-for-byte: `bankof=-1`, `home=42`, `cross=42`, `baseline=7`, `barbank=-1`, suite-end present; no errors / no `?` / no halt. Confirms the redirect's fixed-memory placement + cross-bank reachability hold on hardware, not just under iz-cpm-banking. Remaining gate before status → done: adversarial code-review (`CR`, ideally a different LLM).

### File List

- `src/assembler.asm` — `asm_code_home_bank` scratch cell; `w_CODE_cf` redirect-arm block + `.code_no_name` restore; `w_END_CODE_cf` restore; `asm_cleanup` restore; new shared leaf `asm_code_restore_home`.
- `src/compiler.asm` — `build_header`: 2 bank reads changed `current_bank` → `triple_owner` (0-byte; enables the redirect to emit a true bank-0/fixed-memory entry).
- `tests/banking_tests_22_3.fth` — new isolated probe fixture (AC7 a/b/c + suite-end; 0x1A-terminated).
- `Makefile` — new `test-repl-banking-isolated-22-3` target; added to `.PHONY`.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `22-3-…` status `ready-for-dev` → `in-progress` → `review`.

## Change Log

| Date | Change |
|---|---|
| 2026-06-14 | Story 22.3 dev-pass: CODE→fixed-memory redirect implemented via `build_header`→`triple_owner` (project-lead mechanism election) + `w_CODE_cf`/`END-CODE`/`asm_cleanup` triple swap-and-restore. New isolated probe fixture + Makefile target. Gates green (975/0 · 62/0 · isolated-22-3 4/4 · straddle 3/3 · file-sanity · doc-sync 0-drift). Binary +53 B (project-lead-approved +3 B over the ~50 B soft ceiling; keeps the defensive disarm guard). Status → review; HW UAT pending. |
| 2026-06-14 | HW UAT PASS on real MicroBeast (transcript `beastty-20260614-164138.bin`): AC7 batch byte-identical to emulator (`bankof=-1`/`home=42`/`cross=42`/`baseline=7`/`barbank=-1`/suite-end; no errors/halt). AC8 satisfied. Status stays `review` pending adversarial code-review. |
| 2026-06-14 | Adversarial code-review closed (high effort). Two correctness candidates surfaced — (1) caught-then-re-raised THROW double-restoring the live triple via `exception.asm` frame+9 + `asm_cleanup`; (2) `build_header`/stub-allocator `triple_owner`-vs-`current_bank` asymmetry corrupting `bank-table[0]` in a cross-bank dispatch window — both **empirically refuted** across ~6 instrumented probes (HERE rolled back, `LATEST` stable, words findable, at-risk xt unchanged). Root: the per-bank triple excludes the shared fat bucket array, so triple swaps never affect findability and compose back correctly; one proposed fix was net-harmful (correct HERE rollback → 10 B leak). No code-behaviour change warranted; 22.3 correct as shipped. Single survivor: comment-accuracy fix in `compiler.asm` (`triple_owner`/`current_bank` also diverge in a cross-bank dispatch window), binary byte-identical, commit `58d493c`. Status → done. |
