# Story 23.4: `UD.` + `ENVIRONMENT?` query gaps

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-28 by create-story workflow (context-engine pass).
     Story 23.4 is the fourth feature story of Epic 23 (Phase 5 — standards &
     I/O polish, → antforth v3.1.0). Two additive deliverables:
       (A) `UD.` — print an unsigned double-cell integer (one new DEFWORD).
       (B) Six new `ENVIRONMENT?` query rows (pure `env_table` data).

     FOUR load-bearing findings were resolved at DRAFT TIME by reading live
     source + the DPANS94 standard (B.4 / PD-2 figure-drift discipline; the
     standards-compliance lesson `feedback_standards_compliance`). Do NOT
     re-litigate them at dev-pass:

       (1) `UD.` IS NOT AN ANS WORD — THE EPIC'S §8.6.1.1230 CITATION IS WRONG.
           The epic (epics-phase5-epic-23.md:253, FR-P5-3) cites `UD.` as
           DPANS94 §8.6.1.1230. That section number is **`M*/`** (and antforth's
           own compliance doc maps "8.6.1230" → `DNEGATE`, line 470). `UD.`
           does NOT appear anywhere in DPANS94 — not in §8.6.1 (Double-Number)
           nor §8.6.2 (Double-Number Extension, which is only `2ROT`/`2VALUE`/
           `DU<`). `UD.` is a common-practice extension (gforth et al.). So it
           is documented as an ANTFORTH EXTENSION row in the compliance doc's
           "Non-standard words" table — exactly like 23.3 handled `IN`/`OUT` —
           NOT given the fabricated §8.6.1.1230 row. (Standards-honesty:
           `feedback_standards_compliance` — investigate the standard, never
           rationalise a wrong citation.)

       (2) ENV-QUERY HONESTY — THREE OF THE SIX NEW QUERIES ANSWER `false`,
           NOT `true`. DECIDED WITH ANT 2026-06-28.
           The epic's AC2 asks for all six (`EXCEPTION`, `EXCEPTION-EXT`,
           `DOUBLE`, `DOUBLE-EXT`, `SEARCH-ORDER`, `SEARCH-ORDER-EXT`) to return
           `( true true )`. A completeness audit (grep over `src/*.asm`) shows
           three of those wordsets are NOT fully implemented:
             • `DOUBLE` (§8.6.1) — MISSING `D0<` `D0=` `D2*` `D2/` `2CONSTANT`
               `2LITERAL` `2VARIABLE` (7 words). `M*/` exists; `D+ D- D. DNEGATE
               DABS M+ D* D< D= DMAX DMIN D>S D.R` exist. Net: incomplete.
             • `DOUBLE-EXT` (§8.6.2) — `2ROT` `2VALUE` `DU<` ALL absent.
             • `SEARCH-ORDER-EXT` (§16.6.2) — MISSING `ALSO` `FORTH` `ORDER`
               `PREVIOUS`; only `ONLY` exists. Incomplete.
           The other three ARE complete: `EXCEPTION` (`CATCH` `THROW`),
           `EXCEPTION-EXT` (`ABORT` `ABORT"`), `SEARCH-ORDER` (all 8 §16.6.1
           words present in `src/wordlists.asm`).
           antforth's existing `env_table` is already scrupulously honest about
           this: `CORE-EXT` returns `false` (`dw 0`) precisely because §6.2 is
           partial (13/46), and `FLOORED` returns `false`. Per DPANS94 §3.2.6 a
           recognised-but-incomplete wordset query returns `( false true )` —
           kind=2 flag = `0` — NOT `( true true )`. Returning `true` for
           `DOUBLE`/`DOUBLE-EXT`/`SEARCH-ORDER-EXT` would over-claim and
           contradict the `CORE-EXT` precedent. **Ant's decision (2026-06-28):
           honest flags.** So:
             EXCEPTION → $FFFF · EXCEPTION-EXT → $FFFF · SEARCH-ORDER → $FFFF
             DOUBLE → 0     · DOUBLE-EXT → 0      · SEARCH-ORDER-EXT → 0
           This is a deliberate correction to the epic's literal AC2 — recorded
           here so the dev does NOT "fix" it back to all-true.

       (3) `UD.` IS THE `D.` PATTERN MINUS THE SIGN MACHINERY — EVEN SIMPLER.
           `D.` (formatting.asm:161-178) does `DUP >R DABS <# #S R> SIGN #>
           TYPE SPACE` to carry the sign. `UD.` is unsigned, so it drops ALL of
           that: just `<# #S #> TYPE SPACE` operating directly on the `ud`. No
           `DABS` (the value is already unsigned — taking DABS would corrupt
           values ≥ 2^31), no `SIGN`, no `DUP`/`>R`/`R>`. Five threaded cells.
           This is the heart of AC1's "no sign-flip": a `ud` with the high cell's
           top bit set (e.g. `4294967295.`) MUST print as a big positive, which
           is automatic because `<# #S #>` treat the cell-pair as unsigned and
           UD. never calls SIGN/DABS. (Contrast `D.` of the same value → `-1`.)

       (4) GET THE env-row LENGTH BYTES EXACTLY RIGHT — A MISCOUNT CORRUPTS THE
           TABLE WALK FOR EVERY ROW AFTER IT.
           Each `env_table` row is `db len, "KEY", kind, value(2|4)` and the
           walker (`system.asm` `.env_advance`) uses `len` to step to the next
           row. A wrong `len` desynchronises the walk for all following entries
           (and ultimately the terminator). Verified char counts (count them,
           do not eyeball): `EXCEPTION`=9, `EXCEPTION-EXT`=**13**, `DOUBLE`=6,
           `DOUBLE-EXT`=10, `SEARCH-ORDER`=12, `SEARCH-ORDER-EXT`=16. (A first
           draft of this analysis miscounted `EXCEPTION-EXT` as 12 — it is 13.)
           The six new rows append AFTER the last data row (`STACK-CELLS`) and
           BEFORE the `db 0` terminator. kind=2 walks identically to kind=0
           (2 value bytes), so `.env_advance` needs NO change (AC4). -->

