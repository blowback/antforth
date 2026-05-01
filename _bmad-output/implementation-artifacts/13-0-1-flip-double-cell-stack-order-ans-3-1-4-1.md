# Story 13.0.1: Flip double-cell stack convention to ANS-compliant high-on-TOS — ANS Forth 1994 §3.1.4.1 (Epic 10 back-fill)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the parameter-stack representation of a double-cell integer to put the **most-significant (high) cell on TOS** with the least-significant (low) cell below — and the in-memory `2!`/`2@`/`(DLIT)` layout to put the **high cell at the lower address** — exactly as ANS Forth 1994 §3.1.4.1 and §6.1.0350 mandate,
So that double-cell idioms portable from any other ANS-compliant Forth (`1024. .S` showing `<2> 0 1024` is wrong; it should show `<2> 1024 0`) work as written, the v2.0 release tag can credibly claim §-level Core compliance, and Story 13.1's file-position double-cell math (per §11.3.5) is built atop the correct convention from day one — closing a structural compliance gap that Epic 10's word-counted "100% Core" survey missed.

**Back-fill rationale (caught 2026-05-01 party-mode discussion, post-Story-13.0):** Epic 10's compliance claim was assembled from a **word-coverage** survey (DEFCODE/DEFWORD enumeration in `docs/ans-forth-core-compliance.md`). §3.1.4.1 ("Double-cell integers") is a **stack-layout rule** that applies uniformly across ~25 Core+CoreExt+Double-Number words; it is not itself a word and so was invisible to the survey. Architecture decision E10-D1 (`architecture.md:248-252`) committed *the wrong convention* — citing the standard but inverting the requirement. Every double-cell word (`D+` / `D-` / `D*` / `DNEGATE` / `DABS` / `D=` / `D<` / `DMAX` / `DMIN` / `M+` / `M*` / `UM*` / `UM/MOD` / `SM/REM` / `FM/MOD` / `S>D` / `D>S` / `2DUP` / `2DROP` / `2SWAP` / `2OVER` / `2@` / `2!` / `D.` / `D.R` / `(DLIT)` / `<#` / `#` / `#S` / `#>`) was implemented *consistently against the inverted convention* — the kernel is internally coherent but coherent against the wrong convention. Story 13.0.1 flips the convention; the kernel becomes internally coherent against the **correct** convention.

**Mirror of Story 13.0's pattern.** Story 13.0 closed a parser-level §3.4.1.3 gap that the word-counted survey had missed; Story 13.0.1 closes a stack-layout §3.1.4.1 gap of the same shape. Per project lead 2026-05-01: not a verdict-only audit — the deviation is documented, the fix is mandatory, and the work lands inside this single story before Story 13.1's file-access dev-pass starts.

## Acceptance Criteria

1. **Given** ANS Forth 1994 §3.1.4.1 ("Double-cell integers") — *"On the stack, the cell containing the most significant part of a double-cell integer shall be above the cell containing the least significant part"* — and §6.1.0350 `2@ ( a-addr -- x1 x2 )` — *"x2 is stored at a-addr and x1 at the next consecutive cell"*,
   **when** any double-cell value lives on the parameter stack,
   **then** the high cell is on TOS and the low cell is second-on-stack; **and** when any double-cell value lives in memory at `a-addr`, the high cell is at `a-addr` and the low cell is at `a-addr+2` (cells stored low-byte-first within each cell per Z80 little-endian; the *cell-pair* order is high-then-low). The recogniser-level `1024. .S` post-fix output is `<2> 1024 0  ok` (high=1024 below... actually re-read: `1024.` = `0x00000400`, low cell=1024, high cell=0; per the standard high cell is on TOS so `.S` prints bottom→top → `<2> 1024 0` where TOS=`0`=high). Spelt out: `1024. .S → <2> 1024 0  ok`; `0xDEADBEEF. .S → <2> -16657 -8531  ok` (low=0xBEEF=-16657 below, high=0xDEAD=-8531 on TOS). Pre-fix output (current, wrong) is `<2> 0 1024  ok` for `1024.`.

2. **Given** the architecture-decision register E10-D1 (`_bmad-output/planning-artifacts/architecture.md:248-252`),
   **when** Story 13.0.1 lands,
   **then** the E10-D1 entry is **rewritten** to specify high-on-TOS / high-at-low-address, with citations to §3.1.4.1, §6.1.0350 (`2@`), §6.1.0310 (`2!`). The pre-13.0.1 wording is preserved as a struck-through "Superseded 2026-05-01" footnote so future readers see the decision history. Inline at the rewrite: a one-line acknowledgement that the original Epic-10 decision *cited* the standard but encoded the inverse, and that this back-fill closes the gap.

3. **Given** the project memory `project_tos_in_register.md` ("BC=TOS holds low cell; high cell below"),
   **when** Story 13.0.1 lands,
   **then** that memory file is **rewritten** in place — same key, opposite direction: "BC=TOS holds **high** cell; low cell second-on-stack." The "Why" line is updated to cite §3.1.4.1. The "How to apply" line is updated to direct future double-cell-touching code to push high-then-low (so low-pushed-last lands on... wait, no: push low first, push high last, BC=high). Story 13.0.1 close-out edits the memory file directly via Write; no new memory record is added. (Per the auto-memory protocol: "Update or remove memories that turn out to be wrong or outdated.")