## Story

As a Forth programmer,
I want `UD.` and the missing `ENVIRONMENT?` wordset-presence rows,
so that unsigned doubles print without a spurious sign and wordset-detection
queries answer **truthfully** — `true` for the wordsets antforth fully
implements and `false` (recognised, not present) for the ones it does not.

## Acceptance Criteria

1. **`UD. ( ud -- )` prints an unsigned double-cell integer** in the current
   `BASE`, followed by one trailing space, with **no sign**. `0. UD.` → `0 `.
   A value with the high cell's top bit set prints as a large positive with no
   sign-flip: in `DECIMAL`, `4294967295. UD.` → `4294967295 ` (whereas
   `4294967295. D.` → `-1 `). Honours `BASE` (works in `DECIMAL` and `HEX`).
   Built on the existing pictured-output sequence `<# #S #>` + `TYPE` + `SPACE`
   — NO `DABS`, NO `SIGN` (it is the `D.` thread with the sign machinery
   removed). `UD.` is an **antforth / common-practice extension**, NOT an ANS
   word (the epic's §8.6.1.1230 citation is `DNEGATE`'s number; see draft
   finding (1)) — flagged as an extension row in the compliance doc, no
   fabricated `§` number.

2. **Six new `ENVIRONMENT?` wordset-presence queries are recognised, answering
   honestly per the completeness audit** (draft finding (2); Ant's decision
   2026-06-28):
   - `S" EXCEPTION" ENVIRONMENT?` → `( true true )` (`CATCH`/`THROW` present).
   - `S" EXCEPTION-EXT" ENVIRONMENT?` → `( true true )` (`ABORT`/`ABORT"` present).
   - `S" SEARCH-ORDER" ENVIRONMENT?` → `( true true )` (all 8 §16.6.1 words present).
   - `S" DOUBLE" ENVIRONMENT?` → `( false true )` (recognised; §8.6.1 incomplete —
     `D0< D0= D2* D2/ 2CONSTANT 2LITERAL 2VARIABLE` missing).
   - `S" DOUBLE-EXT" ENVIRONMENT?` → `( false true )` (recognised; `2ROT 2VALUE
     DU<` absent).
   - `S" SEARCH-ORDER-EXT" ENVIRONMENT?` → `( false true )` (recognised;
     `ALSO FORTH ORDER PREVIOUS` missing).
   The `false`-flag rows are consistent with the existing `CORE-EXT`/`FLOORED`
   precedent (recognised-but-not-fully-present → `( false true )`, kind=2 flag
   = `0`). **This deliberately overrides the epic's literal "all six true."**

3. **All pre-existing `ENVIRONMENT?` keys return byte-identical results**
   (FR-P5-8). A present key is unchanged (`S" CORE" ENVIRONMENT?` → `( true
   true )`); an incomplete-set key is unchanged (`S" CORE-EXT" ENVIRONMENT?` →
   `( false true )`); the miss path is unchanged (`S" NOPE" ENVIRONMENT?` →
   `( false )`, a single cell). The 14 original keys all still resolve.

4. **The new rows are flag-kind (`kind=2`) additions to `env_table`** in
   `src/system.asm`, appended after the last data row (`STACK-CELLS`) and before
   the `db 0` terminator. The table-walk / advance arithmetic (`.env_advance`)
   is **unaffected** — kind=2 has 2 value bytes and walks identically to kind=0;
   no advance-code edit. Length bytes are exact: `EXCEPTION`=9,
   `EXCEPTION-EXT`=13, `DOUBLE`=6, `DOUBLE-EXT`=10, `SEARCH-ORDER`=12,
   `SEARCH-ORDER-EXT`=16 (draft finding (4)).

5. **REPL-piped probe** (self-printing PASS/FAIL, column-0-anchored verdicts per
   the 23.2/23.3 lesson) covers:
   - `UD.` in `DECIMAL`: `0.` → `0 `; a value > `0x7FFF` (e.g. `100000.`); the
     full-range `4294967295.` (high bit set, no sign-flip) → `4294967295 `; and
     a negative-control `4294967295. D.` → `-1 ` proving `UD.` ≠ `D.`.
   - `UD.` in `HEX`: a value > `0xFFFF` (e.g. `1234ABCD.`) → `1234ABCD `.
   - Each new env key (3 returning `( true true )`, 3 returning `( false true )`).
   - One regression assert on an existing present key (`CORE` → true/true) + an
     existing incomplete key (`CORE-EXT` → false/true) + the miss
     (`NOPE` → single `false`).

6. **Docs reconciled.** `docs/ans-forth-core-compliance.md`:
   - `UD.` added as an **antforth-extension** row in the "Non-standard words"
     table (NOT a `§`-numbered Core/Double row — finding (1)).
   - The §3.2.6 `ENVIRONMENT?` rows (TWO enumerations: line ~27 and line ~377)
     updated from "14-entry" to "20-entry" with the six new keys listed, noting
     the three `true` and three `false`(recognised) dispositions and the
     `CORE-EXT`-consistency rationale. (Update BOTH enumerations — figure-drift
     PD-2.)
   `docs/dev_journal.md:5-8` gaps marked resolved (the `UD.` line + the three
   env-query gap lines), in the resolved-annotation style of the 23.1 entry
   (journal:10+); the annotation records that `DOUBLE`/`DOUBLE-EXT`/
   `SEARCH-ORDER-EXT` answer `false`(recognised) pending full wordset
   implementation (a future story/epic, out of 23.4 scope).

7. **No regression.** Full `make test-repl` (iz-cpm) holds at the **975-PASS**
   baseline; `test-repl-asm`, `test-repl-value-to`, `test-repl-in-out`,
   `test-repl-banking`, `test-straddle-regression`, and the new `UD.`/env probe
   all green; `make check-doc-sync` 0-drift (modulo pre-existing advisories).
   Binary delta recorded and itemised at close (est. ≈ 111 B; see Dev Notes).

8. **S9 hardware-smoke (binary-delta story).** Required on real CP/M 2.2 /
   MicroBeast before done; recipe posted **in the closing chat message** (STRONG
   — `feedback_post_hw_smoke_steps_at_review`), not only in Dev Notes.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `make` then `wc -c build/antforth.com` →
      record in Dev Notes.
  - Do NOT inherit a prior number. 23.3's close reported **28859 B**, but the
    working-tree artifact currently shows 28835 B (possibly a stale/partial
    build) — these disagree, which is exactly the figure-drift trap (B.3 /
    Lesson 13.5-F). Re-`make` and `wc -c` from the FRESH artifact; that value is
    the true pre-edit baseline. **Fresh `make` baseline = 28835 B.**
- [x] Capture current `make test-repl` (975/0) and `test-repl-banking` (62/0)
      baselines — confirm green pre-edit. **Confirmed: test-repl 975 PASS / 0 FAIL
      (+2 SKIP); test-repl-banking 0 FAIL.**

### Story tasks