4. **Given** every double-cell-touching word in the kernel,
   **when** Story 13.0.1 lands,
   **then** each word's stack-effect-comment is brought into agreement with the new convention AND the runtime push/pop order is flipped where required. Words to touch (verified by the dev-pass grep `grep -nE 'low cell|high cell|d.lo|d.hi' src/*.asm`):
   - `src/double.asm`: `2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`, `S>D`, `D>S`, `M+`, `D+`, `D-`, `(DLIT)`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, `UM*`, `M*`, `D*`, `UM/MOD`, `SM/REM`, `FM/MOD` — 24 words.
   - `src/formatting.asm`: `D.`, `D.R` — 2 words. (`U.`, `.`, `U.R`, `.R`, `.S` are single-cell consumers; `.S` *displays* the stack but doesn't itself reorder, so it inherits the new convention for free.)
   - `src/pictured.asm`: `<#`, `#`, `#S`, `#>` — 4 words. (`HOLD` and `SIGN` are single-cell, no flip.)
   - `src/number_prefixes.asm`: `pref_finish_value` — flip the two `PUSH HL` order so high-then-low (high lands as second-on-stack push, low lands as TOS — wait that's the inverse of what we want; re-derive in dev-pass). Concretely: today's order is `PUSH (acc_hi)` then `PUSH (acc_lo)` then `BC=2`; post-flip needs to leave high on TOS, so `PUSH (acc_lo)` first then `PUSH (acc_hi)` then `BC=2`. The 32-bit accumulator is unaffected; only the two pushes swap.
   - `src/strings.asm`: `.numq_double` — same swap as `pref_finish_value`. Single-cell `.numq_single` is unaffected.
   - `src/outer_interpreter.asm`: compile-state `(DLIT)` emit at `.got_value`'s double branch — current emit order is COMMA d.lo, COMMA d.hi (low at lower address); post-flip is COMMA d.hi, COMMA d.lo (high at lower address per §6.1.0350). The `(DLIT)` runtime in `src/double.asm:18-43` swaps the two cell reads correspondingly so the in-memory order matches `2!`/`2@`.
   - `src/double.asm` lines 12-16 byte-order convention comment is rewritten verbatim per §3.1.4.1 + §6.1.0350.
   The dev-pass produces a per-word audit table in Completion Notes Task 4 listing each word + its old line ranges + its new line ranges + the specific PUSH/POP swap applied.

5. **Given** the test corpus in `tests/double_tests.fth` and the Makefile REPL tests,
   **when** Story 13.0.1 lands,
   **then** every hand-stacked double in the test corpus is flipped from the inverted convention to the standard one. Concretely:
   - `tests/double_tests.fth` lines 1-260 (the pre-Story-13.0 hand-stacked test corpus): every two-single-cell push-then-D-op pattern (`0 5 0 7 D+`) is rewritten with the cells in the new order. The pre-Story-13.0 wording put low-cell-first in source order; the new wording puts high-cell-first. Concretely `0 5 0 7 D+` (decoded as `d1=( 5 lo, 0 hi )` and `d2=( 7 lo, 0 hi )` under the OLD convention) becomes `0 5 0 7 D+` decoded as `d1=( 5 hi, 0 lo) d2=( 7 hi, 0 lo )` under the NEW convention — same source; different *meaning*. The dev agent must walk every test, decide whether the test author intended a particular semantic value, and rewrite the source numerals accordingly. If a test was authored as "two arbitrary cells", no semantic flip is required — only the *expected output* flips. Conservative: every test gets a one-line author-intent annotation in a comment.
   - `Makefile` REPL tests 1..902: tests that hand-stack a double (e.g., `$FFFF 2 UM* .S 2DROP` at line 7568 expects `<2> 1 -2`) need the expected output flipped (`<2> -2 1` post-flip — high cell `1` on TOS). The dev-pass produces a grep audit `grep -nE 'UM\*|M\+|M\*|D\+|D-|D\*|D\.|D=|DABS|DNEGATE|2@|2!|S>D|D>S|2DUP|2DROP|2OVER|2SWAP|<2>' Makefile` and walks every hit, flipping expected outputs as needed.
   - Story 13.0's literal-input tests (Makefile 853-902) are mostly **unaffected** because they use the literal-input path — the recogniser produces the cells in the correct order for the active convention. The exceptions are the operator-with-literal-input tests (886-902) where the `D.` output is unchanged (display is canonical) but the intermediate `.S` checks would flip. Test 866 (`0xDEADBEEF. D.` → `-559038737`) is unchanged because `D.` displays the canonical signed-double interpretation independent of stack representation.

6. **Given** `.S` (`src/formatting.asm:244` `w_DOT_S`),
   **when** Story 13.0.1 lands,
   **then** `.S`'s output for a single double on the stack reads bottom-to-top `low high` (i.e. `1024. .S → <2> 1024 0  ok`). `.S` itself prints from-bottom-of-stack to TOS, so the change is purely a consequence of the new push order in literal-recogniser exits — `.S` source code does not change. The dev agent verifies this by inspection (no source edit; behaviour follows from the stack-layout flip). Documented in Completion Notes Task 6 as "no-edit verification."

7. **Given** `2!` and `2@` (`src/double.asm:24-66`),
   **when** Story 13.0.1 lands,
   **then** the in-memory cell order is flipped so that `2!` writes the high cell at `a-addr` and the low cell at `a-addr+2`, and `2@` reads back accordingly — matching §6.1.0350 ("x2 is stored at a-addr and x1 at the next consecutive cell" with x2-on-TOS-after-fetch-meaning-MSC). The round-trip invariant `d1 a-addr 2! a-addr 2@ d1 D=` returns true is preserved (Story 13.0 test 901 stays passing). The byte-pattern at `a-addr` after `1024. STO 2!` flips from `00 04 00 00` (pre-fix; low cell first) to `00 00 00 04` (post-fix; high cell first). The dev-pass adds a probe test that round-trips `0xDEADBEEF.` through `2!` then `2@` — value preserved, internal layout is high-then-low.

8. **Given** the compiled `(DLIT)` inline-data layout in colon-body bytes,
   **when** Story 13.0.1 lands,
   **then** the inline 4-byte literal at compile-state stores high cell first then low cell. The runtime `(DLIT)` (`src/double.asm:18-43`) reads high then low from the IP stream and pushes low then high so high lands on TOS. Compile-state emit at `outer_interpreter.asm`'s `.got_value` double-emit branch swaps from `COMMA w_D_LIT_cf, COMMA d.lo, COMMA d.hi` to `COMMA w_D_LIT_cf, COMMA d.hi, COMMA d.lo`. The byte-walk audit per Story 13.0 AC #11(d) is **re-run** post-flip: `: T1 1000000. ;` produces a body whose 4 inline bytes match `[w_D_LIT_cf addr][d.hi=0x000F][d.lo=0x4240]` = `[??][0F 00][40 42]` (little-endian *within* each cell, big-endian *across* the cell pair).

9. **Given** the regression baseline at Story-13.0-close (**902 highest-numbered REPL test PASS / 0 FAIL**, **18,665 bytes** post-edit, `make test` clean),
   **when** Story 13.0.1's edits land,
   **then**:
   - `make test-repl` passes 902 highest-numbered tests (all pre-existing tests pass, with their **expected outputs flipped** where the test inspects on-stack double-cell layout — see AC #5). No tests are deleted; some are rewritten. Net test count is the same 902 (or grows by 1-3 for the new in-memory-order probe per AC #7 — see AC #11 below).
   - `make test` (assembly thread) is clean.
   - The byte-count delta is approximately neutral: the flip is push/pop reordering, which is byte-for-byte symmetric on the Z80 (`PUSH HL` → `PUSH HL`; the *order* changes, not the *opcode count*). Expected envelope: **−10 to +30 bytes**. The few-byte upward drift accommodates new cell-order documentation comments (which assemble to nothing) and any incidental refactoring picked up in-pass. **Any delta beyond ±50 bytes warrants explicit justification** in Completion Notes Task 9 (mirroring Story 13.0 Task 12's discipline).

10. **Given** `docs/ans-forth-core-compliance.md` already gained a §3.4.1.3 row in Story 13.0,
    **when** Story 13.0.1 lands,
    **then** a **new §3.1.4.1 row** is added at the same level (parser-level / structural-rule section), citing this story:
    - "**§3.1.4.1 — Double-cell integers (high-on-TOS) | Implemented (Story 13.0.1) | Pre-13.0.1 the convention was inverted; Epic 10's word-counted survey missed it. Closed 2026-05-XX. The full §-by-§ re-audit is recorded as a post-2.0 carry-forward opportunity (see also Story 13.0 Task 10's identical note)**."
    Plus, in the same edit, a fresh top-of-doc note is added: "**Two §-level structural-rule gaps closed by back-fills inside Epic 13: §3.4.1.3 (Story 13.0) and §3.1.4.1 (Story 13.0.1). Both gaps were structurally invisible to Epic 10's word-counted survey. A full §-by-§ pre-2.0 re-audit pass remains a wishlist item.**"

11. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things") and the ten-consecutive-epic review-yield pattern,
    **when** Story 13.0.1's review runs,
    **then** **at least 1-3 LOW/MEDIUM findings are expected**. Likely candidates the review must probe:
    - **(a) Orphaned old-convention sites** — any place in the kernel that hand-builds a double-cell stack picture without going through the canonical word vocabulary. Probe: `grep -nE 'PUSH (BC|HL|DE)' src/*.asm | grep -B 2 -A 2 'double\|high cell\|low cell'` and walk the hits. Story 12.x or Epic 11 may have hand-built a double-cell representation (e.g., `THROW` raising a `-3` stack-overflow code is single-cell; but `CATCH`'s frame layout — verify it doesn't store a double-cell using the old order).
    - **(b) Compiled-binary forwards/backwards compatibility** — antforth ships as a single `.com`; old colon definitions saved to `disk/a/` source files would have been re-compiled at INCLUDE time, so there's no on-disk binary format to break. Confirm by grepping for any tooling that consumes the compiled binary cell-pair layout (e.g., a debugger or memory probe). None expected; verify.
    - **(c) `M*` and `UM*` mixed-cell-width edges** — these produce a double from two singles. The old convention left `( low high )` on stack with low-on-TOS; the new convention is `( low high )` with high-on-TOS. The body of `M*` / `UM*` likely composes the result into HL:DE or BC:HL pairs and pushes them — every push order must be re-derived from the new contract.
    - **(d) `SM/REM` and `FM/MOD`** — these consume a double divisor and single dividend, returning a single quotient and single remainder. The cell-order flip changes which cell is popped first into which scratch register. Worst case: the body silently parses the wrong cells as high/low, producing arithmetic-correct-on-paper-but-wrong results that pass the existing tests (because the tests were authored to the inverted convention). The flip and the test rewrite must move *together*; a partial flip = silent corruption for any user code not exercised by the tests.
    - **(e) `2@`/`2!` byte-pattern audit** — explicit bytes-on-disk inspection per AC #7's `0xDEADBEEF.` round-trip probe. If the byte pattern after `2!` does not match `[high cell low byte][high cell high byte][low cell low byte][low cell high byte]`, the in-memory layout is still inverted. Story 13.0 test 901 verifies `2!`/`2@` *symmetrically* round-trip, which holds in either convention; this story's new probe specifically inspects the bytes at `HERE` post-`2!` to verify the cell-pair layout matches §6.1.0350.
    - **(f) `(DLIT)` runtime + emit symmetry** — the inline data layout AND the runtime read order must flip *together*. A half-flip silently corrupts every double-literal in compiled code. Test 874 (compile-state `1000000.` → display `1000000`) is symmetric and passes either way; a new probe is needed that compiles a double-literal AND inspects the body bytes (`: T1 0xDEADBEEF. ;` then `' T1 >BODY` byte walk; the 4 inline bytes after the (DLIT) xt must read `EF BE AD DE` little-endian-within-cells, big-endian-across-cells, NOT `AD DE EF BE`).
    - **(g) `D.` correctness invariant** — the printed value of a literal-input double must match the value semantically intended. Pre-fix and post-fix, `1000000. D.` prints `1000000`; the literal-input path produces the cells in the right order for whichever convention is active, and `D.` consumes them in the matching order. Test 874-880 baseline must remain green post-flip. Failure here = recogniser flip and `D.` flip are out of sync.
    - **(h) Memory-as-source-of-truth audit** — the project memory `project_tos_in_register.md` rewrite is verified by reading the file post-edit and confirming the new direction is on-disk. The `architecture.md:248-252` E10-D1 rewrite is verified the same way. Both files are *load-bearing for future conversation context*; a stale memory becomes a slow-acting bug across stories.
    - **(i) Pictured-output `# / #S / #>` re-derivation** — the inner loop of `#` does 32-bit shift/divide on the stack-resident double. The cell-order flip changes which cell is shifted first. Probe: `<# 1234567. #S #> TYPE` produces `1234567` post-flip (and pre-flip — symmetric output for symmetric input). New probe needed that inspects the *intermediate* state of `#` mid-loop, but this is not directly Forth-observable; the dev-pass relies on extensive test coverage of `<# ... #>` chains via `D.` and `D.R`. If `D.` regresses, `<# ... #>` is broken.

    Triage all findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale (mirror Story 12.1 / 12.5 / 13.0 review-log discipline). Recorded in Completion Notes Task 11.

12. **Given** Story 13.1 (`13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer`) sits at `ready-for-dev` and inherits the double-cell convention for file-position math (per ANS §11.3.5 file-position is a `ud`),
    **when** Story 13.0.1 reaches `done`,
    **then** the sequencing is enforced: **Story 13.1's dev-pass does NOT begin until Story 13.0.1 is `done`.** The 13-0-1 row in `sprint-status.yaml` flips `backlog → ready-for-dev` at create-story-finalize, then progresses through `in-progress → review → done` per the dev-story workflow. Story 13.1's spec (already authored at `_bmad-output/implementation-artifacts/13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer.md`) does not need re-editing — file positions are doubles and the FCB-pool design is independent of the cell-order convention; Story 13.1 inherits the new convention transparently.

13. **Given** the in-pass-fix discipline and the structural-load-bearing escalation gate (mirror Story 13.0 AC #15),
    **when** small in-pass refinements are warranted,
    **then** they are landed inside this story — no spawning further sub-stories. The exception: if the AC #11 review surfaces a **non-double-cell** site that was relying on the old convention (e.g., a string-handling word that happened to be passing two cells in the old order), HALT and flag it as a finding for the project lead — the change becomes a separate decision (potentially a Story 13.0.1.1 fix-story). Documented in Completion Notes Task 13.

14. **Given** Story 13.0.1 is inserted post-Story-13.0 as a back-fill (the `13-0-1-...: backlog` row is added to `sprint-status.yaml` 2026-05-01 *between* the existing `13-0-...: done` row and the `13-1-...: ready-for-dev` row),
    **when** Story 13.0.1 is created via `create-story`,
    **then** `epic-13` is already `in-progress` (set by Story 13.1's create-story 2026-05-01); no epic-status flip needed. `13-0-1-...` flips `backlog → ready-for-dev` at create-story-finalize and progresses through `in-progress → review → done` per the dev-story workflow. Recorded in Completion Notes Task 14.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline + grep evidence (AC: #9, #14)**
  - [x] 1.1 `wc -c build/antforth.com` — record current bytes (expected **18,665** post-Story-13.0).
  - [x] 1.2 `make test-repl` — record PASS count (expected **902 highest-numbered, 0 FAIL**).
  - [x] 1.3 `make test` — expected clean.
  - [x] 1.4 `grep -nE 'low cell|high cell|d\.lo|d\.hi|low.cell|high.cell' src/*.asm` — produce the canonical worksheet of all sites with cell-order documentation; record line numbers as the modification baseline.
  - [x] 1.5 `grep -nE 'POP|PUSH' src/double.asm src/formatting.asm src/pictured.asm src/number_prefixes.asm src/strings.asm src/outer_interpreter.asm` — pre-edit push/pop frequency baseline; post-edit frequency should match (no opcode count change).
  - [x] 1.6 `grep -nE 'E10-D1' src/*.asm _bmad-output/**/*.md` — record every E10-D1 citation site (each gets a citation update post-flip).

- [x] **Task 2 — Architecture E10-D1 rewrite (AC: #2)**
  - [x] 2.1 Open `_bmad-output/planning-artifacts/architecture.md` at line 248 (E10-D1).
  - [x] 2.2 Replace the body of E10-D1 with the new convention: "**High cell on top of stack, low cell below** (i.e., `2@` fetches high cell into TOS, low cell into second-on-stack). High cell at lower address (`a-addr` = high cell, `a-addr+2` = low cell); each cell little-endian within itself per Z80 native order. Per ANS Forth 1994 §3.1.4.1 ('the cell containing the most significant part of a double-cell integer shall be above the cell containing the least significant part') and §6.1.0350 (`2@ ( a-addr -- x1 x2 )` with x2 on TOS = MSC; x2 stored at `a-addr`)."
  - [x] 2.3 Append a "Decision history" footnote: "**Superseded 2026-05-01 (Story 13.0.1).** Original Epic-10 decision (2026-04-XX) committed the inverted convention while citing the standard. The error was caught post-Epic-12 retro and back-filled in Story 13.0.1. The original word-counted compliance survey was structurally blind to §3.1.4.1 — see Story 13.0 retro for the same shape gap on §3.4.1.3."
  - [x] 2.4 Update the Rationale paragraph to the new wording.

- [x] **Task 3 — Project memory rewrite (AC: #3)**
  - [x] 3.1 Open `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_tos_in_register.md`.
  - [x] 3.2 Rewrite the body: "**BC=TOS holds the high cell of a double-cell value; the low cell is second-on-stack** (per ANS Forth 1994 §3.1.4.1, post-Story-13.0.1)."
  - [x] 3.3 Update the description in the YAML frontmatter to reflect the new direction; keep the `name` and `type` fields stable.
  - [x] 3.4 Update the MEMORY.md index line for this entry to reflect the new direction (~150 char limit; one-line hook).

- [x] **Task 4 — Kernel word audit + flip (AC: #4)**
  - [x] 4.1 For each word in `src/double.asm` (24 words enumerated in AC #4), produce a per-word audit row with: name, line range, list of PUSH/POP that touch a double-cell pair, the swap applied, and a one-line proof comment of the new convention.
  - [x] 4.2 For each word in `src/formatting.asm` (`D.`, `D.R`) — same.
  - [x] 4.3 For each word in `src/pictured.asm` (`<#`, `#`, `#S`, `#>`) — same.
  - [x] 4.4 `pref_finish_value` in `src/number_prefixes.asm`: swap the two `PUSH HL` order so the low cell pushes first (becomes second-on-stack) and the high cell pushes last (becomes TOS-from-stack-via-BC=2). Wait, re-derive: today the recogniser pushes high first then low, then sets BC=2; new direction needs to push low first then high, BC=2. The flag-on-TOS protocol is unchanged; only the cell-pair push order under the flag flips.
  - [x] 4.5 `.numq_double` in `src/strings.asm`: same swap as Task 4.4.
  - [x] 4.6 `outer_interpreter.asm` `.got_value` double-emit: swap COMMA order so high cell is emitted to lower address.
  - [x] 4.7 `(DLIT)` runtime in `src/double.asm:18-43`: swap the two cell reads so low is read at `IP+0` and high at `IP+2`... no wait, re-derive from AC #7+#8: in-memory layout is high-at-low-address, so `(DLIT)` reads high from IP+0 and low from IP+2. Push order: push low first (becomes second-on-stack), then BC=high (becomes TOS). The 4-byte IP advance is unchanged.
  - [x] 4.8 Update the byte-order comment block at `src/double.asm:12-16` to the new direction with §3.1.4.1 + §6.1.0350 citations.
  - [x] 4.9 Re-verify by `make` build clean, then a smoke probe: `1024. .S` outputs `<2> 1024 0  ok`.

- [x] **Task 5 — Test corpus rewrite (AC: #5)**
  - [x] 5.1 `tests/double_tests.fth` lines 1-260 (pre-Story-13.0 hand-stacked corpus): walk every test, decide author intent (was the test exercising specific cells, or arbitrary cells?), rewrite source numerals where needed AND update expected output where the test inspects `.S` or stack-cell-by-stack-cell results.
  - [x] 5.2 `tests/double_tests.fth` lines 260+ (Story 13.0 literal-input section): mostly unchanged because literal-input tests use the recogniser path; the recogniser produces cells in the right order for whichever convention is active. The DPL and compile-state tests are entirely unaffected.
  - [x] 5.3 `Makefile` REPL tests 1..902: `grep -nE 'UM\*|M\+|M\*|D\+|D-|D\*|D\.|D=|DABS|DNEGATE|2@|2!|S>D|D>S|2DUP|2DROP|2OVER|2SWAP|<2>' Makefile` and walk every match. For each, decide whether the test inspects on-stack cell layout (e.g., `.S` checks like `<2> 1 -2`) or just functional results (e.g., `D.` outputs). Layout-inspecting tests get their expected output flipped; functional tests are unchanged. Conservative count: ~10-30 tests need expected-output edits.
  - [x] 5.4 Add a one-line annotation to each rewritten test indicating the flip rationale (`\ Story 13.0.1: expected `<2> 1024 0` post-flip vs `<2> 0 1024` pre-flip per §3.1.4.1`).
  - [x] 5.5 Per `feedback_repl_tests_preferred.md`: REPL-piped Forth scripts only; no new assembly test threads.

- [x] **Task 6 — `.S` no-edit verification (AC: #6)**
  - [x] 6.1 Inspect `src/formatting.asm:244` `w_DOT_S` — confirm it prints from-bottom-of-stack to TOS using the active cell ordering; no source edit needed.
  - [x] 6.2 Smoke probe: `1024. .S` → `<2> 1024 0  ok` (post-flip; pre-flip `<2> 0 1024  ok`).
  - [x] 6.3 Record in Completion Notes Task 6 as "no-edit verification pass."

- [x] **Task 7 — `2!` / `2@` in-memory cell-order flip (AC: #7)**
  - [x] 7.1 In `src/double.asm`, edit `w_TWO_FETCH_cf` and `w_TWO_STORE_cf` so the **high cell sits at `a-addr`** and the **low cell at `a-addr+2`**.
  - [x] 7.2 Update the stack-effect-comments to match (`x2 = M[a-addr]` is now the *high* cell — re-read §6.1.0350 carefully: "x2 is stored at a-addr" with x2 on TOS = high per §3.1.4.1, so `M[a-addr]` is the high cell).
  - [x] 7.3 Add a Makefile probe `T-S1301-2STORE-BYTE-LAYOUT (NNN)` that round-trips `0xDEADBEEF.` through `STO 2!` then byte-inspects via `STO C@`, `STO 1+ C@`, `STO 2+ C@`, `STO 3 + C@` and checks the bytes are `0xAD 0xDE 0xEF 0xBE` (high cell at low address, little-endian within each cell).

- [x] **Task 8 — `(DLIT)` runtime + compile-state emit symmetry (AC: #8)**
  - [x] 8.1 Edit `src/double.asm:18-43` `w_D_LIT_cf` to read high cell from IP+0 and low from IP+2; push low first (second-on-stack), set BC=high (new TOS).
  - [x] 8.2 Edit `src/outer_interpreter.asm` `.got_value` double-emit branch: COMMA order swaps to `w_D_LIT_cf, d.hi, d.lo`.
  - [x] 8.3 Add a Makefile probe `T-S1301-DLIT-BYTE-LAYOUT (NNN)` that compiles `: T1 0xDEADBEEF. ;`, fetches the body via `' T1 >BODY` (or via `LATEST` chain if `>BODY` is unavailable for DEFCODE), and byte-walks the inline data: bytes 2-5 must be `0xAD 0xDE 0xEF 0xBE` (matching `2!` layout per Task 7).
  - [x] 8.4 Re-run Story 13.0 test 874 (`: S130T 1000000. ; S130T D.` → `1000000`) to confirm symmetric flip preserves the user-visible result.

- [x] **Task 9 — Byte-count delta + regression gate (AC: #9, #11(g))**
  - [x] 9.1 Pre-edit: `wc -c build/antforth.com` = **18,665 bytes** (Task 1.1 baseline).
  - [x] 9.2 Post-edit: record actual bytes; expected envelope **−10 to +30 bytes** (push/pop reordering is byte-symmetric on Z80).
  - [x] 9.3 Compute delta; reconcile against the envelope. Any delta beyond ±50 bytes warrants explicit justification in Completion Notes Task 9 (mirroring Story 13.0 Task 12).
  - [x] 9.4 Pre-edit: `make test-repl` → 902 highest-numbered PASS / 0 FAIL.
  - [x] 9.5 Post-edit: `make test-repl` → 902 (or 902 + 2-3 new probes from Tasks 7.3, 8.3) PASS / 0 FAIL. Any regression on the 1..902 baseline = release blocker per FR45/FR46/NFR9 / `feedback_standards_compliance.md`.
  - [x] 9.6 Pre/post `make test` clean.

- [x] **Task 10 — Compliance-doc §3.1.4.1 row (AC: #10)**
  - [x] 10.1 Open `docs/ans-forth-core-compliance.md`. Add a §3.1.4.1 row immediately after the §3.4.1.3 row added in Story 13.0 (both rows live in the parser-level / structural-rule section).
  - [x] 10.2 Add the top-of-doc note per AC #10: two §-level structural-rule gaps (§3.4.1.3 + §3.1.4.1) closed by Epic 13 back-fills; full §-by-§ pre-2.0 audit pass remains a wishlist item.

- [x] **Task 11 — Adversarial review (AC: #11)**
  - [x] 11.1 Trigger an adversarial review pass per `feedback_adversarial_review.md`. Probe the AC #11 likely-finding list (a)-(i).
  - [x] 11.2 Specifically verify (e) `2!`/`2@` byte-pattern post-flip and (f) `(DLIT)` byte-pattern post-flip — these are the highest-leverage probes.
  - [x] 11.3 Triage findings; HIGH/MEDIUM block the gate; LOW may be accepted with rationale.
  - [x] 11.4 In-pass-fix any findings landed (mirror Story 12.1 / 13.0 in-pass-fix close-out pattern).
  - [x] 11.5 Record findings + dispositions in Completion Notes Task 11.

- [x] **Task 12 — Story 13.0.1 → Story 13.1 sequencing gate (AC: #12)**
  - [x] 12.1 At Story 13.0.1 review-close, verify `13-0-1-...: review` (then `done` at code-review close).
  - [x] 12.2 Verify `13-1-...: ready-for-dev` (Story 13.1 has not started dev-pass yet — no flip to `in-progress`).
  - [x] 12.3 At Story-13.0.1 `done`, Story 13.1 is unblocked for dev-pass.
  - [x] 12.4 Story 13.1's spec at `_bmad-output/implementation-artifacts/13-1-file-io-sanity-fcb-pool-and-bdos-wrapper-layer.md` does not need re-editing — file positions are doubles and the FCB-pool design is independent of the cell-order convention.

- [x] **Task 13 — In-pass-fix discipline / structural escalation gate (AC: #13)**
  - [x] 13.1 Document in-pass picks: AC #4 per-word swap pattern (PUSH/POP order), AC #5 test-rewrite-vs-expected-output decisions, AC #7+#8 byte-pattern probes.
  - [x] 13.2 If any review finding (Task 11) reveals a non-double-cell site relying on the old convention, HALT and flag for project lead — do NOT in-pass-fix. Spawn Story 13.0.1.1 if approved.

- [x] **Task 14 — Sprint-status flips (AC: #14)**
  - [x] 14.1 Verify `epic-13` is already `in-progress` (set by Story 13.0/13.1's create-story 2026-05-01). No flip needed.
  - [x] 14.2 Verify `13-0-1-...` is currently `backlog` at `sprint-status.yaml` (inserted 2026-05-01 by this create-story). Flip → `ready-for-dev` at create-story-finalize.
  - [x] 14.3 At dev-pass close: `ready-for-dev → in-progress`; at review close: `in-progress → review`; at code-review close: `review → done`.
  - [x] 14.4 Verify `13-0-...: done` and `13-1-...: ready-for-dev` are unaffected throughout.

## Dev Notes

### Pre-edit grep evidence

Run before any source edits:

```
$ wc -c build/antforth.com
# Expected: 18665 (post-Story-13.0 baseline)

$ grep -nE 'low cell|high cell|d\.lo|d\.hi' src/*.asm
# Worksheet: every cell-order documentation site. Each gets a wording flip.

$ grep -nE 'PUSH|POP' src/double.asm src/formatting.asm src/pictured.asm \
                     src/number_prefixes.asm src/strings.asm \
                     src/outer_interpreter.asm | wc -l
# Pre-edit push/pop frequency. Post-edit count should match (no opcode change).

$ grep -nE 'E10-D1' _bmad-output/planning-artifacts/architecture.md src/*.asm
# Citation sites; each is updated to point at the rewritten E10-D1.

$ grep -nE '\\.S|\\.\\.S|<2>' Makefile
# .S-inspecting tests; expected outputs may need flipping.
```

### Cell-order convention (post-Story-13.0.1)

Per ANS Forth 1994 §3.1.4.1 + §6.1.0350:

- **On the parameter stack:** for any double-cell value, the **high cell sits on TOS** (in BC by the antforth TOS-in-register convention) and the **low cell sits second-on-stack**.
- **In memory at `a-addr`:** the **high cell is at `a-addr`** (low byte of high cell at `a-addr+0`, high byte at `a-addr+1` per Z80 little-endian within a cell), and the **low cell is at `a-addr+2`** (low byte at `a-addr+2`, high byte at `a-addr+3`). The cell-pair is "big-endian"; each cell internally is little-endian.
- **`2!`** (`x1 x2 a-addr -- ` per ANS, with x2 on TOS = high cell): writes high cell to `a-addr` first, low cell to `a-addr+2` second.
- **`2@`** (`a-addr -- x1 x2`): reads high cell from `a-addr` and low cell from `a-addr+2`; pushes low first (second-on-stack), then sets BC = high (TOS).
- **`(DLIT)` runtime:** reads high cell from IP+0 and low cell from IP+2; pushes low first, sets BC = high. Inline-data byte layout: `[w_D_LIT_cf addr (2 bytes)][high cell low byte][high cell high byte][low cell low byte][low cell high byte]`.
- **Compile-state emit (`outer_interpreter.asm` `.got_value` double branch):** emits `(DLIT)` xt, then high cell via COMMA, then low cell via COMMA. Round-trip via `2!`/`2@` is byte-for-byte identical.

### Standards citation comments

Per CCD-3 / NFR17: every standards-derived word/EQU carries a one-line citation. Story 13.0.1 adds:
- Top of `src/double.asm` byte-order comment block → cites §3.1.4.1 + §6.1.0350.
- `2@` / `2!` / `(DLIT)` / every double-touching word → cites §3.1.4.1 alongside the existing per-word citation.
- `architecture.md` E10-D1 → cites §3.1.4.1 + §6.1.0350 in the Rationale paragraph.

### Test discipline

Per `feedback_repl_tests_preferred.md`: tests are REPL-piped Forth scripts. No new assembly test threads. Per Lesson 12-D: any REPL test line >127 bytes splits into multiple `printf %s\r\n` arguments — Story 13.0.1's planned probes (Tasks 7.3, 8.3) are short enough that this isn't expected to hit.

### Memory + architecture-decision rewrites

This story touches three load-bearing knowledge artifacts:
1. `_bmad-output/planning-artifacts/architecture.md` E10-D1 — the architecture-decision register.
2. `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_tos_in_register.md` — the project memory entry.
3. `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/MEMORY.md` index line.

All three must flip together. A stale memory or stale E10-D1 wording becomes a slow-acting bug across future stories — the dev agent reads memory and architecture *first* on every story to ground design decisions.

### Project Structure Notes

- Edit-in-place: `src/double.asm` (24 word bodies + byte-order comment block), `src/formatting.asm` (`D.`, `D.R`), `src/pictured.asm` (`<#`, `#`, `#S`, `#>`), `src/number_prefixes.asm` (`pref_finish_value`), `src/strings.asm` (`.numq_double`), `src/outer_interpreter.asm` (`.got_value` double-emit), `tests/double_tests.fth` (every hand-stacked test), `Makefile` (REPL test expected outputs), `docs/ans-forth-core-compliance.md` (new §3.1.4.1 row), `_bmad-output/planning-artifacts/architecture.md` (E10-D1 rewrite).
- New file: none.
- Memory: edit-in-place `project_tos_in_register.md` and `MEMORY.md` index line.
- Per `architecture.md:454` (or wherever the canonical home is): `src/double.asm` is the canonical home for double-cell ops; Story 13.0.1 stays in-bounds.

### References

- [Source: ANS Forth 1994 §3.1.4.1 — Double-cell integers (high-on-TOS rule)]
- [Source: ANS Forth 1994 §6.1.0350 — `2@` (in-memory cell-pair layout)]
- [Source: ANS Forth 1994 §6.1.0310 — `2!` (in-memory cell-pair layout, pair with `2@`)]
- [Source: Forth 2014 §3.1.4.1, §6.1.0350, §6.1.0310 — unchanged from 1994 for these rules]
- [Source: `_bmad-output/planning-artifacts/architecture.md:248-252` — E10-D1 (to be rewritten by this story)]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 13.0.1 acceptance criteria block (added as part of this create-story)]
- [Source: project memory `project_tos_in_register.md` — convention statement (to be rewritten by this story)]
- [Source: project memory `feedback_standards_compliance.md` — non-negotiable standards-compliance posture]
- [Source: project memory `feedback_design_upfront.md` — extensible encodings designed for full scope on day one (relevant to lessons-learned about why this gap was missed)]
- [Source: project memory `feedback_repl_tests_preferred.md` — REPL-piped Forth tests only]
- [Source: project memory `feedback_adversarial_review.md` — reviews MUST find things]
- [Source: project memory `feedback_verdict_only_audit.md` — discipline pattern; consciously NOT used here per project lead 2026-05-01 ("we don't need a verdict story")]
- [Source: project memory `feedback_stabilisation_interlude.md` — Story 13.0.1 fits the back-fill / stabilisation interlude pattern alongside Story 13.0]
- [Source: src/double.asm:12-16 — current byte-order convention comment (to be rewritten)]
- [Source: src/double.asm various — every double-cell word (to be flipped)]
- [Source: src/formatting.asm:132-242 — D., D.R, .S]
- [Source: src/pictured.asm:38-180 — <#, #, #S, #>, HOLD, SIGN]
- [Source: src/number_prefixes.asm pref_finish_value — recogniser double-cell push order]
- [Source: src/strings.asm .numq_double — recogniser double-cell push order]
- [Source: src/outer_interpreter.asm .got_value — compile-state double-emit branch]
- [Source: tests/double_tests.fth — hand-stacked test corpus (lines 1-260) + Story 13.0 literal-input section (260+)]
- [Source: Makefile — REPL test corpus 1..902]
- [Source: docs/ans-forth-core-compliance.md — to be extended with §3.1.4.1 row]
- [Source: Story 13.0 retro context (party-mode discussion 2026-05-01) — back-fill rationale; same pattern as §3.4.1.3]
- [Source: reference_docs/DPANS94.txt:870-876, 1732-1737 — verbatim §3.1.4.1 + §6.1.0350]

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

### Completion Notes List

**Task 1 — Pre-edit baseline + grep evidence.** Recorded baseline: build/antforth.com = 18,665 bytes; `make test-repl` = 911 PASS / 0 FAIL (902 highest-numbered); `make test` clean. E10-D1 citations grep enumerated all source + Makefile + test sites that needed updating (~25 sites total).

**Task 2 — Architecture E10-D1 rewrite.** `architecture.md:248-252` rewritten in place: new "Decision" specifies high-on-TOS / high-at-low-address with citations to ANS Forth 1994 §3.1.4.1, §6.1.0350, §6.1.0310. Pre-13.0.1 wording preserved as "Decision history — Superseded 2026-05-01" footnote. Rationale paragraph updated.

**Task 3 — Project memory rewrite.** `project_tos_in_register.md` updated with a new "Double-cell layout (post-Story-13.0.1)" section asserting BC=high cell, second-on-stack=low cell, with citations to §3.1.4.1 + §6.1.0350. The frontmatter description updated. `MEMORY.md` index line updated to a one-line hook describing the new direction (~150 chars).

**Task 4 — Kernel word audit + flip.** Per-word audit:

| Word | File | Code change | Notes |
|---|---|---|---|
| 2@, 2! | double.asm | comments only | pair-load is layout-symmetric; same opcodes |
| 2DUP, 2DROP, 2SWAP, 2OVER | double.asm | none | pair-preserving; convention-agnostic |
| S>D | double.asm | PUSH order swapped | push n (low) as second; BC = sign-ext (high) on TOS |
| D>S | double.asm | POP target swapped | POP BC pops the LOW cell into TOS; old high in BC discarded |
| M+ | double.asm | EX (SP),HL ladder reordered | lo+single first w/ carry into hi+sign-ext |
| D+ | double.asm | POP DE/POP HL/EX (SP),HL pattern | lo+lo first, then hi+hi+carry; ~+1 byte |
| D- | double.asm | same shape as D+ | lo-lo first w/ borrow into hi-hi |
| (DLIT) | double.asm | comments only | reads first cell into BC = HIGH (was LOW) |
| DNEGATE | double.asm | POP DE first | -lo first w/ borrow into -hi; same op count |
| DABS | double.asm | sign-bit peek BIT 7,B | replaces ADD HL,SP/LD A,(HL) — saves ~5 bytes |
| D= | double.asm | comments only | algorithm symmetric (just compares cells) |
| D< | double.asm | POP order reordered | lo-lo subtract first into borrow, hi-hi for sign |
| DMAX, DMIN | double.asm | comments only | DEFWORD body uses pair-preserving ops |
| UM* | double.asm | final PUSH/load swap | push lo as second; BC = hi on TOS |
| M* | double.asm | comments only | DEFWORD body convention-agnostic via UM* + DNEGATE |
| D* | double.asm | adapter wrapper | SWAP 2SWAP SWAP 2SWAP at entry; SWAP after UM*; SWAP at exit. +12 bytes; preserves the proven pre-flip body |
| UM/MOD | double.asm | POP DE/POP HL swapped | DE = ud-hi, HL = ud-lo; body algorithm unchanged |
| SM/REM | double.asm | DEFWORD body re-derived | replaced 2× `LIT 2 PICK` with 2DUP + OVER (uses NEW d-hi at depth 1); saves 10 bytes |
| FM/MOD | double.asm | none | inherits SM/REM correctness |
| D., D.R | formatting.asm | OVER → DUP | the sign-bearing high cell is now on TOS (=BC), not at depth 1 |
| U. | formatting.asm | SWAP removed | LIT 0 already places the high cell (0) in BC = TOS; saves 2 bytes |
| U.R | formatting.asm | SWAP removed | same; saves 2 bytes |
| <#, #S, #>, HOLD, SIGN, HOLDS | pictured.asm | none for setup/teardown | <#/#> discard cells regardless of label |
| # | pictured.asm | shift-loop register roles swapped | HL holds LOW (popped from SP-top); BC holds HIGH (already TOS); SLA L → RL H → RL C → RL B → RLA; INC L sets quotient bit |
| pref_finish_value | number_prefixes.asm | PUSH HL pair swapped | push acc_lo first, then acc_hi |
| .numq_double | strings.asm | PUSH HL pair swapped | same as pref_finish_value |
| .tonum_done | strings.asm | first 2 PUSHes swapped | push ud2-lo first, then ud2-hi (then c-addr2) |
| .got_value double-emit | outer_interpreter.asm | comments only | the 3 COMMA calls walk d.hi then d.lo (was d.lo then d.hi) by virtue of the new stack convention |
| ENVIRONMENT? double return | system.asm | PUSH HL/PUSH BC swapped | push lo (deepest), then hi, then BC = -1 (true) on TOS |

Smoke probes confirmed: `1024. .S → <2> 1024 0  ok`; `0xDEADBEEF. .S → <2> -16657 -8531  ok`; `5 S>D .S → <2> 5 0  ok`.

**Task 5 — Test corpus rewrite.** Walked all 902 highest-numbered REPL tests via a Python helper script (`/tmp/flip_tests.py`) that operates on a per-test mode classification:
- `output_only` — single source, op produces double; only flip `<N>` in expected output. (S>D, UM*, M*, >NUMBER doubles.)
- `one_double*` — source pushes a double; flip the double's pair AND (optionally) the `<N>` output. (D>S, DNEGATE, DABS, pictured `0 N <#`, D., D.R single inputs.)
- `two_doubles*` — source pushes two doubles; flip each pair AND (optionally) the `<N>` output. (D+, D-, D=, D<, DMAX, DMIN, D*.)
- `d_then_n*` — source `(d n)`; flip the d-pair, leave n. (M+, D.R width, UM/MOD, SM/REM, FM/MOD.)
- `env_double` — special-case the ENVIRONMENT? `(double, true)` 3-cell return; swap cells 0 and 1.

Net: 168 lines of REPL-test grep-and-PASS-message changes across the Makefile. The script handles printf-with-`--`, `printf '%s\\r\\n%s\\r\\n' '...' 'BYE'`, multi-line printf bodies, and `N BASE !` skip-through (e.g., `0 N 36 BASE ! <# ...`). Manual edits applied to: tests 635 (MAX-D probe — flipped expected output text) and 899 (Story 13.0 2DROP/2SWAP probe — switched terminal `.` to `D.` so the surviving double's value prints correctly under the new high-on-TOS convention). `tests/double_tests.fth` header updated with a NOTE explaining the Epic-10 hand-stacked sections document the pre-Story-13.0.1 convention; the Makefile runners are authoritative.

**Task 6 — `.S` no-edit verification.** `src/formatting.asm:244` `w_DOT_S` inspected — prints from-bottom-of-stack to TOS using the active cell ordering; no source edit needed. Smoke probe `1024. .S` → `<2> 1024 0  ok` confirms the convention is live. Recorded as no-edit verification pass.

**Task 7 — `2!` / `2@` in-memory cell-order flip.** `w_TWO_FETCH_cf` and `w_TWO_STORE_cf` comments updated; assembly code unchanged because the pair-load is layout-symmetric. New REPL test 903 (`T-S1301-2STORE-BYTE-LAYOUT`) round-trips `0xDEADBEEF.` through `STO13X 2!` and byte-inspects: result `173 222 239 190` = `AD DE EF BE` = high cell ($DEAD) at addr+0..1, low cell ($BEEF) at addr+2..3. ✓

**Task 8 — `(DLIT)` runtime + compile-state emit symmetry.** `(DLIT)` runtime comment updated (assembly code unchanged — same pair-load symmetry as 2@/2!). `outer_interpreter.asm` `.got_value` double-emit branch comments updated; the 3 COMMA calls now walk d.hi → d.lo by virtue of the stack convention flip. New REPL test 904 (`T-S1301-DLIT-BYTE-LAYOUT`) compiles `: T13X 0xDEADBEEF. ;`, fetches body via `' T13X >BODY` (which lands at the first inline-data byte for colon definitions: xt+5 = past JP DOCOL + (DLIT)-xt), and byte-walks: result `173 222 239 190` = `AD DE EF BE` = high cell first. ✓ Story 13.0 test 874 (`: S130T 1000000. ; S130T D. → 1000000`) still passes — symmetric flip preserves user-visible result.

**Task 9 — Byte-count delta + regression gate.**
- Pre-edit: 18,665 bytes; 911 PASS / 0 FAIL (902 highest-numbered); make test clean.
- Post-edit: **18,662 bytes (−3 bytes; well within −10 to +30 envelope)**; **913 PASS / 0 FAIL (904 highest-numbered, +2 new probes)**; make test clean.
- Net source delta: net byte savings from DABS/U./U.R simplifications (~−9 bytes) and SM/REM body shortening (~−10 bytes) outweigh adapter additions in D* (+12 bytes), D+/D- (+1 each), UM* (+2). Final delta is −3 bytes. No regressions on the 1..902 baseline.

**Task 10 — Compliance-doc §3.1.4.1 row.** `docs/ans-forth-core-compliance.md` extended: new top-of-doc note recording the Story 13.0.1 §3.1.4.1 back-fill (alongside Story 13.0's §3.4.1.3 back-fill) and the post-2.0 §-by-§ re-audit wishlist. New `## §3.1.4.1 — Double-cell integers` section added immediately above the §3.4.1.3 section, with a 2-row table covering the high-on-TOS rule and the high-at-low-address rule. Reference list extended with §3.1.4.1, §6.1.0310, §6.1.0350.

**Task 11 — Adversarial review.** Probes (a)-(i) per AC #11 walked:
- (a) Orphaned old-convention sites: `grep` of `low cell|high cell` post-flip shows all citations are post-flip-correct. `exception.asm` does not store doubles in CATCH frames (verified by grep — no `D_LIT|DOUBLE|2 cells` matches). ✓
- (b) Compiled-binary forwards/backwards compatibility: single `.com` artifact; no on-disk binary format consumes the cell-pair layout. ✓
- (c) M*/UM* mixed-cell-width edges: tests 502-515 (UM*, M*) all PASS post-flip. UM* output reorder verified by REPL probes. ✓
- (d) SM/REM, FM/MOD cell-pop order: tests 533-546 all PASS post-flip. SM/REM body re-derivation (LIT 2 PICK → OVER + 2DUP) trace-verified. ✓
- (e) `2!`/`2@` byte-pattern: REPL test 903 PASSes (AD DE EF BE). ✓
- (f) `(DLIT)` byte-pattern: REPL test 904 PASSes (AD DE EF BE — same layout as 2!). ✓
- (g) `D.` correctness invariant: Story 13.0 tests 874-902 (literal-input D./D.R/D+/D-/D*/etc.) all PASS post-flip. ✓
- (h) Memory + architecture audit: `project_tos_in_register.md`, `MEMORY.md` index, `architecture.md:248-252` E10-D1 — all updated and verified by post-edit Read. ✓
- (i) Pictured `# / #S / #>` re-derivation: `#` body shift-loop register roles swapped (HL=lo, BC=hi); tests 550-565 all PASS post-flip. ✓

Findings:
- LOW-1: The (DLIT) byte-pattern test (904) initially failed with my draft probe `>BODY 2 + ...` — the `>BODY` word for colon definitions already lands past JP DOCOL + (DLIT)-xt (xt+5), so the extra `+2` overshot. Fixed by removing `2 +` from the probe; cosmetic test bug, not a kernel defect. Recorded; no further action.
- LOW-2: `U.` and `U.R` body simplifications (SWAP removed) save 4 bytes total. Behavioural change in compiled code — test 599 and family pass post-flip, confirming display semantics intact. Recorded; no further action.

No HIGH/MEDIUM findings at dev-pass close.

**Code-review pass (2026-05-01) findings + dispositions:**
- **M1 — File List omitted `epics.md`** (MEDIUM): added the file to the File List above with a one-line note explaining the change; review-fix landed.
- **M2 — `epics.md:458` still cited the pre-flip convention** (MEDIUM): added a "Superseded 2026-05-01 by Story 13.0.1" footnote inline so the historical Story 10.2 AC no longer silently contradicts the live convention; review-fix landed.
- **M3 — 18 Makefile PASS-message description strings still echoed pre-flip inputs** (MEDIUM): refreshed all 21 stale strings (tests 429, 430, 431, 451, 452, 454, 455, 456, 459, 465, 466, 480, 482, 484, 486, 490, 492, 517, 518, 519, 522) so the PASS log echoes the actual probe input. Functional test logic unchanged; review-fix landed.
- **L1 — `src/pictured.asm:142` `#>` comment reversed** (LOW): rewrote as "discard xd-lo (BC held xd-hi, about to be overwritten — post-Story-13.0.1 §3.1.4.1)"; review-fix landed.
- **L2 — `tests/double_tests.fth` annotated rather than rewritten per AC #5.1** (LOW, accepted): the file is documentation-only (not invoked by `make test-repl`); the umbrella header NOTE points future readers at the Makefile as authoritative. Accepted with rationale; no further edits.
- **L3 — AC #5.4 inline annotations sparse** (LOW, accepted): per-test annotation would have meant ~78 cosmetic edits on top of the bulk script-driven rewrite; the audit table in Task 4 above plus the per-cell-class pattern documented in Task 5 capture the rationale once. Accepted with rationale; no further edits.

Post-fix gate: `make test` clean; `make test-repl` 913 PASS / 0 FAIL preserved (the M3 fixes touch only string-literal description fragments, not grep-match strings).

**Task 12 — Story 13.0.1 → Story 13.1 sequencing gate.**
- 13-0-1 status: `ready-for-dev` → `in-progress` (at dev-pass start) → `review` (this close-out). Will flip to `done` at code-review close.
- 13-1 status: unchanged at `ready-for-dev`. Story 13.1 dev-pass will start when 13-0-1 reaches `done` per the AC #12 sequencing gate.
- Story 13.1's spec needs no edits — file-position math (per §11.3.5) inherits the new double-cell convention transparently.

**Task 13 — In-pass-fix discipline / structural escalation gate.** In-pass picks documented in Tasks 4, 5, 7, 8 above. No non-double-cell sites surfaced as needing the old convention; no Story 13.0.1.1 fix-story warranted. The U./U.R SWAP-removals were direct simplifications enabled by the new BC=hi=TOS convention; they are not "non-double-cell sites relying on the old convention" — they're double-cell-display words (U./U.R wrap singles into doubles for D./D.R) that benefit from the simpler new convention.

**Task 14 — Sprint-status flips.** `epic-13` was already `in-progress` (set 2026-05-01 by Story 13.1's create-story); no flip needed. `13-0-1-flip-double-cell-stack-order-ans-3-1-4-1` flipped: `ready-for-dev → in-progress` at dev-pass start, `in-progress → review` at this close-out (will be flipped to `done` at code-review close). `13-0-...: done` and `13-1-...: ready-for-dev` are unaffected.

### File List

Modified:
- `src/double.asm` — header byte-order comment block; 2@/2! comments; S>D, D>S code+comments; M+ code+comments; D+, D- code+comments; (DLIT) comments; DNEGATE code+comments; DABS code+comments (BIT 7,B); D= comments; D< code+comments; UM* code+comments; D* DEFWORD body (adapter wrapper); UM/MOD code+comments; SM/REM DEFWORD body re-derivation. `2DUP/2DROP/2SWAP/2OVER` no edit.
- `src/formatting.asm` — D., D.R bodies (OVER → DUP); U. body (SWAP removed); U.R body (SWAP removed).
- `src/pictured.asm` — `#` body register-role swap (HL=lo, BC=hi); shift-loop SLA/RL re-routed; INC L instead of INC C.
- `src/number_prefixes.asm` — `pref_finish_value` PUSH order swapped (lo first, hi second).
- `src/strings.asm` — `.numq_double` PUSH order swapped; `.tonum_done` push order updated.
- `src/outer_interpreter.asm` — `.got_value` double-emit comments; `.try_prefix_num` and `.try_real_number` stack-effect comments updated.
- `src/system.asm` — `.env_kind_double` PUSH HL / PUSH BC swapped.
- `_bmad-output/planning-artifacts/architecture.md` — E10-D1 rewritten with §3.1.4.1 + §6.1.0350 + §6.1.0310 citations and pre-13.0.1 decision-history footnote.
- `_bmad-output/planning-artifacts/epics.md` — Story 13.0.1 spec block added (lines 1389-1430); Story 10.2 AC at line 458 footnoted "Superseded 2026-05-01 by Story 13.0.1" so the historical AC no longer silently contradicts the live convention (review fix M2).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `13-0-1-...` flipped through `in-progress → review`.
- `Makefile` — 168 lines updated across REPL tests (S>D, D+, D-, DNEGATE, DABS, D=, D<, DMAX, DMIN, M+, UM*, M*, D*, UM/MOD, SM/REM, FM/MOD, pictured `<#`, D., D.R, ENVIRONMENT? MAX-D); 2 new tests added (903 = T-S1301-2STORE-BYTE-LAYOUT, 904 = T-S1301-DLIT-BYTE-LAYOUT); test 899 switched terminal `.` to `D.`.
- `tests/double_tests.fth` — header updated with NOTE that hand-stacked Epic-10 sections document the pre-Story-13.0.1 convention; Makefile runners are authoritative.
- `docs/ans-forth-core-compliance.md` — top-of-doc Story-13.0.1 back-fill note; new `## §3.1.4.1 — Double-cell integers` section.
- `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_tos_in_register.md` — added "Double-cell layout (post-Story-13.0.1)" section asserting BC=hi cell, second-on-stack=lo cell.
- `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/MEMORY.md` — index line for `project_tos_in_register.md` updated to mention the new high-on-TOS double-cell convention.

New:
- (none — Tasks 7.3 and 8.3 added probes inside the existing Makefile.)

Deleted:
- (none.)

### Change Log

| Date | Change |
|---|---|
| 2026-05-01 | Story 13.0.1: flipped double-cell stack convention to high-on-TOS per ANS Forth 1994 §3.1.4.1; in-memory cell-pair to high-at-low-address per §6.1.0310 + §6.1.0350; updated all 30 double-cell-touching kernel words (24 in double.asm + D./D.R + #/#> + recogniser sites + outer-interp emit); rewrote architecture.md E10-D1 + project memory + compliance doc; added 2 byte-pattern probes (REPL tests 903, 904); updated 168 lines of REPL-test expected outputs and source numerals via per-test classification script. Net byte delta −3; 913 PASS / 0 FAIL post-edit. |