- [x] Task 1 — Implement `UD.` runtime word (AC: 1)
  - [x] Add `w_U_D_DOT` / `w_U_D_DOT_cf` (`DEFWORD "UD.", 0`) in
        `src/formatting.asm`, adjacent to the unsigned-print family — recommended
        immediately after `U.R` (`formatting.asm:240`) or after `D.`
        (`formatting.asm:178`). Thread body (5 cells + terminator):
    ```
    w_U_D_DOT:
            DEFWORD "UD.", 0
    w_U_D_DOT_body:
    w_U_D_DOT_cf    EQU     w_U_D_DOT_body - 3
            DW      w_PIC_LESS_HASH_cf      ; <#     ( ud )
            DW      w_PIC_HASH_S_cf         ; #S     ( 0 0 )   — all digits, unsigned
            DW      w_PIC_GREATER_HASH_cf   ; #>     ( c-addr u )
            DW      w_TYPE_cf               ; TYPE
            DW      w_SPACE_cf              ; SPACE
            DW      EXIT_CODE
    ```
  - [x] Confirm the cf-label names against live source before assembling:
        `w_PIC_LESS_HASH_cf` (`<#`, pictured.asm:37), `w_PIC_HASH_S_cf`
        (`#S`, pictured.asm:119), `w_PIC_GREATER_HASH_cf` (`#>`, pictured.asm),
        `w_TYPE_cf` (io.asm:25), `w_SPACE_cf` (io.asm:74), `EXIT_CODE`.
  - [x] Header comment: one-line *what*, no provenance
        (`feedback_source_comment_discipline`). Note it is the `D.` thread
        without `DABS`/`SIGN` (unsigned — taking `DABS` would corrupt values
        ≥ 2^31). Underflow of an under-deep stack is trapped by `#`'s own
        `check_underflow` (same family-wide property as `D.`/`U.` — do not add a
        bespoke guard; that matches the existing print words).

- [x] Task 2 — Add the six `ENVIRONMENT?` flag rows (AC: 2, 3, 4)
  - [x] In `src/system.asm`, append after the `STACK-CELLS` row (~line 566) and
        before the `db 0` terminator (~line 568):
    ```
            ; EXCEPTION -> true (CATCH/THROW present, §9.6.1)
            db  9, "EXCEPTION", 2
            dw  $FFFF
            ; EXCEPTION-EXT -> true (ABORT/ABORT" present, §9.6.2)
            db  13, "EXCEPTION-EXT", 2
            dw  $FFFF
            ; DOUBLE -> false (recognised; §8.6.1 incomplete — D0</D2*/2CONSTANT/... missing)
            db  6, "DOUBLE", 2
            dw  0
            ; DOUBLE-EXT -> false (recognised; §8.6.2 2ROT/2VALUE/DU< absent)
            db  10, "DOUBLE-EXT", 2
            dw  0
            ; SEARCH-ORDER -> true (all 8 §16.6.1 words present)
            db  12, "SEARCH-ORDER", 2
            dw  $FFFF
            ; SEARCH-ORDER-EXT -> false (recognised; §16.6.2 ALSO/FORTH/ORDER/PREVIOUS missing)
            db  16, "SEARCH-ORDER-EXT", 2
            dw  0
    ```
  - [x] Sanity-re-count every `len` byte (finding (4)); a wrong `len` desyncs the
        walk for all following rows + the terminator. Comments state the *why*
        of each true/false (the audit), not provenance.
  - [x] Confirm `.env_advance` is untouched (kind=2 = 2 value bytes, walks like
        kind=0).

- [x] Task 3 — Author the REPL-piped probe (AC: 5)
  - [x] Create `tests/ud_env_tests.fth` (self-printing PASS/FAIL). Sections:
    - [x] **`UD.` decimal** — emit tagged column-0 lines for the Makefile to
          assert exact text (the in-Forth verdict can't easily capture `TYPE`
          output, so assert the printed string via the Makefile grep, anchored).
          E.g. `." udA=" 0. UD. CR`, `." udB=" 4294967295. UD. CR`,
          `." udC=" 100000. UD. CR`; the runtime lines land at column 0
          (`udA=0 `, `udB=4294967295 `, `udC=100000 `) while the echoed source
          (begins with `."`) does not — anchor the Makefile grep to `^udA=` etc.
    - [x] **No-sign-flip control** — `." udD=" 4294967295. D. CR` → `udD=-1 `
          (proves `UD.` ≠ `D.` for a high-bit-set value).
    - [x] **`UD.` hex** — `HEX ." udE=" 1234ABCD. UD. CR DECIMAL` → `udE=1234ABCD `.
    - [x] **Env queries (in-Forth self-assert, easy)** — e.g.
          `: _e-ex S" EXCEPTION" ENVIRONMENT? AND -1 = IF ." PASS: env-exception" ELSE ." FAIL: env-exception" THEN CR ;`
          for the three `true` keys (both cells -1 → AND = -1), and for the three
          `false` keys assert `( 0 -1 )`:
          `S" DOUBLE" ENVIRONMENT? >R 0= R> -1 = AND` → -1 means flag=0 AND
          recognised=-1 (`PASS: env-double-false`). Cover all six.
    - [x] **Regression asserts** — `CORE` → ( -1 -1 ) (`PASS: env-core`);
          `CORE-EXT` → ( 0 -1 ) (`PASS: env-coreext-false`); miss
          `S" NOPE" ENVIRONMENT?` → exactly one cell `0`
          (`DEPTH 1 = SWAP 0= AND`, `PASS: env-miss`).
  - [x] TIB-128 line lint (every probe line ≤ 128 chars — S12); word-existence
        pre-flight (`' UD. DROP` at INTERPRET level before the verdicts so a
        missing word fails loudly first). Column-0-anchor all Makefile greps
        (`^PASS:` / `^FAIL:` / `^udA=` …) so echoed source can't false-green.
  - [x] Wire a `make` target `test-repl-ud-env` mirroring `test-repl-in-out`:
        `UD_ENV_PROBE = tests/ud_env_tests.fth`, add to `.PHONY`, run under
        `$(IZCPM) $(IZCPM_DISKS)`. (Plain `$(IZCPM)` is fine — no banking needed;
        but the banking emulator is a superset, so it works either way.)

- [x] Task 4 — Docs + CCD-3 (AC: 6)
  - [x] `docs/ans-forth-core-compliance.md`:
    - [x] Add `UD.` to the "Non-standard words (not in Core or Core Extension)"
          table (~line 880, alongside `IN`/`OUT`): `| `UD.` | `formatting.asm:NNN`
          | Non-standard (Double-Number common extension — print unsigned double;
          NOT DPANS94, §8.6.1.1230 = `DNEGATE`) |`.
    - [x] Update BOTH §3.2.6 `ENVIRONMENT?` enumerations (line ~27 and line ~377)
          from "14-entry" to "20-entry"; append the six keys to the listed-keys
          sentence; note 3 answer `( true true )` and 3 answer `( false true )`
          (recognised-but-incomplete, consistent with `CORE-EXT`).
  - [x] `docs/dev_journal.md:5-8`: mark the `UD.` + three env-query gap lines
        resolved (23.1-entry annotation style at journal:10+); record that
        `DOUBLE`/`DOUBLE-EXT`/`SEARCH-ORDER-EXT` answer `false`(recognised)
        pending full wordset implementation (future scope).
  - [x] No `; antforth extension` source flag is needed for the env rows (table
        data); `UD.` carries a one-line *what* comment (it is a common-practice
        word, mildly extension-flavoured — a brief note that it is non-ANS is
        enough, matching the compliance-doc row).

- [x] Task 5 — Regression + close (AC: 7, 8)
  - [x] `make test-repl` (975/0) · `test-repl-asm` · `test-repl-value-to` (7/7)
        · `test-repl-in-out` (4) · the new `test-repl-ud-env` · `test-repl-banking`
        (62/0) · `test-straddle-regression` (3/3) · `make check-doc-sync`
        0-drift. All green.
  - [x] Final `wc -c build/antforth.com`; record delta vs the Task-0 baseline,
        itemised (UD. ≈ 21 B + six env rows ≈ 90 B ≈ 111 B; see Dev Notes).
  - [x] S9 hardware-smoke — DEFERRED to operator (no silicon in dev env). Post
        the recipe in the closing chat message (STRONG).

## Dev Notes

### Recommended implementation (synthesised from the live kernel map)

**`UD.`** is the smallest possible double-printer: `<# #S #> TYPE SPACE`. It
mirrors `D.` (`formatting.asm:161-178`) with the sign machinery (`DUP >R DABS …
R> SIGN`) deleted, because the input is unsigned. `U.` (`formatting.asm:196-205`)
is the single-cell analogue (it pushes a `0` high cell then calls `D.`); `UD.`
takes the `ud` as-is. Do NOT call `DABS` — for a `ud` whose high cell ≥ `0x8000`,
`DABS` would treat it as a negative double and negate it, corrupting the value.

**The six env rows** are pure `env_table` data (`src/system.asm`, table at
~line 521, terminator `db 0` at ~line 568). Each is `db len, "KEY", 2` + `dw
$FFFF|0`. kind=2 = flag; the dispatcher pushes (flag, $FFFF) for a hit, so
`$FFFF` → `( true true )` and `0` → `( false true )`. The walker keys off the
`len` byte — count each key's characters exactly (finding (4)).

### Standards posture (the load-bearing decision — read before coding)

- `UD.` is **not** ANS. The epic's §8.6.1.1230 is `DNEGATE` (verified against
  `docs/ans-forth-core-compliance.md:470` and the DPANS94 Double-Number set).
  Document `UD.` as an antforth/common-practice extension; do NOT invent a `§`
  number (the 23.3 `IN`/`OUT` precedent).
- The env-query flags are **honest, not blanket-true** (Ant's decision
  2026-06-28). `EXCEPTION`/`EXCEPTION-EXT`/`SEARCH-ORDER` are complete → `true`;
  `DOUBLE`/`DOUBLE-EXT`/`SEARCH-ORDER-EXT` are incomplete → `false`(recognised),
  matching the existing `CORE-EXT`=`false` posture. This OVERRIDES the epic's
  literal AC2 — do not "correct" it back. Per DPANS94 §3.2.6, a recognised query
  for an absent facility returns `( false true )`; `( false )` (single) is only
  for an UNrecognised string — so the three incomplete sets are still recognised
  rows (they answer `false true`, not a single `false`).

### Byte-budget rationale (itemised — B.2, independent per-component)

- **`UD.`** — header `DEFWORD "UD."`: hash_link 3 B + count_flags 1 B + name
  3 B (`U`,`D`,`.`) + `JP DOCOL` 2 B = **9 B**. Thread: 5 cell-pointers × 2 B =
  10 B + `EXIT_CODE` 2 B = **12 B**. UD. subtotal ≈ **21 B**.
- **Six env rows** — Σ name chars = 9+13+6+10+12+16 = 66 B; per-row overhead =
  1 (len) + 1 (kind) + 2 (value) = 4 B × 6 = 24 B. Rows subtotal ≈ **90 B**.
- **Story total ≈ 111 B**, inside the epic's ≈ 130 B figure
  (epics-phase5-epic-23.md:267) and *under* it because `UD.` (≈ 21 B) is simpler
  than the epic's ≈ 40 B `UD.` guess (no sign/DABS machinery). No bank-aware
  overhead (fixed-memory DEFWORD + static table — NFR-P4-26). Re-measure the real
  delta at close (Task 5). Running Epic-23 aggregate is already over the ≈ 300 B
  rough epic budget (23.2 alone was +310 B) — flag the cumulative at the 23.5
  CCD-4 gate; 23.4's own contribution is small.

### Source tree components to touch

- `src/formatting.asm` — add `w_U_D_DOT`/`w_U_D_DOT_cf` (one DEFWORD) near the
  `U.`/`U.R`/`D.` print family.
- `src/system.asm` — append six kind=2 rows to `env_table` before the `db 0`
  terminator (~line 568); `.env_advance` untouched.
- `tests/ud_env_tests.fth` — NEW self-asserting probe (AC5).
- `Makefile` — add `UD_ENV_PROBE` + `test-repl-ud-env` target + `.PHONY` entry
  (model on `test-repl-in-out`, Makefile ~:177; `IN_OUT_PROBE` block ~:160).
- `docs/ans-forth-core-compliance.md` — `UD.` extension row + both §3.2.6
  enumerations updated.
- `docs/dev_journal.md` — lines 5-8 resolved-annotated.

### Testing standards summary

REPL-piped Forth probes are the default (S2). Env queries self-assert in-Forth
(compare the two returned cells). `UD.`'s `TYPE` output is asserted via tagged
column-0 lines + Makefile grep (the probe can't easily capture `TYPE` inside
Forth). Keep every probe line ≤ TIB_SIZE=128 (S12); word-existence pre-flight
(`' UD. DROP` at INTERPRET level) before use. Column-0-anchor all greps
(`^PASS:` / `^FAIL:` / `^udA=` …) so echoed source can't false-green (the 23.2
lesson; Makefile ~:133-140). Binary-delta story → S9 hardware-smoke required;
post the recipe in the closing chat message (STRONG).

### Banking / hardware gotchas (carried-forward)

- `UD.` and the env rows are MMU-agnostic fixed-memory artifacts (NFR-P4-26) —
  no descriptor-stub / cross-bank machinery (contrast 23.2's `VALUE`). `UD.`
  takes the bank-0 CFA path like any kernel DEFWORD.
- `ENVIRONMENT?` lookup is case-sensitive; the new keys are uppercase literals
  (matching every existing key). Lowercase queries miss (return single `false`).

### Project Structure Notes

- No new kernel file; no new UserArea cells; no new THROW codes; no advance-code
  change. Pure additive: one DEFWORD + six static table rows.
- `UD.` is non-ANS (extension row), unlike 23.2's `VALUE`/`TO` (§6.2 Core-Ext) —
  do not give it a `§` number.
- The env-query honesty deviation from the epic's AC2 is intentional and
  Ant-approved (draft finding (2)); the story's AC2 is the source of truth, not
  the epic's "all six true."

### References

- [Source: src/formatting.asm:161-178] — `D.` (the thread `UD.` mirrors minus sign/DABS)
- [Source: src/formatting.asm:196-205] — `U.` (single→double `0`-promotion analogue)
- [Source: src/formatting.asm:132-155] — `D.R` (sign-carry pattern; what UD. omits)
- [Source: src/pictured.asm:35-46,72-150] — `<#` `#` `#S` `#>` (the pictured sequence)
- [Source: src/system.asm:521-568] — `env_table` (row format, kind codes, terminator); insert point
- [Source: src/system.asm:.env_advance ~:418-435] — table walker (len-driven; unaffected by kind=2)
- [Source: src/io.asm:24-25,73-74] — `w_TYPE_cf`, `w_SPACE_cf`
- [Source: src/wordlists.asm] — SEARCH-ORDER §16.6.1 words (all 8 present); §16.6.2 only `ONLY`
- [Source: src/double.asm] — DOUBLE §8.6.1 set (D0</D0=/D2*/D2//2CONSTANT/2LITERAL/2VARIABLE MISSING)
- [Source: src/exception.asm] — EXCEPTION §9.6 (CATCH/THROW present)
- [Source: docs/ans-forth-core-compliance.md:27,377] — §3.2.6 env-query enumerations (BOTH to update)
- [Source: docs/ans-forth-core-compliance.md:470,478] — §8.6.1.1230 = `DNEGATE`; `D.` = §8.6.1.1060 (UD.-citation correction)
- [Source: docs/ans-forth-core-compliance.md:858-882] — Non-standard words table (UD. row home; IN/OUT precedent)
- [Source: docs/dev_journal.md:5-8] — the four gaps this story closes
- [Source: Makefile:~155-235] — `IN_OUT_PROBE` / `test-repl-in-out` (model for `test-repl-ud-env`); column-0-anchor lesson
- [Source: tests/value_to_tests.fth, tests/in_out_tests.fth] — probe-authoring models (column-0 verdicts, uncaught-throw asserts)
- [Source: _bmad-output/planning-artifacts/epics-phase5-epic-23.md#Story-23.4] — epic spec (FR-P5-3 UD., FR-P5-4..8 env); ≈ 130 B; NOTE: §8.6.1.1230 citation + "all six true" both corrected here
- [Source: _bmad-output/implementation-artifacts/23-3-z80-runtime-in-out-port-words.md] — prior story (probe wiring, TIB lint, column-0 anchor, extension-row convention)
- [Memory: feedback_standards_compliance] — non-negotiable: investigate the standard (drove findings (1) and (2))
- [Memory: feedback_source_comment_discipline] — comment the *what/why*, never provenance
- [Memory: feedback_tib_size_inline_comments] — probe lines ≤ TIB_SIZE=128
- [Memory: feedback_post_hw_smoke_steps_at_review] — STRONG: HW-smoke recipe in the closing chat message
- [Memory: feedback_ceremony_diminishing_returns] — no new file for one word + six rows
- [Memory: project_epic17_envelope] — epic byte estimates run rough; re-derive per-component (here UD. comes in under)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow)

### Debug Log References

- Initial `test-repl-ud-env` run failed all nine env `^PASS: env-*$` greps: the
  REPL emits CRLF, so the trailing `\r` defeated the `$` end-anchor (the sibling
  value-to / in-out targets avoid this by not using `$`, but `$` is needed here
  to keep `env-excep` distinct from `env-excep-x`, `env-dbl` from `env-dbl-x`,
  etc.). Fixed by piping the captured `OUTPUT` through `tr -d '\r'` before
  matching. UD. column-0 lines (`^udA=` …) passed first try.
- An em-dash (U+2014) in the probe's first comment line was mangled by the CP/M
  pipe (`b^@^T`). Harmless (it is in a `\` comment) but replaced with ASCII `-`
  for the all-ASCII discipline CP/M expects.

### Completion Notes List

- **UD.** implemented in `src/formatting.asm:249` as a five-cell DEFWORD
  (`<# #S #> TYPE SPACE`) — the `D.` thread with `DABS`/`SIGN` removed. Verified:
  `0. UD.` → `0 `, `4294967295. UD.` → `4294967295 ` (no sign-flip; the same
  value via `D.` prints `-1 `), `100000. UD.` → `100000 `, `HEX 1234ABCD. UD.`
  → `1234ABCD `. Non-ANS extension row added to the compliance doc (no fabricated
  `§` number — the epic's §8.6.1.1230 is `DNEGATE`'s).
- **Six `ENVIRONMENT?` kind=2 rows** appended to `env_table` in `src/system.asm`
  before the `db 0` terminator. Honest flags per Ant's 2026-06-28 decision:
  `EXCEPTION`/`EXCEPTION-EXT`/`SEARCH-ORDER` → `( true true )`;
  `DOUBLE`/`DOUBLE-EXT`/`SEARCH-ORDER-EXT` → `( false true )`
  (recognised-but-incomplete, consistent with `CORE-EXT`). `.env_advance`
  untouched (kind=2 walks like kind=0). Length bytes 9/13/6/10/12/16 verified.
  Pre-existing keys (`CORE` → true/true, `CORE-EXT` → false/true, miss `NOPE` →
  single `false`) regression-asserted unchanged.
- **Probe** `tests/ud_env_tests.fth` + Makefile target `test-repl-ud-env`
  (wired into `.PHONY` and the `test-repl` chain). 14 column-0-anchored asserts
  (5 UD. lines + 9 env verdicts), all green.
- **Binary delta:** 28835 B → 28947 B = **+112 B** (estimate ≈111 B: UD. ≈21 B
  + six env rows ≈90 B). Inside the epic's ≈130 B figure.
- **Gates:** test-repl 975 PASS / 0 FAIL (+2 unchanged SKIP) · test-repl-asm 5/0
  · test-repl-value-to 0 FAIL · test-repl-in-out 0 FAIL · test-repl-ud-env 14/0
  · test-repl-banking 0 FAIL · test-straddle-regression 3/3 · check-doc-sync
  0 drift (31 pre-existing advisories).
- **S9 hardware-smoke:** ✅ PASS on real CP/M 2.2 / MicroBeast (operator-run
  2026-06-28). `UD.` prints unsigned with no sign-flip (`HEX 1234ABCD. UD.` →
  `1234ABCD`; `4294967295. D.` control → `-1`); the six `ENVIRONMENT?` rows
  answer honestly on silicon (`EXCEPTION`/`SEARCH-ORDER` → `-1 -1`;
  `DOUBLE`/`SEARCH-ORDER-EXT` → `-1 0` = `( false true )`); `CORE-EXT`
  regression `-1 0` unchanged; `NOPE` miss → single false (`0 0`).

### File List

- `src/formatting.asm` — added `w_U_D_DOT` / `w_U_D_DOT_cf` DEFWORD (`UD.`)
- `src/system.asm` — appended six kind=2 wordset-presence rows to `env_table`
- `tests/ud_env_tests.fth` — NEW self-asserting REPL probe (AC5)
- `Makefile` — added `UD_ENV_PROBE`, `test-repl-ud-env` target, `.PHONY` entry,
  and `test-repl` prerequisite
- `docs/ans-forth-core-compliance.md` — `UD.` non-standard-words row; both §3.2.6
  enumerations + two further mentions updated 14→20 entries with the six keys
- `docs/dev_journal.md` — the four gap lines (lines 5-8) annotated RESOLVED +
  a dated Story 23.4 resolution section
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 23.4 → review

## Change Log

| Date | Change |
|------|--------|
| 2026-06-28 | Story 23.4 implemented: `UD.` unsigned-double printer (formatting.asm) + six honest `ENVIRONMENT?` wordset-presence rows (system.asm); new `tests/ud_env_tests.fth` probe + `test-repl-ud-env` target; compliance doc + dev journal reconciled. +112 B (28835 → 28947). All gates green (test-repl 975/0, banking 0 fail, straddle 3/3, doc-sync 0 drift). Status → review. |
| 2026-06-28 | S9 hardware-smoke PASS on real CP/M 2.2 / MicroBeast (operator-run): `UD.` no sign-flip + all six `ENVIRONMENT?` rows confirmed on silicon. |
